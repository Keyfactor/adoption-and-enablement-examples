package helpers

import "fmt"

type HelpItem struct {
	Option      string
	Description string
}

func ShowHelp(title string, items []HelpItem) {
	fmt.Printf("=== %s Help ===\n", title)
	for _, item := range items {
		fmt.Printf("%s - %s\n", item.Option, item.Description)
	}
	fmt.Println("H - Show help")
	fmt.Println()
}
