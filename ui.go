package main

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/key"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

var (
	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#7AA2F7")).
			MarginBottom(1)

	selectedStyle = lipgloss.NewStyle().
			Background(lipgloss.Color("#7AA2F7")).
			Foreground(lipgloss.Color("#1A1B26"))

	headerStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#9ABDF5"))

	helpStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#565F89"))

	queryStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#9ECE6A")).
			Bold(true)

	stringStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("#9ECE6A"))
	numberStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("#FF9E64"))
	boolStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("#BB9AF7"))
	nullStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("#565F89"))
	keyStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("#7AA2F7"))
)

type keyMap struct {
	Up       key.Binding
	Down     key.Binding
	Left     key.Binding
	Right    key.Binding
	Expand   key.Binding
	Collapse key.Binding
	Select   key.Binding
	Search   key.Binding
	Back     key.Binding
	Quit     key.Binding
	Help     key.Binding
}

var keys = keyMap{
	Up: key.NewBinding(
		key.WithKeys("up", "k"),
		key.WithHelp("↑/k", "move up"),
	),
	Down: key.NewBinding(
		key.WithKeys("down", "j"),
		key.WithHelp("↓/j", "move down"),
	),
	Left: key.NewBinding(
		key.WithKeys("left", "h"),
		key.WithHelp("←/h", "collapse"),
	),
	Right: key.NewBinding(
		key.WithKeys("right", "l"),
		key.WithHelp("→/l", "expand"),
	),
	Expand: key.NewBinding(
		key.WithKeys("right", "l", "space"),
		key.WithHelp("→/space", "expand"),
	),
	Collapse: key.NewBinding(
		key.WithKeys("left", "h"),
		key.WithHelp("←/h", "collapse"),
	),
	Select: key.NewBinding(
		key.WithKeys("enter"),
		key.WithHelp("enter", "select"),
	),
	Search: key.NewBinding(
		key.WithKeys("/"),
		key.WithHelp("/", "search"),
	),
	Back: key.NewBinding(
		key.WithKeys("esc"),
		key.WithHelp("esc", "back"),
	),
	Quit: key.NewBinding(
		key.WithKeys("q", "ctrl+c"),
		key.WithHelp("q", "quit"),
	),
	Help: key.NewBinding(
		key.WithKeys("?"),
		key.WithHelp("?", "help"),
	),
}

func (k keyMap) ShortHelp() []key.Binding {
	return []key.Binding{k.Up, k.Down, k.Select, k.Quit, k.Help}
}

func (k keyMap) FullHelp() [][]key.Binding {
	return [][]key.Binding{
		{k.Up, k.Down, k.Left, k.Right},
		{k.Select, k.Search, k.Back, k.Quit},
	}
}

func (m model) Init() tea.Cmd {
	return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		// Handle search mode
		if m.searchMode {
			switch msg.String() {
			case "esc":
				m.searchMode = false
				m.searchTerm = ""
			case "backspace":
				if len(m.searchTerm) > 0 {
					m.searchTerm = m.searchTerm[:len(m.searchTerm)-1]
				}
			case "enter":
				m.searchMode = false
			default:
				if len(msg.String()) == 1 {
					m.searchTerm += msg.String()
				}
			}
			m.updateFilteredNodes()
			return m, nil
		}

		switch {
		case key.Matches(msg, keys.Quit):
			return m, tea.Quit
		case key.Matches(msg, keys.Up):
			if m.cursor > 0 {
				m.cursor--
			}
		case key.Matches(msg, keys.Down):
			visibleNodes := m.root.getAllVisibleNodes()
			if m.cursor < len(visibleNodes)-1 {
				m.cursor++
			}
		case key.Matches(msg, keys.Left):
			visibleNodes := m.root.getAllVisibleNodes()
			if m.cursor < len(visibleNodes) {
				current := visibleNodes[m.cursor]
				if current.Type == "object" || current.Type == "array" {
					current.Expanded = false
				}
			}
		case key.Matches(msg, keys.Right):
			visibleNodes := m.root.getAllVisibleNodes()
			if m.cursor < len(visibleNodes) {
				current := visibleNodes[m.cursor]
				if current.Type == "object" || current.Type == "array" {
					current.Expanded = true
				}
			}
		case key.Matches(msg, keys.Select):
			visibleNodes := m.root.getAllVisibleNodes()
			if m.cursor < len(visibleNodes) {
				m.selected = visibleNodes[m.cursor]
				m.jqQuery = m.selected.buildJqQuery()
			}
		case key.Matches(msg, keys.Search):
			m.searchMode = true
		case key.Matches(msg, keys.Help):
			m.showHelp = !m.showHelp
		case msg.String() == "space":
			visibleNodes := m.root.getAllVisibleNodes()
			if m.cursor < len(visibleNodes) {
				current := visibleNodes[m.cursor]
				if current.Type == "object" || current.Type == "array" {
					current.Expanded = !current.Expanded
				}
			}
		}

	case tea.WindowSizeMsg:
		m.height = msg.Height
		m.width = msg.Width
	}

	return m, nil
}

