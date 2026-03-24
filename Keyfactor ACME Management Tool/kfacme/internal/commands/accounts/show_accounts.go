package accounts

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"

	"kfacme/internal/acme_client"

	"github.com/jedib0t/go-pretty/v6/table"
)

func ShowAccounts(ctx context.Context, acme *acme_client.AcmeClient) error {
	if acme == nil {
		return fmt.Errorf("acme client is nil")
	}

	resp, err := acme.AdminAccountsGet("")
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	var accounts []map[string]any
	if err := json.Unmarshal(body, &accounts); err != nil {
		return err
	}

	if len(accounts) == 0 {
		fmt.Println("No accounts found.")
		waitForEnter()
		return nil
	}

	for i := range accounts {
		accounts[i]["Index"] = i + 1
	}

	fieldNames := []string{"Index"}
	for key := range accounts[0] {
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

	for _, account := range accounts {
		row := make(table.Row, 0, len(fieldNames))
		for _, field := range fieldNames {
			row = append(row, account[field])
		}
		t.AppendRow(row)
	}

	fmt.Println(t.Render())
	waitForEnter()

	_ = ctx
	return nil
}

func waitForEnter() {
	reader := bufio.NewReader(os.Stdin)
	fmt.Print("Press Enter to return to the menu...")
	_, _ = reader.ReadString('\n')
}
