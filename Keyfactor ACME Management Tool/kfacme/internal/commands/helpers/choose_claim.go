package helpers

import (
	"bufio"
	"fmt"
	"os"
	"strings"
	"time"
)

func DisplayClaimTypesAndGetChoice() string {
	fmt.Println("=== Choose ClaimType ===")
	fmt.Println("[1] Role")
	fmt.Println("[2] Subject")
	fmt.Println("[3] Client Id")
	fmt.Println("[4] Exit to Action Menu")
	fmt.Println("You can only select one ClaimType.")

	reader := bufio.NewReader(os.Stdin)
	fmt.Print("Choose which ClaimType to assign to the Claim (1-4): ")

	input, err := reader.ReadString('\n')
	if err != nil {
		fmt.Println("Failed to read input.")
		time.Sleep(2 * time.Second)
		return ""
	}

	choice := strings.TrimSpace(input)
	if choice == "" {
		fmt.Println("No ClaimType selected. Returning...")
		time.Sleep(2 * time.Second)
		return ""
	}

	if choice == "4" {
		return ""
	}

	typeMapping := map[string]string{
		"1": "role",
		"2": "sub",
		"3": "clientid",
	}

	claimType, ok := typeMapping[choice]
	if !ok {
		fmt.Printf("Invalid choice: %s.\n", choice)
		time.Sleep(2 * time.Second)
		return ""
	}

	return claimType
}
