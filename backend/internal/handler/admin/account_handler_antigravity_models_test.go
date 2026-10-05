package admin

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/Wei-Shaw/sub2api/internal/pkg/antigravity"
	"github.com/Wei-Shaw/sub2api/internal/service"
	"github.com/stretchr/testify/require"
)

func TestAccountHandlerGetAvailableModels_AntigravityUsesConfiguredModels(t *testing.T) {
	adminService := &availableModelsAdminService{
		stubAdminService: newStubAdminService(),
		account: service.Account{
			ID: 90, Platform: service.PlatformAntigravity, Type: service.AccountTypeOAuth,
			Credentials: map[string]any{"model_mapping": map[string]any{
				"gemini-3.8-flash":  "gemini-3.8-flash-tiered",
				"claude-sonnet-4-6": "claude-sonnet-4-6",
			}},
		},
	}
	router := setupAvailableModelsRouter(adminService)
	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/api/v1/admin/accounts/90/models", nil))
	require.Equal(t, http.StatusOK, recorder.Code)
	var response struct {
		Data []antigravity.ClaudeModel `json:"data"`
	}
	require.NoError(t, json.Unmarshal(recorder.Body.Bytes(), &response))
	require.Len(t, response.Data, 2)
	require.Equal(t, "claude-sonnet-4-6", response.Data[0].ID)
	require.Equal(t, "gemini-3.8-flash", response.Data[1].ID)
	require.Equal(t, "gemini-3.8-flash", response.Data[1].DisplayName)
	require.Equal(t, "model", response.Data[1].Type)
}

func TestAccountHandlerGetAvailableModels_AntigravityDefaultsWithoutMapping(t *testing.T) {
	adminService := &availableModelsAdminService{
		stubAdminService: newStubAdminService(),
		account:          service.Account{ID: 90, Platform: service.PlatformAntigravity, Type: service.AccountTypeOAuth},
	}
	router := setupAvailableModelsRouter(adminService)
	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/api/v1/admin/accounts/90/models", nil))
	require.Equal(t, http.StatusOK, recorder.Code)
	var response struct {
		Data []antigravity.ClaudeModel `json:"data"`
	}
	require.NoError(t, json.Unmarshal(recorder.Body.Bytes(), &response))
	require.Equal(t, antigravity.DefaultModels(), response.Data)
}
