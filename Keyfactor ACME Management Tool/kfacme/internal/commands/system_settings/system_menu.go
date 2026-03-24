package system_settings

import (
	"bufio"
	"context"
	"fmt"
	"kfacme/internal/acme_client"
	"os"
	"strings"
)

func RunSystemMenu(ctx context.Context, acme *acme_client.AcmeClient) error {
	reader := bufio.NewReader(os.Stdin)

	for {
		fmt.Println("=== System Settings Menu ===")
		fmt.Println("[1] Show Settings")
		fmt.Println("[2] Allow Wildcard Enrollments")
		fmt.Println("[3] Deny Wildcard Enrollments")
		fmt.Println("[4] Certificate Revocation Enabled")
		fmt.Println("[5] Certificate Revocation Disabled")
		fmt.Println("[6] Exit to Previous Menu")
		fmt.Print("Choose what action you want to execute (1-6): ")

		input, err := reader.ReadString('\n')
		if err != nil {
			return err
		}

		switch strings.TrimSpace(input) {
		case "1":
			if err := showSystemSettings(acme); err != nil {
				return err
			}
		case "2":
			if err := changeSetting(ctx, acme, "wildcard_allow"); err != nil {
				return err
			}
		case "3":
			if err := changeSetting(ctx, acme, "wildcard_deny"); err != nil {
				return err
			}
		case "4":
			if err := changeSetting(ctx, acme, "revocation_enabled"); err != nil {
				return err
			}
		case "5":
			if err := changeSetting(ctx, acme, "revocation_disabled"); err != nil {
				return err
			}
		case "6":
			fmt.Println("Exiting to Previous Menu")
			return nil
		default:
			fmt.Println("Invalid choice. Please enter a number between 1 and 6.")
		}

		fmt.Println()
	}
}
