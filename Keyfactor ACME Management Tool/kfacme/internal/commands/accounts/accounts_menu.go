package accounts

import (
	"bufio"
	"context"
	"fmt"
	"kfacme/internal/acme_client"
	"os"
	"strings"
)

func RunAccountsMenu(ctx context.Context, acme *acme_client.AcmeClient) error {
	reader := bufio.NewReader(os.Stdin)

	for {
		fmt.Println("=== Registered Accounts Menu ===")
		fmt.Println("[1] Show Accounts")
		fmt.Println("[2] Update Template Mapping")
		fmt.Println("[3] Exit to Previous Menu")
		fmt.Print("Choose what action you want to execute (1-3): ")

		input, err := reader.ReadString('\n')
		if err != nil {
			return err
		}

		switch strings.TrimSpace(input) {
		case "1":
			if err := ShowAccounts(ctx, acme); err != nil {
				return err
			}
		case "2":
			if err := ChangeTemplate(ctx, acme); err != nil {
				return err
			}
		case "3":
			fmt.Println("Exiting to Previous Menu")
			return nil
		default:
			fmt.Println("Invalid choice. Please enter a number between 1 and 3.")
		}

		fmt.Println()
	}
}
