package config

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"strconv"
	"strings"
)

type Config struct {
	BaseURL          string `json:"base_url"`
	TimeoutSeconds   int    `json:"timeout_seconds"`
	ClientID         string `json:"client_id"`
	ClientSecret     string `json:"client_secret"`
	OIDCDiscoveryURL string `json:"oidc_discovery_url"`
	Scope            string `json:"scope"`
	Audience         string `json:"audience"`
	CertCheck        bool   `json:"cert_check"`
	KeyfactorURL     string `json:"keyfactor_url"`
}

func promptString(reader *bufio.Reader, name string) (string, error) {
	for {
		fmt.Printf("Enter %s (press Enter to exit): ", name)
		input, err := reader.ReadString('\n')
		if err != nil {
			return "", err
		}

		value := strings.TrimSpace(input)
		if value == "" {
			fmt.Println("No input provided. Exiting application.")
			os.Exit(1)
		}

		if strings.Contains(strings.ToUpper(name), "URL") {
			if _, err := url.ParseRequestURI(value); err != nil {
				fmt.Printf("Invalid URL for %s. Please enter a valid URL.\n", name)
				continue
			}
		}

		return value, nil
	}
}

func promptInt(reader *bufio.Reader, name string) (int, error) {
	for {
		v, err := promptString(reader, name)
		if err != nil {
			return 0, err
		}
		n, err := strconv.Atoi(v)
		if err == nil && n > 0 {
			return n, nil
		}
		fmt.Println("Please enter a valid positive number.")
	}
}

func (c *Config) Validate() error {
	if c.BaseURL == "" {
		return fmt.Errorf("BASE_URL is required")
	}
	if c.ClientID == "" {
		return fmt.Errorf("CLIENT_ID is required")
	}
	if c.ClientSecret == "" {
		return fmt.Errorf("CLIENT_SECRET is required")
	}
	if c.OIDCDiscoveryURL == "" {
		return fmt.Errorf("OIDC_DISCOVERY_URL is required")
	}
	if c.Scope == "" {
		return fmt.Errorf("SCOPE is required")
	}
	if c.Audience == "" {
		return fmt.Errorf("AUDIENCE is required")
	}
	if c.KeyfactorURL == "" {
		return fmt.Errorf("KEYFACTOR_URL is required")
	}
	if c.TimeoutSeconds <= 0 {
		return fmt.Errorf("TIMEOUT_SECONDS must be greater than 0")
	}
	return nil
}

func Load(configPath string) (*Config, error) {
	cfg := &Config{
		CertCheck:      false,
		TimeoutSeconds: 30,
	}

	applyEnvOverrides(cfg)

	if configFile := strings.TrimSpace(configPath); configFile != "" {
		fileCfg, err := loadFromFile(configFile)
		if err != nil {
			return nil, err
		}
		mergeMissing(cfg, fileCfg)
	} else if configFile := strings.TrimSpace(os.Getenv("CONFIG_FILE")); configFile != "" {
		fileCfg, err := loadFromFile(configFile)
		if err != nil {
			return nil, err
		}
		mergeMissing(cfg, fileCfg)
	}

	if err := promptForMissing(cfg); err != nil {
		return nil, err
	}

	if err := cfg.Validate(); err != nil {
		return nil, err
	}

	return cfg, nil
}

func applyEnvOverrides(cfg *Config) {
	if v := envOrEmpty("BASE_URL"); v != "" {
		cfg.BaseURL = v
	}
	if v := envOrEmpty("CLIENT_ID"); v != "" {
		cfg.ClientID = v
	}
	if v := envOrEmpty("CLIENT_SECRET"); v != "" {
		cfg.ClientSecret = v
	}
	if v := envOrEmpty("OIDC_DISCOVERY_URL"); v != "" {
		cfg.OIDCDiscoveryURL = v
	}
	if v := envOrEmpty("SCOPE"); v != "" {
		cfg.Scope = v
	}
	if v := envOrEmpty("AUDIENCE"); v != "" {
		cfg.Audience = v
	}
	if v := envOrEmpty("KEYFACTOR_URL"); v != "" {
		cfg.KeyfactorURL = v
	}

	if v, ok := parseIntEnv("TIMEOUT_SECONDS"); ok {
		cfg.TimeoutSeconds = v
	}
	if v, ok := parseBoolEnv("CERT_CHECK"); ok {
		cfg.CertCheck = v
	}
}

