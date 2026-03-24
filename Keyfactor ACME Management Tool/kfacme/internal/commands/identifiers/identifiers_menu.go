package identifiers

import (
	"bufio"
	"context"
	"fmt"
	"kfacme/internal/acme_client"
	"os"
	"strings"
)

func RunIdentifiersMenu(ctx context.Context, acme *acme_client.AcmeClient) error {
	reader := bufio.NewReader(os.Stdin)

	for {
		fmt.Println("=== Identifiers Menu ===")
		fmt.Println("[1] Show Identifiers")
		fmt.Println("[2] Add Identifiers")
		fmt.Println("[3] Remove Identifiers")
		fmt.Println("[4] Exit to Previous Menu")
		fmt.Print("Choose what action you want to execute (1-4): ")

		input, err := reader.ReadString('\n')
		if err != nil {
			return err
		}

		switch strings.TrimSpace(input) {
		case "1":
			if err := ShowIdentifiers(ctx, acme); err != nil {
				return err
			}
		case "2":
			if err := AddIdentifier(ctx, acme); err != nil {
				return err
			}
		case "3":
			if err := RemoveIdentifier(acme); err != nil {
				return err
			}
		case "4":
			fmt.Println("Exiting to Previous Menu")
			return nil
		default:
			fmt.Println("Invalid choice. Please enter a number between 1 and 4.")
		}

		fmt.Println()
	}
}
