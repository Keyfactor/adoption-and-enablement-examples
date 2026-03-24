package commands

import (
	"context"
	"fmt"

	"kfacme/internal/acme_client"
)

type StatusCommand struct {
	Client *acme_client.AcmeClient
}

func (c *StatusCommand) Run(ctx context.Context) error {
	if c == nil || c.Client == nil {
		return fmt.Errorf("status command: client is nil")
	}

	ok, err := c.Client.StatusGet("")
	if err != nil {
		return err
	}
	if !ok {
		return fmt.Errorf("status endpoint returned non-204 response")
	}

	fmt.Println("Acme status is good")
	return nil
}