func loadFromFile(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read config file: %w", err)
	}

	var cfg Config
	if err := json.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("parse config file: %w", err)
	}

	return &cfg, nil
}

func mergeMissing(dst, src *Config) {
	if dst.BaseURL == "" {
		dst.BaseURL = src.BaseURL
	}
	if dst.ClientID == "" {
		dst.ClientID = src.ClientID
	}
	if dst.ClientSecret == "" {
		dst.ClientSecret = src.ClientSecret
	}
	if dst.OIDCDiscoveryURL == "" {
		dst.OIDCDiscoveryURL = src.OIDCDiscoveryURL
	}
	if dst.Scope == "" {
		dst.Scope = src.Scope
	}
	if dst.Audience == "" {
		dst.Audience = src.Audience
	}
	if dst.KeyfactorURL == "" {
		dst.KeyfactorURL = src.KeyfactorURL
	}
	if dst.TimeoutSeconds == 30 {
		return
	}
	if dst.TimeoutSeconds == 0 {
		dst.TimeoutSeconds = src.TimeoutSeconds
	}
}

func promptForMissing(cfg *Config) error {
	reader := bufio.NewReader(os.Stdin)

	if cfg.BaseURL == "" {
		v, err := promptString(reader, "BASE_URL")
		if err != nil {
			return err
		}
		cfg.BaseURL = v
	}
	if cfg.ClientID == "" {
		v, err := promptString(reader, "CLIENT_ID")
		if err != nil {
			return err
		}
		cfg.ClientID = v
	}
	if cfg.ClientSecret == "" {
		v, err := promptString(reader, "CLIENT_SECRET")
		if err != nil {
			return err
		}
		cfg.ClientSecret = v
	}
	if cfg.OIDCDiscoveryURL == "" {
		v, err := promptString(reader, "OIDC_DISCOVERY_URL")
		if err != nil {
			return err
		}
		cfg.OIDCDiscoveryURL = v
	}
	if cfg.Scope == "" {
		v, err := promptString(reader, "SCOPE")
		if err != nil {
			return err
		}
		cfg.Scope = v
	}
	if cfg.Audience == "" {
		v, err := promptString(reader, "AUDIENCE")
		if err != nil {
			return err
		}
		cfg.Audience = v
	}
	if cfg.KeyfactorURL == "" {
		v, err := promptString(reader, "KEYFACTOR_URL")
		if err != nil {
			return err
		}
		cfg.KeyfactorURL = v
	}
	if cfg.TimeoutSeconds <= 0 {
		v, err := promptInt(reader, "TIMEOUT_SECONDS")
		if err != nil {
			return err
		}
		cfg.TimeoutSeconds = v
	}

	return nil
}

func envOrEmpty(key string) string {
	return strings.TrimSpace(os.Getenv(key))
}

func parseIntEnv(key string) (int, bool) {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return 0, false
	}

	v, err := strconv.Atoi(raw)
	if err != nil {
		return 0, false
	}
	return v, true
}

func parseBoolEnv(key string) (bool, bool) {
	raw := strings.TrimSpace(strings.ToLower(os.Getenv(key)))
	if raw == "" {
		return false, false
	}

	switch raw {
	case "1", "true", "yes", "y", "on":
		return true, true
	case "0", "false", "no", "n", "off":
		return false, true
	default:
		return false, false
	}
}
