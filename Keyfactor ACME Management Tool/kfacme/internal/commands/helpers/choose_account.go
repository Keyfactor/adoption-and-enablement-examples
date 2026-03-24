package helpers

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/jedib0t/go-pretty/v6/table"
)

func DisplayAccountsAndGetChoice(accounts []map[string]any) string {
	if len(accounts) == 0 {
		fmt.Println("No accounts found.")
		time.Sleep(2 * time.Second)
		return ""
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

	reader := bufio.NewReader(os.Stdin)
	fmt.Print("Enter the Index User ID of the Keyfactor ACME account you want to change or press Enter to return: ")
	accountChoice, err := reader.ReadString('\n')
	if err != nil {
		fmt.Println("Failed to read input.")
		time.Sleep(2 * time.Second)
		return ""
	}

	accountChoice = strings.TrimSpace(accountChoice)
	if accountChoice == "" {
		fmt.Println("No account selected. Returning...")
		time.Sleep(2 * time.Second)
		return ""
	}

	selectedIndex, err := strconv.Atoi(accountChoice)
	if err != nil {
		fmt.Println("Invalid ID entered. Please try again.")
		time.Sleep(2 * time.Second)
		return ""
	}

	for _, account := range accounts {
		index, ok := account["Index"].(int)
		if !ok || index != selectedIndex {
			continue
		}

		if status, ok := account["status"].(string); ok && status == "revoked" {
			fmt.Printf("Account %v is revoked. Please select another account.\n", account["accountId"])
			time.Sleep(2 * time.Second)
			return DisplayAccountsAndGetChoice(accounts)
		}

		if accountID, ok := account["accountId"].(string); ok {
			return accountID
		}

		fmt.Println("Selected account has no valid accountId.")
		time.Sleep(2 * time.Second)
		return ""
	}

	fmt.Println("Invalid ID entered. Please try again.")
	time.Sleep(2 * time.Second)
	return ""
}
