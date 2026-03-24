package claims

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"kfacme/internal/acme_client"

	"github.com/jedib0t/go-pretty/v6/table"
)

func ShowClaims(ctx context.Context, acme *acme_client.AcmeClient) error {
	if acme == nil {
		return fmt.Errorf("acme client is nil")
	}

	response, err := acme.ClaimGet("", "")
	if err != nil {
		return err
	}
	defer response.Body.Close()

	var claims []map[string]any
	if err := json.NewDecoder(response.Body).Decode(&claims); err != nil {
		return err
	}
	fmt.Println(claims)

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
	fmt.Print("Press Enter to continue...")
	_, _ = fmt.Fscanln(os.Stdin)

	return nil
}
