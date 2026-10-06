package provider

import (
	"context"
	"net/url"
	"strings"
	"testing"

	"github.com/Wei-Shaw/sub2api/internal/payment"
)

func TestEasyPayVerifyNotificationAcceptsSignedAllowlist(t *testing.T) {
	t.Parallel()

	const pkey = "test_secret_key"
	e := &EasyPay{config: map[string]string{"pid": "1001", "pkey": pkey}}
	params := map[string]string{
		"pid":          "1001",
		"trade_no":     "gateway-trade-1",
		"out_trade_no": "ORDER123",
		"type":         "alipay",
		"name":         "balance recharge",
		"money":        "10.00",
		"trade_status": tradeStatusSuccess,
		"param":        "",
	}
	params["sign"] = easyPaySign(params, pkey)
	params["sign_type"] = signTypeMD5

	n, err := e.VerifyNotification(context.Background(), encodeEasyPayParams(params), nil)
	if err != nil {
		t.Fatalf("VerifyNotification returned error: %v", err)
	}
	if n.Status != payment.ProviderStatusSuccess {
		t.Fatalf("status = %q", n.Status)
	}
	if n.TradeNo != "gateway-trade-1" || n.OrderID != "ORDER123" || n.Amount != 10 {
		t.Fatalf("notification = %+v", n)
	}
}

func TestEasyPayVerifyNotificationRejectsUnexpectedParam(t *testing.T) {
	t.Parallel()

	const pkey = "test_secret_key"
	e := &EasyPay{config: map[string]string{"pid": "1001", "pkey": pkey}}
	params := signedEasyPayNotifyParams(pkey)
	params["return_url"] = "https://example.com/payment/result"

	_, err := e.VerifyNotification(context.Background(), encodeEasyPayParams(params), nil)
	if err == nil || !strings.Contains(err.Error(), "unexpected notify param") {
		t.Fatalf("error = %v, want unexpected notify param", err)
	}
}

func TestEasyPayVerifyNotificationRejectsEmptyTradeNo(t *testing.T) {
	t.Parallel()

	const pkey = "test_secret_key"
	e := &EasyPay{config: map[string]string{"pid": "1001", "pkey": pkey}}
	params := signedEasyPayNotifyParams(pkey)
	params["trade_no"] = ""
	params["sign"] = easyPaySign(params, pkey)

	_, err := e.VerifyNotification(context.Background(), encodeEasyPayParams(params), nil)
	if err == nil || !strings.Contains(err.Error(), "missing trade_no") {
		t.Fatalf("error = %v, want missing trade_no", err)
	}
}

func TestEasyPayVerifyNotificationRejectsDuplicateParam(t *testing.T) {
	t.Parallel()

	const pkey = "test_secret_key"
	e := &EasyPay{config: map[string]string{"pid": "1001", "pkey": pkey}}
	raw := encodeEasyPayParams(signedEasyPayNotifyParams(pkey)) + "&trade_no=other-trade"

	_, err := e.VerifyNotification(context.Background(), raw, nil)
	if err == nil || !strings.Contains(err.Error(), "duplicate notify param") {
		t.Fatalf("error = %v, want duplicate notify param", err)
	}
}

func signedEasyPayNotifyParams(pkey string) map[string]string {
	params := map[string]string{
		"pid":          "1001",
		"trade_no":     "gateway-trade-1",
		"out_trade_no": "ORDER123",
		"type":         "alipay",
		"name":         "balance recharge",
		"money":        "10.00",
		"trade_status": tradeStatusSuccess,
	}
	params["sign"] = easyPaySign(params, pkey)
	params["sign_type"] = signTypeMD5
	return params
}

func encodeEasyPayParams(params map[string]string) string {
	values := url.Values{}
	for k, v := range params {
		values.Set(k, v)
	}
	return values.Encode()
}
