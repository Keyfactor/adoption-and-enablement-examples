package claims

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"

	"kfacme/internal/acme_client"

	"github.com/jedib0t/go-pretty/v6/table"
)

func RemoveClaim(ctx context.Context, acme *acme_client.AcmeClient) error {
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

		fmt.Print("Enter the ID of the claim to remove: ")
		input, err := reader.ReadString('\n')
		if err != nil {
			return err
		}
		choiceClaimID := strings.TrimSpace(input)

		var matchingClaim map[string]any
		for _, claim := range claims {
			if fmt.Sprint(claim["id"]) == choiceClaimID {
				matchingClaim = claim
				break
			}
		}

		if matchingClaim == nil {
			fmt.Printf("Claim with ID %s not found.\n", choiceClaimID)
			time.Sleep(2 * time.Second)
			return nil
		}

		claimID := matchingClaim["id"]
		deleteResp, err := acme.ClaimDelete(fmt.Sprint(claimID), "")
		if err != nil {
			return err
		}
		defer deleteResp.Body.Close()

		if deleteResp.StatusCode == 204 {
			fmt.Printf("Claim with ID %v removed successfully.\n", claimID)
			time.Sleep(2 * time.Second)
			return nil
		}

		fmt.Printf("Failed to remove claim with ID %v.\n", claimID)
		time.Sleep(2 * time.Second)
		return nil
	}
}
