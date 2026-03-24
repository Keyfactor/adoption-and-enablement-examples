package identifiers

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"kfacme/internal/acme_client"

	"github.com/jedib0t/go-pretty/v6/table"
)

func ShowIdentifiers(ctx context.Context, acme *acme_client.AcmeClient) error {
	if acme == nil {
		return fmt.Errorf("acme client is nil")
	}

	response, err := acme.IdentifierGet("")
	if err != nil {
		return err
	}
	defer response.Body.Close()

	var identifiers []map[string]any
	if err := json.NewDecoder(response.Body).Decode(&identifiers); err != nil {
		return err
	}

	if len(identifiers) == 0 {
		fmt.Println("No identifiers found")
		return nil
	}

	for idx := range identifiers {
		identifiers[idx]["Index"] = idx + 1
	}

	fieldNames := []string{"Index"}
	for key := range identifiers[0] {
		if key != "Index" {
			fieldNames = append(fieldNames, key)
		}
	}

	t := table.NewWriter()
	header := make(table.Row, 0, len(fieldNames))
	for _, name := range fieldNames {
		header = append(header, name)
	}
	t.AppendHeader(header)

	for _, identifier := range identifiers {
		row := make(table.Row, 0, len(fieldNames))
		for _, field := range fieldNames {
			row = append(row, identifier[field])
		}
		t.AppendRow(row)
	}

	fmt.Println(t.Render())
	fmt.Print("Press Enter to continue...")
	_, _ = fmt.Fscanln(os.Stdin)

	return nil
}
