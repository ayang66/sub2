//go:build unit

package handler

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"

	middleware "github.com/Wei-Shaw/sub2api/internal/server/middleware"
	"github.com/Wei-Shaw/sub2api/internal/service"
	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/require"
	"github.com/tidwall/gjson"
)

func TestChatCompletionsGeminiGroupRoutesAntigravityOAuthAccount(t *testing.T) {
	group := &service.Group{ID: 19, Platform: service.PlatformGemini, Status: service.StatusActive}
	account := &service.Account{
		ID: 91, Name: "gemini-oauth", Platform: service.PlatformAntigravity,
		Type: service.AccountTypeOAuth, Status: service.StatusActive,
		Schedulable: true, Concurrency: 1, GroupIDs: []int64{group.ID},
		Extra: map[string]any{"mixed_scheduling": true},
		Credentials: map[string]any{
			"model_mapping": map[string]any{"gemini-3.8-flash": "gemini-3.8-flash-tiered"},
		},
	}
	h, cleanup := newTestGatewayHandler(t, group, []*service.Account{account})
	defer cleanup()
	// A missing token provider gives a deterministic response after reaching the bridge.
	h.antigravityGatewayService = &service.AntigravityGatewayService{}

	recorder := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(recorder)
	c.Request = httptest.NewRequest(http.MethodPost, EndpointChatCompletions, bytes.NewBufferString(
		`{"model":"gemini-3.8-flash","messages":[{"role":"user","content":"hello"}]}`,
	))
	apiKey := &service.APIKey{
		ID: 114, UserID: 1, GroupID: &group.ID, Group: group, User: &service.User{ID: 1},
	}
	c.Set(string(middleware.ContextKeyAPIKey), apiKey)
	c.Set(string(middleware.ContextKeyUser), middleware.AuthSubject{UserID: 1, Concurrency: 1})

	h.ChatCompletions(c)

	require.Equal(t, http.StatusBadGateway, recorder.Code)
	require.Equal(t, "Antigravity token provider not configured", gjson.Get(recorder.Body.String(), "error.message").String())
	require.Equal(t, EndpointAntigravityGenerateContent, GetUpstreamEndpoint(c, service.PlatformAntigravity))
}