func (m model) View() string {
	if m.showHelp {
		return m.renderHelp()
	}

	var sections []string

	// Title
	title := titleStyle.Render("JQPick - Interactive JSON Explorer")
	if m.searchMode {
		title = titleStyle.Render("JQPick - Search Mode (type to search, esc to exit)")
	}
	sections = append(sections, title)

	// Search indicator
	if m.searchMode || m.searchTerm != "" {
		searchInfo := fmt.Sprintf("Search: %s", m.searchTerm)
		if m.searchMode {
			searchInfo += "_" // Cursor
		}
		sections = append(sections, searchInfo)
	}

	// JSON Tree View
	treeView := m.renderTreeView()
	sections = append(sections, treeView)

	// JQ Query Display
	if m.jqQuery != "" && m.selected != nil {
		querySection := m.renderQuerySection()
		sections = append(sections, querySection)
	}

	// Help line
	help := helpStyle.Render("Press ? for help, q to quit")
	sections = append(sections, help)

	return lipgloss.JoinVertical(lipgloss.Left, sections...)
}

func (m model) renderTreeView() string {
	var visibleNodes []*JSONNode
	if m.searchMode || m.searchTerm != "" {
		visibleNodes = m.filtered
	} else {
		visibleNodes = m.root.getAllVisibleNodes()
	}
	
	var lines []string
	header := headerStyle.Render(fmt.Sprintf("JSON Structure (%d nodes)", len(visibleNodes)))
	lines = append(lines, header)

	// Calculate viewport
	viewHeight := m.height - 10 // Reserve space for title, query, help
	startIdx := 0
	endIdx := len(visibleNodes)

	if len(visibleNodes) > viewHeight {
		if m.cursor >= viewHeight {
			startIdx = m.cursor - viewHeight + 1
		}
		endIdx = startIdx + viewHeight
		if endIdx > len(visibleNodes) {
			endIdx = len(visibleNodes)
		}
	}

	for i := startIdx; i < endIdx; i++ {
		node := visibleNodes[i]
		line := m.renderNode(node, i == m.cursor)
		lines = append(lines, line)
	}

	return strings.Join(lines, "\n")
}

func (m model) renderNode(node *JSONNode, isSelected bool) string {
	indent := m.getIndent(node)
	
	// Build the display line
	var parts []string
	parts = append(parts, indent)

	// Add expand/collapse indicator
	if node.Type == "object" || node.Type == "array" {
		if node.Expanded {
			parts = append(parts, "▼")
		} else {
			parts = append(parts, "▶")
		}
	} else {
		parts = append(parts, " ")
	}

	// Add key name
	keyName := node.getDisplayName()
	if node.Key != "" {
		parts = append(parts, keyStyle.Render(keyName+":"))
	}

	// Add value preview
	valuePreview := node.getValuePreview()
	var styledValue string
	switch node.Type {
	case "string":
		styledValue = stringStyle.Render(valuePreview)
	case "number":
		styledValue = numberStyle.Render(valuePreview)
	case "boolean":
		styledValue = boolStyle.Render(valuePreview)
	case "null":
		styledValue = nullStyle.Render(valuePreview)
	default:
		styledValue = valuePreview
	}
	
	if node.Key != "" {
		parts = append(parts, " "+styledValue)
	} else {
		parts = append(parts, styledValue)
	}

	line := strings.Join(parts, "")
	
	if isSelected {
		return selectedStyle.Render(line)
	}
	
	return line
}

func (m *model) updateFilteredNodes() {
	if m.searchTerm == "" {
		m.filtered = m.root.getAllVisibleNodes()
		return
	}
	
	var filtered []*JSONNode
	allNodes := m.root.getAllVisibleNodes()
	
	for _, node := range allNodes {
		if node.matchesSearch(m.searchTerm) {
			filtered = append(filtered, node)
		}
	}
	
	m.filtered = filtered
	// Adjust cursor if needed
	if m.cursor >= len(m.filtered) && len(m.filtered) > 0 {
		m.cursor = len(m.filtered) - 1
	}
}

func (m model) getIndent(node *JSONNode) string {
	level := 0
	current := node
	for current.Parent != nil {
		level++
		current = current.Parent
	}
	return strings.Repeat("  ", level)
}

func (m model) renderQuerySection() string {
	var lines []string
	
	header := headerStyle.Render("JQ Query")
	lines = append(lines, header)
	
	if m.selected != nil {
		path := m.selected.buildJqQuery()
		query := queryStyle.Render(path)
		lines = append(lines, query)
		
		// Add example usage
		example := helpStyle.Render(fmt.Sprintf("Example: cat file.json | jq '%s'", path))
		lines = append(lines, example)
	}
	
	return strings.Join(lines, "\n")
}

func (m model) renderHelp() string {
	var lines []string
	
	title := titleStyle.Render("JQPick Help")
	lines = append(lines, title)
	
	// Navigation
	lines = append(lines, headerStyle.Render("Navigation:"))
	lines = append(lines, "  ↑/k     Move cursor up")
	lines = append(lines, "  ↓/j     Move cursor down")
	lines = append(lines, "  ←/h     Collapse current node")
	lines = append(lines, "  →/l     Expand current node")
	lines = append(lines, "  Space   Toggle expand/collapse")
	
	// Actions
	lines = append(lines, headerStyle.Render("Actions:"))
	lines = append(lines, "  Enter   Select node and show jq query")
	lines = append(lines, "  /       Search (start typing)")
	lines = append(lines, "  Esc     Clear selection")
	lines = append(lines, "  ?       Toggle this help")
	lines = append(lines, "  q       Quit")
	
	// Examples
	lines = append(lines, headerStyle.Render("Examples:"))
	lines = append(lines, "  cat api.json | jqpick")
	lines = append(lines, "  echo '{\"users\":[{\"name\":\"John\"}]}' | jqpick")
	lines = append(lines, "  curl -s https://api.example.com/data | jqpick")
	
	return strings.Join(lines, "\n")
}