package eab_keys

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"kfacme/internal/acme_client"
	"kfacme/internal/commands/helpers"
	"os"
	"strings"
	"time"

	"golang.org/x/term"
)

func GetEAB(ctx context.Context, acme *acme_client.AcmeClient, clientID, clientSecret string) error {

	type KeyfactorKeyResponse struct {
		KeyID    string `json:"keyId"`
		KeyValue string `json:"keyValue"`
	}

	if acme == nil {
		return fmt.Errorf("acme client is nil")
	}

	reader := bufio.NewReader(os.Stdin)

	if strings.TrimSpace(clientID) == "" {
		fmt.Print("Enter the Client ID (press enter or return to the previous menu): ")
		input, err := reader.ReadString('\n')
		if err != nil {
			return err
		}
		clientID = strings.TrimSpace(input)
		if clientID == "" {
			fmt.Println("No Client ID entered. Returning to previous menu...")
			time.Sleep(2 * time.Second)
			return nil
		}
	}

	if strings.TrimSpace(clientSecret) == "" {
		fmt.Print("Enter the Client Secret (press enter or return to the Previous Menu): ")
		secretBytes, err := term.ReadPassword(int(os.Stdin.Fd()))
		if err != nil {
			return err
		}
		clientSecret = strings.TrimSpace(string(secretBytes))
		fmt.Println()

		if clientSecret == "" {
			fmt.Println("No Secret entered. Returning to Previous Menu...")
			time.Sleep(2 * time.Second)
			return nil
		}
	}

	templatesResp, err := acme.TemplatePatternsGet("keyfactor")
	if err != nil {
		return err
	}
	defer templatesResp.Body.Close()

	var templates []map[string]any
	if err := json.NewDecoder(templatesResp.Body).Decode(&templates); err != nil {
		return err
	}

	selectedTemplate := helpers.DisplayTemplatesAndGetChoice(templates)
	if selectedTemplate == "" {
		return nil
	}

	result, err := acme.KeyManagementGet(selectedTemplate, nil, "")
	if err != nil {
		fmt.Println("You do not have access to EAB keys for that template. Returning to Previous Menu...")
		time.Sleep(1 * time.Second)
		return nil
	}
	if result == nil || result.Body == nil {
		fmt.Println("Key management request returned no response. Returning to Previous Menu...")
		time.Sleep(1 * time.Second)
		return nil
	}
	defer result.Body.Close()

	body, err := io.ReadAll(result.Body)
	if err != nil {
		fmt.Println("Failed to read EAB response. Returning to Previous Menu...")
		time.Sleep(1 * time.Second)
		return nil
	}

	var keyResp KeyfactorKeyResponse
	if err := json.Unmarshal(body, &keyResp); err != nil {
		return err
	}

	fmt.Printf("keyId=%q keyValue=%q\n", keyResp.KeyID, keyResp.KeyValue)
	time.Sleep(5 * time.Second)
	return nil
}
