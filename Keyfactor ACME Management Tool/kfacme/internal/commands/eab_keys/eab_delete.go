package eab_keys

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"kfacme/internal/acme_client"
	"kfacme/internal/commands/helpers"
	"os"
	"strings"
	"time"
)

func DelEAB(ctx context.Context, acme *acme_client.AcmeClient) error {
	_ = ctx

	if acme == nil {
		return fmt.Errorf("acme client is nil")
	}

	accountResp, err := acme.AdminAccountsGet("")
	if err != nil {
		return err
	}
	defer accountResp.Body.Close()

	var accounts []map[string]any
	if err := json.NewDecoder(accountResp.Body).Decode(&accounts); err != nil {
		return err
	}

	selectedAccount := helpers.DisplayAccountsAndGetChoice(accounts)
	if selectedAccount == "" {
		return nil
	}

	fmt.Printf("Are you sure you want to delete the account with ID %s?\n", selectedAccount)
	fmt.Println("This action cannot be undone.")
	fmt.Println("Type 'y' to continue, or press Enter / type 'n' to return to the menu.")

	reader := bufio.NewReader(os.Stdin)
	input, err := reader.ReadString('\n')
	if err != nil {
		return err
	}

	choice := strings.ToLower(strings.TrimSpace(input))
	if choice == "" || choice == "n" || choice == "no" {
		fmt.Println("Returning to Previous Menu...")
		time.Sleep(1 * time.Second)
		return nil
	}
	if choice != "y" && choice != "yes" {
		fmt.Println("Invalid choice. Returning to Previous Menu...")
		time.Sleep(1 * time.Second)
		return nil
	}

	resp, err := acme.AdminAccountsRevokePost(selectedAccount, true, "")
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		fmt.Printf("Account with ID %s deleted successfully\n", selectedAccount)
	} else {
		fmt.Printf("Failed to delete account with ID %s\n", selectedAccount)
	}

	time.Sleep(2 * time.Second)
	return nil
}
