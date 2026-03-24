package commands

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"strings"

	"kfacme/internal/acme_client"
	"kfacme/internal/commands/eab_keys"
	"kfacme/internal/commands/sub"
)

func RunUserMenu(ctx context.Context, acme *acme_client.AcmeClient) error {
	reader := bufio.NewReader(os.Stdin)

	for {
		fmt.Println("=== Account Admin ===")
		fmt.Println("[1] Get claim Subject")
		fmt.Println("[2] Get EAB Keys")
		fmt.Println("[3] Exit Application")
		fmt.Print("Choose what action you want to execute (1-3): ")

		input, err := reader.ReadString('\n')
		if err != nil {
			return err
		}

		switch strings.TrimSpace(input) {
		case "1":
			if err := sub.GetSub(ctx, acme, acme.Vars["client_id"], acme.Vars["client_secret"]); err != nil {
				return err
			}
		case "2":
			if err := eab_keys.GetEAB(ctx, acme, acme.Vars["client_id"], acme.Vars["client_secret"]); err != nil {
				return err
			}
		case "3":
			fmt.Println("Exiting")
			return nil
		default:
			fmt.Println("Invalid choice. Please enter a number between 1 and 3.")
		}

		fmt.Println()
	}
}
