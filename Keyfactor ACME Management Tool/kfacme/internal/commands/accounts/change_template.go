package accounts

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"kfacme/internal/acme_client"
	"kfacme/internal/commands/helpers"
	"time"
)

func ChangeTemplate(ctx context.Context, acme *acme_client.AcmeClient) error {
	if acme == nil {
		return fmt.Errorf("acme client is nil")
	}

	response, err := acme.AdminAccountsGet("")
	if err != nil {
		return err
	}
	defer response.Body.Close()

	body, err := io.ReadAll(response.Body)
	if err != nil {
		return err
	}

	var accounts []map[string]any
	if err := json.Unmarshal(body, &accounts); err != nil {
		return err
	}

	if len(accounts) == 0 {
		fmt.Println("No accounts found")
		return nil
	}

	accountID := helpers.DisplayAccountsAndGetChoice(accounts)
	if accountID == "" {
		return nil
	}

	var selectedAccount map[string]any
	for _, account := range accounts {
		if id, ok := account["accountId"].(string); ok && id == accountID {
			selectedAccount = account
			break
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

	template := helpers.DisplayTemplatesAndGetChoice(templates)
	if template == "" {
		return nil
	}

	if currentTemplate, ok := selectedAccount["template"].(string); ok && currentTemplate == template {
		fmt.Println("Account is already set to that template. Returning to Previous menu...")
		time.Sleep(2 * time.Second)
		return nil
	}

	data := map[string]any{
		"template": template,
	}

	putResp, err := acme.AdminAccountsPut(accountID, data, "")
	if err != nil {
		return err
	}
	defer putResp.Body.Close()

	if putResp.StatusCode < 200 || putResp.StatusCode >= 300 {
		return fmt.Errorf("template update failed: %s", putResp.Status)
	}

	fmt.Println("Template mapping updated successfully")
	time.Sleep(1 * time.Second)
	return nil
}
