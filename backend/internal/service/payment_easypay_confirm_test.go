//go:build unit

package service

import (
	"context"
	"testing"
	"time"

	dbent "github.com/Wei-Shaw/sub2api/ent"
	"github.com/Wei-Shaw/sub2api/internal/payment"
	"github.com/stretchr/testify/require"
)

func TestEasyPayNotificationRequiresMatchingUpstreamOrder(t *testing.T) {
	ctx := context.Background()
	client := newPaymentOrderLifecycleTestClient(t)

	user, err := client.User.Create().
		SetEmail("easypay-confirm@example.com").
		SetPasswordHash("hash").
		SetUsername("easypay-confirm-user").
		Save(ctx)
	require.NoError(t, err)

	order := createEasyPayConfirmOrder(t, ctx, client, user, "EASY-CONFIRM-OK", "sub2_easypay_confirm_ok")
	provider := &paymentOrderLifecycleQueryProvider{
		key: payment.TypeEasyPay,
		resp: &payment.QueryOrderResponse{
			TradeNo: "upstream-trade-ok",
			Status:  payment.ProviderStatusPaid,
			Amount:  88,
		},
	}
	svc := newEasyPayConfirmService(client, user, order, provider)

	err = svc.HandlePaymentNotification(ctx, &payment.PaymentNotification{
		TradeNo: "upstream-trade-ok",
		OrderID: order.OutTradeNo,
		Amount:  88,
		Status:  payment.ProviderStatusSuccess,
	}, payment.TypeEasyPay)
	require.NoError(t, err)
	require.Equal(t, 1, provider.queryCalls)

	reloaded, err := client.PaymentOrder.Get(ctx, order.ID)
	require.NoError(t, err)
	require.Equal(t, OrderStatusCompleted, reloaded.Status)
	require.Equal(t, "upstream-trade-ok", reloaded.PaymentTradeNo)
	require.Equal(t, 88.0, svc.userRepo.(*mockUserRepo).getByIDUser.Balance)
}

func TestEasyPayNotificationRejectsUnconfirmedUpstreamOrder(t *testing.T) {
	ctx := context.Background()
	client := newPaymentOrderLifecycleTestClient(t)

	user, err := client.User.Create().
		SetEmail("easypay-reject@example.com").
		SetPasswordHash("hash").
		SetUsername("easypay-reject-user").
		Save(ctx)
	require.NoError(t, err)

	order := createEasyPayConfirmOrder(t, ctx, client, user, "EASY-CONFIRM-REJECT", "sub2_easypay_confirm_reject")
	provider := &paymentOrderLifecycleQueryProvider{
		key: payment.TypeEasyPay,
		resp: &payment.QueryOrderResponse{
			TradeNo: "upstream-trade-other",
			Status:  payment.ProviderStatusPending,
			Amount:  88,
		},
	}
	svc := newEasyPayConfirmService(client, user, order, provider)

	err = svc.HandlePaymentNotification(ctx, &payment.PaymentNotification{
		TradeNo: "upstream-trade-other",
		OrderID: order.OutTradeNo,
		Amount:  88,
		Status:  payment.ProviderStatusSuccess,
	}, payment.TypeEasyPay)
	require.Error(t, err)
	require.Equal(t, 1, provider.queryCalls)

	reloaded, err := client.PaymentOrder.Get(ctx, order.ID)
	require.NoError(t, err)
	require.Equal(t, OrderStatusPending, reloaded.Status)
	require.Empty(t, reloaded.PaymentTradeNo)
	require.Equal(t, 0.0, svc.userRepo.(*mockUserRepo).getByIDUser.Balance)
}

func createEasyPayConfirmOrder(t *testing.T, ctx context.Context, client *dbent.Client, user *dbent.User, code string, outTradeNo string) *dbent.PaymentOrder {
	t.Helper()
	order, err := client.PaymentOrder.Create().
		SetUserID(user.ID).
		SetUserEmail(user.Email).
		SetUserName(user.Username).
		SetAmount(88).
		SetPayAmount(88).
		SetFeeRate(0).
		SetRechargeCode(code).
		SetOutTradeNo(outTradeNo).
		SetPaymentType(payment.TypeEasyPay).
		SetPaymentTradeNo("").
		SetOrderType(payment.OrderTypeBalance).
		SetStatus(OrderStatusPending).
		SetExpiresAt(time.Now().Add(time.Hour)).
		SetClientIP("127.0.0.1").
		SetSrcHost("api.example.com").
		Save(ctx)
	require.NoError(t, err)
	return order
}

func newEasyPayConfirmService(client *dbent.Client, user *dbent.User, order *dbent.PaymentOrder, provider *paymentOrderLifecycleQueryProvider) *PaymentService {
	userRepo := &mockUserRepo{
		getByIDUser: &User{
			ID:       user.ID,
			Email:    user.Email,
			Username: user.Username,
			Balance:  0,
		},
	}
	userRepo.updateBalanceFn = func(_ context.Context, id int64, amount float64) error {
		if userRepo.getByIDUser != nil && userRepo.getByIDUser.ID == id {
			userRepo.getByIDUser.Balance += amount
		}
		return nil
	}
	redeemRepo := &paymentOrderLifecycleRedeemRepo{
		codesByCode: map[string]*RedeemCode{
			order.RechargeCode: {
				ID:     1,
				Code:   order.RechargeCode,
				Type:   RedeemTypeBalance,
				Value:  order.Amount,
				Status: StatusUnused,
			},
		},
	}
	registry := payment.NewRegistry()
	registry.Register(provider)
	return &PaymentService{
		entClient:       client,
		registry:        registry,
		redeemService:   NewRedeemService(redeemRepo, userRepo, nil, nil, nil, client, nil, nil),
		userRepo:        userRepo,
		providersLoaded: true,
	}
}
