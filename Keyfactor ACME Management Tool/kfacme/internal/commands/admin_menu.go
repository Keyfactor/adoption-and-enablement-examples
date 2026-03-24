package commands

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"strings"

	"kfacme/internal/acme_client"
	"kfacme/internal/commands/accounts"
	"kfacme/internal/commands/claims"
	"kfacme/internal/commands/eab_keys"
	"kfacme/internal/commands/identifiers"
	"kfacme/internal/commands/sub"
	"kfacme/internal/commands/system_settings"
)

func RunAdminMenu(ctx context.Context, acme *acme_client.AcmeClient) error {
	reader := bufio.NewReader(os.Stdin)

	for {
		fmt.Println("=== Administration Menu ===")
		fmt.Println("[1] Get claim Subject")
		fmt.Println("[2] Get EAB Keys")
		fmt.Println("[3] Delete EAB Keys")
		fmt.Println("[4] Manage Registered Accounts")
		fmt.Println("[5] Manage Claims")
		fmt.Println("[6] Manage Identifiers")
		fmt.Println("[7] Manage System Settings")
		fmt.Println("[8] Exit Application")
		fmt.Print("Choose what action you want to execute (1-8): ")

		input, err := reader.ReadString('\n')
		if err != nil {
			return err
		}

		switch strings.TrimSpace(input) {
		case "1":
			if err := sub.GetSub(ctx, acme, "", ""); err != nil {
				return err
			}
		case "2":
			if err := eab_keys.GetEAB(ctx, acme, "", ""); err != nil {
				return err
			}
		case "3":
			if err := eab_keys.DelEAB(ctx, acme); err != nil {
				return err
			}
		case "4":
			if err := accounts.RunAccountsMenu(ctx, acme); err != nil {
				return err
			}
		case "5":
			if err := claims.RunClaimsMenu(ctx, acme); err != nil {
				return err
			}
		case "6":
			if err := identifiers.RunIdentifiersMenu(ctx, acme); err != nil {
				return err
			}
		case "7":
			if err := system_settings.RunSystemMenu(ctx, acme); err != nil {
				return err
			}
		case "8":
			fmt.Println("Exiting")
			return nil
		default:
			fmt.Println("Invalid choice. Please enter a number between 1 and 8.")
		}

		fmt.Println()
	}
}
