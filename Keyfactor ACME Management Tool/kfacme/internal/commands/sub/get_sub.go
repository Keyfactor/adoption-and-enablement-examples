package sub

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"strings"
	"time"

	"kfacme/internal/acme_client"

	"golang.org/x/term"
)

func GetSub(ctx context.Context, acme *acme_client.AcmeClient, clientID, clientSecret string) error {
	if acme == nil {
		return fmt.Errorf("acme client is nil")
	}

	reader := bufio.NewReader(os.Stdin)

	if strings.TrimSpace(clientID) == "" {
		fmt.Print("Enter the Client ID (press enter or return to the previous menu): ")
		input, err := reader.ReadString('\n')
		if err != nil {
			return err
		}
		clientID = strings.TrimSpace(input)
		if clientID == "" {
			fmt.Println("No Client ID entered. Returning to previous menu...")
			time.Sleep(2 * time.Second)
			return nil
		}
	}

	if strings.TrimSpace(clientSecret) == "" {
		fmt.Print("Enter the Client Secret (press enter or return to the previous menu): ")
		secretBytes, err := term.ReadPassword(int(os.Stdin.Fd()))
		if err != nil {
			return err
		}
		clientSecret = strings.TrimSpace(string(secretBytes))
		fmt.Println()

		if clientSecret == "" {
			fmt.Println("No Secret entered. Returning to previous menu...")
			time.Sleep(2 * time.Second)
			return nil
		}
	}

	token, err := acme.GetTokenWithCredentials(ctx, clientID, clientSecret)
	if err != nil {
		fmt.Println("Invalid Client ID or Secret. Please try again.")
		time.Sleep(2 * time.Second)
		return nil
	}

	sub, err := ExtractSubFromToken(token)
	if err != nil {
		fmt.Println(err)
		time.Sleep(2 * time.Second)
		return nil
	}

	fmt.Printf("Extracted subject: %s\n", sub)
	fmt.Println("Press Enter to continue...")
	_, _ = reader.ReadString('\n')

	return nil
}
