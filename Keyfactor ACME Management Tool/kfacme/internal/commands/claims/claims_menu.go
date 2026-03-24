package claims

import (
	"bufio"
	"context"
	"fmt"
	"kfacme/internal/acme_client"
	"os"
	"strings"
)

func RunClaimsMenu(ctx context.Context, acme *acme_client.AcmeClient) error {
	reader := bufio.NewReader(os.Stdin)

	for {
		fmt.Println("=== Claims Menu ===")
		fmt.Println("[1] Show Claim")
		fmt.Println("[2] Add Claim")
		fmt.Println("[3] Update Claim")
		fmt.Println("[4] Remove Claim")
		fmt.Println("[5] Exit to Previous Menu")
		fmt.Print("Choose what action you want to execute (1-5): ")

		input, err := reader.ReadString('\n')
		if err != nil {
			return err
		}

		switch strings.TrimSpace(input) {
		case "1":
			if err := ShowClaims(ctx, acme); err != nil {
				return err
			}
		case "2":
			if err := AddClaim(acme); err != nil {
				return err
			}
		case "3":
			if err := UpdateClaim(ctx, acme); err != nil {
				return err
			}
		case "4":
			if err := RemoveClaim(ctx, acme); err != nil {
				return err
			}
		case "5":
			fmt.Println("Exiting to Previous Menu")
			return nil
		default:
			fmt.Println("Invalid choice. Please enter a number between 1 and 5.")
		}

		fmt.Println()
	}
}
