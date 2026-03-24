package helpers

import (
	"bufio"
	"fmt"
	"os"
	"strings"
	"time"
)

func DisplayRolesAndGetChoice() []string {
	fmt.Println("=== Choose Roles ===")
	fmt.Println("[1] AccountAdmin")
	fmt.Println("[2] EnrollmentUser")
	fmt.Println("[3] SuperAdmin")
	fmt.Println("[4] Exit to Action Menu")
	fmt.Println("You can select multiple roles by entering numbers separated by commas (e.g., 1,3).")

	reader := bufio.NewReader(os.Stdin)
	fmt.Print("Choose which Roles to assign to the Claim (1-4): ")

	input, err := reader.ReadString('\n')
	if err != nil {
		fmt.Println("Failed to read input.")
		time.Sleep(2 * time.Second)
		return nil
	}

	choices := strings.TrimSpace(input)
	if choices == "" {
		fmt.Println("No role selected. Returning...")
		time.Sleep(2 * time.Second)
		return nil
	}

	rolesMapping := map[string]string{
		"1": "AccountAdmin",
		"2": "EnrollmentUser",
		"3": "SuperAdmin",
	}

	roles := make([]string, 0)
	seen := make(map[string]bool)

	for _, choice := range strings.Split(choices, ",") {
		choice = strings.TrimSpace(choice)

		if choice == "4" {
			return nil
		}

		role, ok := rolesMapping[choice]
		if !ok {
			fmt.Printf("Invalid choice: %s.\n", choice)
			time.Sleep(2 * time.Second)
			return nil
		}

		if !seen[role] {
			seen[role] = true
			roles = append(roles, role)
		}
	}

	return roles
}
