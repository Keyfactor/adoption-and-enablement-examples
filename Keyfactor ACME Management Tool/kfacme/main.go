package main

import (
	"context"
	"flag"
	"fmt"
	"os"

	"kfacme/internal/acme_client"
	"kfacme/internal/commands"
	"kfacme/internal/config"
)

func run() error {
	configPath := flag.String("config", "", "path to config file")
	flag.Parse()

	cfg, err := config.Load(*configPath)
	if err != nil {
		return err
	}
	if err := cfg.Validate(); err != nil {
		return err
	}

	ctx := context.Background()

	acme := acme_client.NewAcmeClient(acme_client.Variables{
		"acme_dns":           cfg.BaseURL,
		"client_id":          cfg.ClientID,
		"client_secret":      cfg.ClientSecret,
		"scope":              cfg.Scope,
		"audience":           cfg.Audience,
		"oidc_discovery_url": cfg.OIDCDiscoveryURL,
		"KeyfactorURL":       cfg.KeyfactorURL,
	}, 3, 1)

	if err := acme.InitializeAuth(ctx); err != nil {
		return err
	}

	return commands.SubMenu(ctx, acme)
}

func printHelp() {
	fmt.Println(`Usage:
  kfacme [options]

Commands:
  no arg    Starts the interactive menu
  -config   path to config json file
  -h,-help Show this help screen

Options:
  -h, --help   Show help`)
}

func main() {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "-h", "--help", "help":
			printHelp()
			return
		}
	}

	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
