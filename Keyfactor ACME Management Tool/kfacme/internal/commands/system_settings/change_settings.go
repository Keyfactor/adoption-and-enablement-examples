package system_settings

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"kfacme/internal/acme_client"
	"strings"
	"time"
)

func changeSetting(ctx context.Context, acme *acme_client.AcmeClient, s string) error {
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

	settingMap := map[string]struct {
		Name         string
		DesiredValue string
		AlreadyMsg   string
	}{
		"wildcard_allow": {
			Name:         "Allow Wildcard Enrollments",
			DesiredValue: "True",
			AlreadyMsg:   "Wildcard Enrollments are already allowed",
		},
		"wildcard_deny": {
			Name:         "Allow Wildcard Enrollments",
			DesiredValue: "False",
			AlreadyMsg:   "Wildcard Enrollments are already denied",
		},
		"revocation_enabled": {
			Name:         "Certificate Revocation Enabled",
			DesiredValue: "True",
			AlreadyMsg:   "Certificate Revocation is already enabled",
		},
		"revocation_disabled": {
			Name:         "Certificate Revocation Enabled",
			DesiredValue: "False",
			AlreadyMsg:   "Certificate Revocation is already disabled",
		},
	}

	config, ok := settingMap[s]
	if !ok {
		fmt.Println("Invalid setting")
		return nil
	}

	var target map[string]any
	for _, setting := range settings {
		if name, _ := setting["name"].(string); name == config.Name {
			target = setting
			break
		}
	}

	if target == nil {
		fmt.Printf("Setting '%s' not found\n", config.Name)
		return nil
	}

	currentValue := strings.ToLower(fmt.Sprint(target["value"]))
	desiredValue := strings.ToLower(config.DesiredValue)

	if currentValue == desiredValue {
		fmt.Println(config.AlreadyMsg)
		time.Sleep(2 * time.Second)
		return nil
	}

	idVal, ok := target["id"]
	if !ok {
		return fmt.Errorf("setting id not found")
	}

	var id int
	switch v := idVal.(type) {
	case float64:
		id = int(v)
	case int:
		id = v
	default:
		return fmt.Errorf("unexpected setting id type")
	}

	result, err = acme.AppSettingsPut(id, map[string]any{"value": config.DesiredValue}, "")
	if err != nil {
		return err
	}
	defer result.Body.Close()

	if result.StatusCode == 204 {
		fmt.Printf("Setting %s was changed successfully\n", s)
		return nil
	}

	fmt.Printf("Setting %s change failed\n", s)
	return nil
}
