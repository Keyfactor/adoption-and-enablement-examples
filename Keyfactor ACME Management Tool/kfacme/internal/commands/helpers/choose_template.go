package helpers

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

func DisplayTemplatesAndGetChoice(templates []map[string]any) string {
	fmt.Println("made it to template chooser")
	fmt.Printf("%-10s%-20s%-20s\n", "ID", "Template Name", "Pattern Name")
	fmt.Println(strings.Repeat("-", 50))

	for _, template := range templates {
		id, _ := template["Id"]
		templateName := ""
		patternName := ""

		if tmpl, ok := template["Template"].(map[string]any); ok {
			if v, ok := tmpl["TemplateName"].(string); ok {
				templateName = v
			}
		}

		if v, ok := template["Name"].(string); ok {
			patternName = v
		}

		fmt.Printf("%-10v%-20s%-20s\n", id, templateName, patternName)
	}

	fmt.Println(strings.Repeat("-", 50))

	reader := bufio.NewReader(os.Stdin)
	fmt.Print("Enter the ID of the Certificate Template to associate with this claim or press Enter to return: ")

	input, _ := reader.ReadString('\n')
	templateChoice := strings.TrimSpace(input)

	if templateChoice == "" {
		fmt.Println("No template selected. Returning...")
		time.Sleep(2 * time.Second)
		return ""
	}

	choiceID, err := strconv.Atoi(templateChoice)
	if err != nil {
		fmt.Println("Invalid ID entered. Please try again.")
		time.Sleep(2 * time.Second)
		return ""
	}

	for _, template := range templates {
		idVal, ok := template["Id"]
		if !ok {
			continue
		}

		var idInt int
		switch v := idVal.(type) {
		case int:
			idInt = v
		case int32:
			idInt = int(v)
		case int64:
			idInt = int(v)
		case float64:
			idInt = int(v)
		default:
			continue
		}

		if idInt == choiceID {
			if tmpl, ok := template["Template"].(map[string]any); ok {
				if cn, ok := tmpl["CommonName"].(string); ok {
					return cn
				}
			}
			return ""
		}
	}

	fmt.Println("Invalid ID entered. Please try again.")
	time.Sleep(2 * time.Second)
	return ""
}
