package system_settings

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"time"

	"kfacme/internal/acme_client"

	"github.com/jedib0t/go-pretty/v6/table"
)

func showSystemSettings(acme *acme_client.AcmeClient) error {
	result, err := acme.AppSettingsGet("")
	if err != nil {
		return err
	}
	defer result.Body.Close()

	body, err := io.ReadAll(result.Body)
	if err != nil {
		return err
	}

	var settings []map[string]any
	if err := json.Unmarshal(body, &settings); err != nil {
		return err
	}

	if len(settings) == 0 {
		fmt.Println("No settings found")
		return nil
	}

	t := table.NewWriter()
	t.SetOutputMirror(os.Stdout)
	t.AppendHeader(table.Row{"id", "name", "value"})

	for _, setting := range settings {
		t.AppendRow(table.Row{
			setting["id"],
			setting["name"],
			setting["value"],
		})
	}

	t.Render()
	time.Sleep(0)
	fmt.Println("Press Enter to continue...")
	_, _ = fmt.Scanln()

	return nil
}
