package identifiers

import (
	"bufio"
	"context"
	"fmt"
	"kfacme/internal/acme_client"
	"kfacme/internal/commands/helpers"
	"os"
	"strings"
	"time"
)

func AddIdentifier(ctx context.Context, acme *acme_client.AcmeClient) error {
	reader := bufio.NewReader(os.Stdin)

	for {
		fmt.Println("=== Identifier Main Menu ===")
		fmt.Println("[1] FQDN EX: (appsrvr12.keyexample.com)")
		fmt.Println(`[2] Regex EX: ([a-zA-Z0-9]+\.keyexample\.com)`)
		fmt.Println("[3] Subnet EX: (192.168.12.0/24 or 2001:db8:abcd::/48)")
		fmt.Println("[4] Wildcard EX: (*.keyexample.com)")
		fmt.Println("[5] Exit to previous menu")
		fmt.Print("Choose the Identifier Type (1-5): ")

		choiceInput, err := reader.ReadString('\n')
		if err != nil {
			return err
		}
		choiceInput = strings.TrimSpace(choiceInput)

		var (
			identifier string
			itype      string
		)

		switch choiceInput {
		case "1":
			fmt.Print("Enter the FQDN: ")
			identifier, err = reader.ReadString('\n')
			if err != nil {
				return err
			}
			identifier = strings.TrimSpace(identifier)
			itype = "fqdn"

			if !helpers.IsValidFQDN(identifier) {
				fmt.Printf("Invalid FQDN: %s\n", identifier)
				time.Sleep(2 * time.Second)
				continue
			}

		case "2":
			fmt.Print("Enter the Regex: ")
			identifier, err = reader.ReadString('\n')
			if err != nil {
				return err
			}
			identifier = strings.TrimSpace(identifier)
			itype = "Regex"

			if !helpers.IsValidRegex(identifier) {
				fmt.Printf("Invalid Regex: %s\n", identifier)
				time.Sleep(2 * time.Second)
				continue
			}

		case "3":
			fmt.Print("Enter the Subnet (ipv4 or IPv6 CIDR): ")
			identifier, err = reader.ReadString('\n')
			if err != nil {
				return err
			}
			identifier = strings.TrimSpace(identifier)
			itype = "Subnet"

			if !helpers.IsValidSubnet(identifier) {
				fmt.Printf("Invalid Subnet: %s\n", identifier)
				time.Sleep(2 * time.Second)
				continue
			}

		case "4":
			enabled, err := helpers.IsWildcardEnabled(acme)
			if err != nil {
				return err
			}
			if !enabled {
				fmt.Println("Wildcard enrollment is not enabled in system settings.")
				time.Sleep(2 * time.Second)
				continue
			}

			fmt.Print("Enter wildcard domain (must be enabled in system settings): ")
			identifier, err = reader.ReadString('\n')
			if err != nil {
				return err
			}
			identifier = strings.TrimSpace(identifier)
			itype = "Wildcard"

			if !helpers.IsValidWildcardDomain(identifier) {
				fmt.Printf("Invalid Wildcard Domain: %s\n", identifier)
				time.Sleep(2 * time.Second)
				continue
			}

		case "5":
			fmt.Println("Exiting to previous menu...")
			return nil

		default:
			fmt.Println("Invalid choice. Please enter a number between 1 and 5.")
			time.Sleep(2 * time.Second)
			continue
		}

		body := map[string]any{
			"Identifier": identifier,
			"type":       itype,
		}

		result, err := acme.IdentifierAddPost(body, "")
		if err != nil {
			fmt.Printf("Network/API error while adding identifier: %v\n", err)
			time.Sleep(2 * time.Second)
			continue
		}
		defer result.Body.Close()

		if result.StatusCode == 200 {
			fmt.Printf("Identifier '%s' was added successfully\n", identifier)
			time.Sleep(2 * time.Second)
			return nil
		}

		fmt.Printf("Server rejected the request (%d)\n", result.StatusCode)
		time.Sleep(2 * time.Second)
	}
}
