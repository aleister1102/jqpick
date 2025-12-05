package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"

	tea "github.com/charmbracelet/bubbletea"
)

// Version information (set by build flags)
var (
	Version = "dev"
	Commit  = "unknown"
	Date    = "unknown"
)

type JSONNode struct {
	Key      string
	Value    interface{}
	Type     string
	Children []*JSONNode
	Parent   *JSONNode
	Expanded bool
}

type model struct {
	root       *JSONNode
	cursor     int
	selected   *JSONNode
	viewport   int
	height     int
	width      int
	jqQuery    string
	showHelp   bool
	searchMode bool
	searchTerm string
	filtered   []*JSONNode
	wrapValues bool
	filename   string
}

func main() {
	filename := "file.json"

	// Parse arguments
	args := os.Args[1:]
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--help", "-h":
			printHelp()
			return
		case "--version", "-v":
			printVersion()
			return
		default:
			// Treat as filename for display
			filename = args[i]
		}
	}

	var input []byte
	var err error

	if isStdinAvailable() {
		input, err = io.ReadAll(os.Stdin)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error reading stdin: %v\n", err)
			os.Exit(1)
		}
	} else {
		fmt.Fprintf(os.Stderr, "Error: No input provided. Use: cat file.json | jqpick [filename]\n")
		os.Exit(1)
	}

	var jsonData interface{}
	if err := json.Unmarshal(input, &jsonData); err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing JSON: %v\n", err)
		os.Exit(1)
	}

	root := buildJSONTree(jsonData, nil, "")

	p := tea.NewProgram(
		model{
			root:     root,
			cursor:   0,
			filename: filename,
		},
		tea.WithAltScreen(),
	)

	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error running program: %v\n", err)
		os.Exit(1)
	}
}

func isStdinAvailable() bool {
	stat, _ := os.Stdin.Stat()
	return (stat.Mode() & os.ModeCharDevice) == 0
}

func printVersion() {
	fmt.Printf("JQPick - Interactive JSON Explorer\n")
	fmt.Printf("Version: %s\n", Version)
	fmt.Printf("Commit: %s\n", Commit)
	fmt.Printf("Date: %s\n", Date)
}

func printHelp() {
	fmt.Printf(`JQPick - Interactive JSON Explorer and JQ Query Builder
Version: %s

Usage:
  cat file.json | jqpick [filename] [options]

Arguments:
  filename       Optional filename to display in examples

Options:
  -h, --help     Show this help message
  -v, --version  Show version information

Interactive Controls:
  ↑/k     Move cursor up
  ↓/j     Move cursor down
  ←/h     Collapse current node
  →/l     Expand current node
  Enter   Select current node and show jq query
  Space   Toggle expand/collapse
  /       Search (start typing)
  Esc     Clear search/selection
  q       Quit

Examples:
  cat api.json | jqpick
  echo '{"users":[{"name":"John"}]}' | jqpick
  curl -s https://api.example.com/data | jqpick
`, Version)
}
