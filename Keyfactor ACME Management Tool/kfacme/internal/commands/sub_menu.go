package commands

import (
	"context"
	"fmt"

	"kfacme/internal/acme_client"
)

func SubMenu(ctx context.Context, acme *acme_client.AcmeClient) error {
	if acme == nil {
		return fmt.Errorf("acme client is nil")
	}

	userType := acme.Vars["user_type"]
	if userType == "" {
		return DetermineAccessLevel(ctx, acme)
	}

	switch userType {
	case "admin":
		return RunAdminMenu(ctx, acme)
	case "account":
		return RunAccountAdminMenu(ctx, acme)
	case "user":
		return RunUserMenu(ctx, acme)
	default:
		return DetermineAccessLevel(ctx, acme)
	}
}
