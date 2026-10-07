package main

import (
	_ "embed"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"time"
)

const version = "0.1.1"

type configureRequest struct {
	APIKey          string `json:"api_key"`
	BaseURL         string `json:"base_url"`
	Model           string `json:"model"`
	ReasoningEffort string `json:"reasoning_effort"`
	Restart         bool   `json:"restart"`
}

type configureResponse struct {
	OK        bool     `json:"ok"`
	Version   string   `json:"version"`
	ConfigDir string   `json:"config_dir"`
	Backups   []string `json:"backups,omitempty"`
	Warnings  []string `json:"warnings,omitempty"`
}

type server struct {
	origin string
}

//go:embed setup.html
var setupHTML []byte

func main() {
	port := flag.Int("port", 17831, "local HTTP port")
	origin := flag.String("origin", "https://brookeapi.cloud", "allowed web origin")
	noRestart := flag.Bool("no-restart", false, "write files without restarting Codex")
	noBrowser := flag.Bool("no-browser", false, "do not open the local setup page")
	flag.Parse()

	s := &server{origin: strings.TrimRight(*origin, "/")}
	mux := http.NewServeMux()
	mux.HandleFunc("/", s.page)
	mux.HandleFunc("/health", s.health)
	mux.HandleFunc("/v1/status", s.status)
	mux.HandleFunc("/v1/configure", func(w http.ResponseWriter, r *http.Request) {
		s.configure(w, r, !*noRestart)
	})

	address := fmt.Sprintf("127.0.0.1:%d", *port)
	listener, err := net.Listen("tcp", address)
	if err != nil {
		log.Fatal(err)
	}
	localURL := "http://" + address
	log.Printf("Codex local setup %s listening on %s", version, localURL)
	if !*noBrowser {
		openBrowser(localURL)
	}
	if err := http.Serve(listener, s.withCORS(mux)); err != nil {
		log.Fatal(err)
	}
}

func (s *server) page(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write(setupHTML)
}

func (s *server) withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		localOrigin := strings.HasPrefix(origin, "http://127.0.0.1:") || strings.HasPrefix(origin, "http://localhost:")
		if origin != "" && origin != s.origin && !localOrigin {
			w.WriteHeader(http.StatusForbidden)
			return
		}
		if origin != "" {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
			w.Header().Set("Access-Control-Allow-Private-Network", "true")
			w.Header().Set("Vary", "Origin")
		}
		if strings.HasPrefix(r.URL.Path, "/v1/") && origin != s.origin && !localOrigin && origin != "" {
			w.WriteHeader(http.StatusForbidden)
			return
		}
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (s *server) health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "version": version})
}

func (s *server) status(w http.ResponseWriter, r *http.Request) {
	dir := codexDir()
	_, authErr := os.Stat(filepath.Join(dir, "auth.json"))
	_, configErr := os.Stat(filepath.Join(dir, "config.toml"))
	_, codexErr := exec.LookPath("codex")
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":            true,
		"version":       version,
		"config_dir":    dir,
		"auth_exists":   authErr == nil,
		"config_exists": configErr == nil,
		"codex_found":   codexErr == nil,
	})
}

