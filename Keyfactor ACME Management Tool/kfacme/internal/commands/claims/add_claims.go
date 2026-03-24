package claims

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"

	"kfacme/internal/acme_client"
	"kfacme/internal/commands/helpers"
)

func AddClaim(acme *acme_client.AcmeClient) error {
	roles := helpers.DisplayRolesAndGetChoice()
	if len(roles) == 0 {
		fmt.Println("No roles selected. Returning to Previous Menu...")
		time.Sleep(2 * time.Second)
		return nil
	}

	claimType := helpers.DisplayClaimTypesAndGetChoice()
	if claimType == "" {
		fmt.Println("No claim type selected. Returning to Previous Menu...")
		time.Sleep(2 * time.Second)
		return nil
	}

	fmt.Println("=== Enter Claim Value ===")
	reader := bufio.NewReader(os.Stdin)

	fmt.Print("Enter the Claim Value to assign to the Claim: ")
	input, err := reader.ReadString('\n')
	if err != nil {
		fmt.Println("Failed to read input.")
		time.Sleep(2 * time.Second)
		return err
	}

	claimValue := strings.TrimSpace(input)

	body := map[string]any{
		"ClaimType":  claimType,
		"ClaimValue": claimValue,
		"Roles":      roles,
	}

	if containsRole(roles, "EnrollmentUser") {
		resp, err := acme.TemplatePatternsGet("keyfactor")
		if err != nil {
			return err
		}
		defer resp.Body.Close()

		var templates []map[string]any
		if err := json.NewDecoder(resp.Body).Decode(&templates); err != nil {
			return err
		}
		template := helpers.DisplayTemplatesAndGetChoice(templates)
		if template == "" {
			return AddClaim(acme)
		}
		body["Template"] = template
	}

	result, err := acme.ClaimPost(body, "")
	if err != nil {
		return err
	}

	if result.StatusCode == 200 {
		fmt.Printf("Claim: %s was added successfully\n", claimValue)
		time.Sleep(2 * time.Second)
		return nil
	}

	if result.StatusCode != 200 {
		fmt.Println("Failed to add claim")
		time.Sleep(2 * time.Second)
		return nil
	}
	return nil
}

func containsRole(roles []string, target string) bool {
	for _, role := range roles {
		if role == target {
			return true
		}
	}
	return false
}
