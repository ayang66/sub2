package routes

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/require"
)

func TestPaymentWebhooksDisabled(t *testing.T) {
	router := gin.New()
	registerDisabledPaymentWebhooks(router.Group("/api/v1"))

	for _, method := range []string{http.MethodGet, http.MethodPost, http.MethodPut, http.MethodPatch, http.MethodDelete, http.MethodOptions, http.MethodHead} {
		for _, provider := range []string{"", "/", "/easypay", "/alipay", "/wxpay", "/stripe", "/airwallex", "/unknown", "/easypay/extra"} {
			t.Run(method+provider, func(t *testing.T) {
				request := httptest.NewRequest(method, "/api/v1/payment/webhook"+provider+"?out_trade_no=test-order", strings.NewReader("ignored-body"))
				response := httptest.NewRecorder()
				router.ServeHTTP(response, request)
				require.Equal(t, http.StatusGone, response.Code)
				var body map[string]string
				require.NoError(t, json.Unmarshal(response.Body.Bytes(), &body))
				require.Equal(t, "PAYMENT_CALLBACKS_DISABLED", body["code"])
			})
		}
	}
}