func (s *server) configure(w http.ResponseWriter, r *http.Request, restart bool) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var input configureRequest
	if err := json.NewDecoder(io.LimitReader(r.Body, 16*1024)).Decode(&input); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}
	if err := validate(input); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	dir := codexDir()
	if err := os.MkdirAll(dir, 0o700); err != nil {
		http.Error(w, "cannot create Codex directory", http.StatusInternalServerError)
		return
	}
	stamp := time.Now().Format("20060102-150405")
	backups := make([]string, 0, 2)
	for _, name := range []string{"auth.json", "config.toml"} {
		path := filepath.Join(dir, name)
		if _, err := os.Stat(path); err == nil {
			backup := path + ".bak-" + stamp
			if err := os.Rename(path, backup); err != nil {
				http.Error(w, "cannot back up existing "+name, http.StatusInternalServerError)
				return
			}
			backups = append(backups, backup)
		} else if !errors.Is(err, os.ErrNotExist) {
			http.Error(w, "cannot inspect existing "+name, http.StatusInternalServerError)
			return
		}
	}

	baseURL := strings.TrimRight(input.BaseURL, "/")
	auth, _ := json.MarshalIndent(map[string]string{"OPENAI_API_KEY": input.APIKey}, "", "  ")
	auth = append(auth, '\n')
	config := []byte(fmt.Sprintf(`cli_auth_credentials_store = "file"
disable_response_storage = true
model = %s
model_provider = "custom"
model_reasoning_effort = %s
personality = "friendly"

[model_providers.custom]
name = "Hakimi"
base_url = %s
requires_openai_auth = true
wire_api = "responses"
`, tomlQuote(input.Model), tomlQuote(input.ReasoningEffort), tomlQuote(baseURL)))

	if err := atomicWrite(filepath.Join(dir, "auth.json"), auth); err != nil {
		http.Error(w, "cannot write auth.json", http.StatusInternalServerError)
		return
	}
	if err := atomicWrite(filepath.Join(dir, "config.toml"), config); err != nil {
		http.Error(w, "cannot write config.toml", http.StatusInternalServerError)
		return
	}

	warnings := make([]string, 0)
	if restart {
		warnings = restartCodex()
	}
	writeJSON(w, http.StatusOK, configureResponse{
		OK: true, Version: version, ConfigDir: dir, Backups: backups, Warnings: warnings,
	})
}

func validate(input configureRequest) error {
	if len(input.APIKey) < 8 || strings.ContainsAny(input.APIKey, "\r\n\t ") {
		return errors.New("API Key 格式无效")
	}
	if input.Model == "" || !regexp.MustCompile(`^[A-Za-z0-9._:/-]+$`).MatchString(input.Model) {
		return errors.New("模型名称无效")
	}
	parsedURL, err := url.ParseRequestURI(input.BaseURL)
	if err != nil || parsedURL.Host == "" || (parsedURL.Scheme != "http" && parsedURL.Scheme != "https") || strings.ContainsAny(input.BaseURL, "\r\n") {
		return errors.New("接口地址无效")
	}
	switch input.ReasoningEffort {
	case "minimal", "low", "medium", "high", "xhigh":
	default:
		return errors.New("推理强度不能为空")
	}
	return nil
}

func tomlQuote(value string) string {
	value = strings.ReplaceAll(value, `\`, `\\`)
	value = strings.ReplaceAll(value, `"`, `\"`)
	return `"` + value + `"`
}

func codexDir() string {
	if value := os.Getenv("CODEX_HOME"); value != "" {
		return value
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return ".codex"
	}
	return filepath.Join(home, ".codex")
}

func atomicWrite(path string, content []byte) error {
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, content, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func restartCodex() []string {
	var warnings []string
	if runtime.GOOS == "windows" {
		_ = exec.Command("taskkill", "/IM", "codex.exe", "/T", "/F").Run()
		if _, err := exec.LookPath("codex.exe"); err != nil {
			warnings = append(warnings, "未找到 codex.exe，请手动重新打开 Codex")
			return warnings
		}
		if err := exec.Command("cmd", "/C", "start", "", "codex.exe").Start(); err != nil {
			warnings = append(warnings, "Codex 已停止，但自动启动失败，请手动打开")
		}
		return warnings
	}
	_ = exec.Command("pkill", "-x", "codex").Run()
	if _, err := exec.LookPath("codex"); err != nil {
		warnings = append(warnings, "未找到 codex 命令，请手动重新打开 Codex")
		return warnings
	}
	cmd := exec.Command("codex")
	if err := cmd.Start(); err != nil {
		warnings = append(warnings, "Codex 已停止，但自动启动失败，请手动打开")
	}
	return warnings
}

func openBrowser(target string) {
	var command string
	var args []string
	switch runtime.GOOS {
	case "darwin":
		command, args = "open", []string{target}
	case "windows":
		command, args = "rundll32", []string{"url.dll,FileProtocolHandler", target}
	default:
		command, args = "xdg-open", []string{target}
	}
	if err := exec.Command(command, args...).Start(); err != nil {
		log.Printf("open local setup page manually at %s: %v", target, err)
	}
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
