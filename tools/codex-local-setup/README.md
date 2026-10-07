# Codex 本地配置助手

本助手只监听 `127.0.0.1`，用于配合哈基米中转站网页配置 Codex。API Key 由浏览器直接发送到本机助手，不会上传到中转站后端。

## 使用

```bash
go run .
```

启动后打开中转站的 **Codex 一键配置** 页面，输入 API Key，点击配置即可。无需配对码，助手只接受配置的中转站 Origin 请求。

助手会：

1. 创建 `~/.codex`（或 `CODEX_HOME` 指定的目录）。
2. 备份已有的 `auth.json` 与 `config.toml`。
3. 写入中转站 API Key 和 Codex 配置。
4. 尝试重启本机 `codex` 命令；找不到时只提示手动重启。

## 构建

```bash
go build -o codex-local-setup .
```

Windows 可构建为 `codex-local-setup.exe`。不要把 API Key 写入日志、提交到仓库或分享给其他人。

跨平台构建示例：

```bash
GOOS=darwin GOARCH=arm64 go build -o codex-local-setup-macos-arm64 .
GOOS=darwin GOARCH=amd64 go build -o codex-local-setup-macos-amd64 .
GOOS=linux GOARCH=amd64 go build -o codex-local-setup-linux-amd64 .
GOOS=windows GOARCH=amd64 go build -o codex-local-setup-windows-amd64.exe .
```

## 安全边界

- 仅绑定回环地址，不接受公网连接。
- 只允许配置的中转站 Origin 跨域访问。
- 所有写入文件权限为用户私有权限。
- 每次覆盖配置前都会生成带时间戳的备份。
- 只绑定回环地址，并限制 `/v1/*` 请求的 Origin 为中转站页面。
