package identifiers

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/jedib0t/go-pretty/v6/table"

	"kfacme/internal/acme_client"
)

func RemoveIdentifier(client *acme_client.AcmeClient) error {
	response, err := client.IdentifierGet("")
	if err != nil {
		return err
	}
	defer response.Body.Close()

	var identifiers []map[string]any
	if err := json.NewDecoder(response.Body).Decode(&identifiers); err != nil {
		fmt.Println("Failed to decode identifiers:", err)
		time.Sleep(2 * time.Second)
		return nil
	}

	if len(identifiers) == 0 {
		fmt.Println("No identifiers found")
		time.Sleep(2 * time.Second)
		return nil
	}

	for idx, claim := range identifiers {
		claim["Index"] = idx + 1
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

	for _, claim := range identifiers {
		row := make(table.Row, 0, len(fieldNames))
		for _, field := range fieldNames {
			row = append(row, claim[field])
		}
		t.AppendRow(row)
	}

	fmt.Println(t.Render())

	reader := bufio.NewReader(os.Stdin)
	fmt.Print("Choose an index to remove (press Enter to go back): ")
	choice, err := reader.ReadString('\n')
	if err != nil {
		fmt.Println("Failed to read input.")
		time.Sleep(2 * time.Second)
		return nil
	}

	choice = strings.TrimSpace(choice)
	if choice == "" {
		return nil
	}

	if _, err := strconv.Atoi(choice); err != nil {
		fmt.Println("Invalid choice. Please enter a number.")
		time.Sleep(2 * time.Second)
		RemoveIdentifier(client)
		return nil
	}

	selectedIndex, _ := strconv.Atoi(choice)
	var matchingIdentifier map[string]any
	for _, claim := range identifiers {
		if idx, ok := claim["Index"].(int); ok && idx == selectedIndex {
			matchingIdentifier = claim
			break
		}
	}

	if matchingIdentifier == nil {
		fmt.Printf("Invalid choice. There is no index value of %d.\n", selectedIndex)
		time.Sleep(2 * time.Second)
		RemoveIdentifier(client)
		return nil
	}

	id, ok := matchingIdentifier["id"].(string)
	if !ok || id == "" {
		fmt.Println("Selected identifier has no valid id.")
		time.Sleep(2 * time.Second)
		return nil
	}

	result, err := client.IdentifierDelete(id, "")
	if err != nil {
		fmt.Println("Failed to delete identifier:", err)
		time.Sleep(2 * time.Second)
		return nil
	}
	defer result.Body.Close()

	if result.StatusCode == 204 {
		fmt.Printf("Identifier with ID %s removed successfully.\n", id)
		time.Sleep(2 * time.Second)
		return nil
	}

	body, _ := bufio.NewReader(result.Body).ReadString(0)
	fmt.Println(strings.TrimSpace(body))
	time.Sleep(2 * time.Second)
	return nil
}
