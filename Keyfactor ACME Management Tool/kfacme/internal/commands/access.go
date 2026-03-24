package commands

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"time"

	"kfacme/internal/acme_client"
)

func DetermineAccessLevel(ctx context.Context, acme *acme_client.AcmeClient) error {
	if acme == nil {
		return fmt.Errorf("acme client is nil")
	}

	// Try super admin access first.
	if resp, err := acme.ClaimGet("", ""); err == nil {
		hasData, readErr := responseHasJSONData(resp)
		resp.Body.Close()
		if readErr == nil && hasData {
			fmt.Println("You have Super Admin access.")
			acme.Vars["user_type"] = "admin"
			time.Sleep(1 * time.Second)
			ClearScreen()
			return RunAdminMenu(ctx, acme)
		}
	}

	// Try account admin access second.
	if resp, err := acme.AdminAccountsGet(""); err == nil {
		hasData, readErr := responseHasJSONData(resp)
		resp.Body.Close()
		if readErr == nil && hasData {
			fmt.Println("You have Account Admin access.")
			acme.Vars["user_type"] = "account"
			time.Sleep(1 * time.Second)
			ClearScreen()
			return RunAccountAdminMenu(ctx, acme)
		}
	}

	// Fallback: enrollment user.
	fmt.Println("You have Enrollment User access.")
	acme.Vars["user_type"] = "user"
	time.Sleep(1 * time.Second)
	ClearScreen()
	return RunUserMenu(ctx, acme)
}

func responseHasJSONData(resp *http.Response) (bool, error) {
	if resp == nil {
		return false, nil
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return false, nil
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return false, err
	}

	// Treat non-empty JSON response as "has access"
	return len(body) > 0 && string(body) != "null" && string(body) != "[]", nil
}

func ClearScreen() {
	fmt.Print("\033[H\033[2J")
}
