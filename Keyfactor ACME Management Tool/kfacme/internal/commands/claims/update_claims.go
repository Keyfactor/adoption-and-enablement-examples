package claims

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"kfacme/internal/acme_client"
	"kfacme/internal/commands/helpers"

	"github.com/jedib0t/go-pretty/v6/table"
)

func UpdateClaim(ctx context.Context, acme *acme_client.AcmeClient) error {
	if acme == nil {
		return fmt.Errorf("acme client is nil")
	}

	reader := bufio.NewReader(os.Stdin)

	for {
		response, err := acme.ClaimGet("", "")
		if err != nil {
			return err
		}
		defer response.Body.Close()

		var claims []map[string]any
		if err := json.NewDecoder(response.Body).Decode(&claims); err != nil {
			return err
		}

		if len(claims) == 0 {
			fmt.Println("No claims found")
			return nil
		}

		fieldNames := []string{"id"}
		for key := range claims[0] {
			if key != "id" {
				fieldNames = append(fieldNames, key)
			}
		}

		t := table.NewWriter()
		header := make(table.Row, 0, len(fieldNames))
		for _, name := range fieldNames {
			header = append(header, name)
		}
		t.AppendHeader(header)

		for _, claim := range claims {
			row := make(table.Row, 0, len(fieldNames))
			for _, field := range fieldNames {
				row = append(row, claim[field])
			}
			t.AppendRow(row)
		}

		fmt.Println(t.Render())
		fmt.Println("Only Claim Roles and Template can be updated")

		fmt.Print("Enter a Claim Id to Update: ")
		input, err := reader.ReadString('\n')
		if err != nil {
			return err
		}

		choiceClaimID := strings.TrimSpace(input)
		if choiceClaimID == "" {
			fmt.Println("No Claim IS Selected, Returning to previous menu")
			time.Sleep(2 * time.Second)
			return nil
		}

		if _, err := strconv.Atoi(choiceClaimID); err != nil {
			fmt.Println("No Claim IS Selected, Returning to previous menu")
			time.Sleep(2 * time.Second)
			return nil
		}

		var matchingClaim map[string]any
		for _, claim := range claims {
			if fmt.Sprint(claim["id"]) == choiceClaimID {
				matchingClaim = claim
				break
			}
		}

		if matchingClaim == nil {
			fmt.Printf("Invalid Claim Id. There is no claim with ID %s.\n", choiceClaimID)
			time.Sleep(2 * time.Second)
			return UpdateClaim(ctx, acme)
		}

		for {
			fmt.Println("=== Update Claim Menu ===")
			fmt.Println("[1] Role")
			fmt.Println("[2] Template")
			fmt.Println("[3] return to Previous Menu")
			fmt.Print("Choose which category you want to update (1-3): ")

			choiceInput, err := reader.ReadString('\n')
			if err != nil {
				return err
			}

			switch strings.TrimSpace(choiceInput) {
			case "1":
				roles := helpers.DisplayRolesAndGetChoice()
				if len(roles) == 0 {
					fmt.Println("No roles selected. Returning to Previous Menu...")
					continue
				}

				matchingClaim["roles"] = roles

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
						return UpdateClaim(ctx, acme)
					}
					matchingClaim["template"] = template
				}

			case "2":
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
					return UpdateClaim(ctx, acme)
				}
				matchingClaim["template"] = template

			case "3":
				fmt.Println("Exiting to Previous menu...")
				return nil

			default:
				fmt.Println("Invalid choice. Please try again.")
				time.Sleep(2 * time.Second)
				return nil
			}
			fmt.Println(matchingClaim)
			result, err := acme.ClaimPut(fmt.Sprint(matchingClaim["id"]), matchingClaim, "")
			if err != nil {
				return err
			}
			defer result.Body.Close()

			if result.StatusCode == 200 {
				fmt.Printf("Claim: %v was updated successfully\n", matchingClaim["claimValue"])
				time.Sleep(2 * time.Second)
				return nil
			}

			bodyBytes, _ := os.ReadFile(os.DevNull)
			_ = bodyBytes
			fmt.Println("Failed to update claim")
			time.Sleep(2 * time.Second)
			return nil
		}
	}
}
