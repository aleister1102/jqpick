package main

import (
	"fmt"
	"os"
	"strings"

	osc52 "github.com/aymanbagabas/go-osc52/v2"
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
			Foreground(lipgloss.Color("#1A1B26")).
			Bold(true)

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
	matchStyle  = lipgloss.NewStyle().Background(lipgloss.Color("#9ECE6A")).Foreground(lipgloss.Color("#1A1B26")).Bold(true)
)

type keyMap struct {
	Up       key.Binding
	Down     key.Binding
	Left     key.Binding
	Right    key.Binding
	PageUp   key.Binding
	PageDown key.Binding
	Expand   key.Binding
	Collapse key.Binding
	Select   key.Binding
	Copy     key.Binding
	Search   key.Binding
	Back     key.Binding
	Quit     key.Binding
	Help     key.Binding
	Wrap     key.Binding
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
	PageUp: key.NewBinding(
		key.WithKeys("pgup", "ctrl+u"),
		key.WithHelp("PgUp", "page up"),
	),
	PageDown: key.NewBinding(
		key.WithKeys("pgdown", "ctrl+d"),
		key.WithHelp("PgDn", "page down"),
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
	Copy: key.NewBinding(
		key.WithKeys("y"),
		key.WithHelp("y", "copy jq query"),
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
	Wrap: key.NewBinding(
		key.WithKeys("w"),
		key.WithHelp("w", "toggle wrap"),
	),
}

func (k keyMap) ShortHelp() []key.Binding {
	return []key.Binding{k.Up, k.Down, k.Select, k.Copy, k.Wrap, k.Quit, k.Help}
}

func (k keyMap) FullHelp() [][]key.Binding {
	return [][]key.Binding{
		{k.Up, k.Down, k.Left, k.Right},
		{k.Select, k.Copy, k.Search, k.Back, k.Quit},
		{k.Wrap, k.Help},
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
				m.updateFilteredNodes()
			case "backspace":
				if len(m.searchTerm) > 0 {
					m.searchTerm = m.searchTerm[:len(m.searchTerm)-1]
				}
				m.updateFilteredNodes()
			case "enter":
				m.searchMode = false
			case "up", "down":
				// Allow navigation in search mode
				if msg.String() == "up" && m.cursor > 0 {
					m.cursor--
				} else if msg.String() == "down" && m.cursor < len(m.filtered)-1 {
					m.cursor++
				}
			default:
				if len(msg.String()) == 1 {
					m.searchTerm += msg.String()
					m.updateFilteredNodes()
				}
			}
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
		case key.Matches(msg, keys.PageUp):
			pageSize := m.height / 2
			if pageSize < 1 {
				pageSize = 10
			}
			m.cursor -= pageSize
			if m.cursor < 0 {
				m.cursor = 0
			}
		case key.Matches(msg, keys.PageDown):
			visibleNodes := m.root.getAllVisibleNodes()
			pageSize := m.height / 2
			if pageSize < 1 {
				pageSize = 10
			}
			m.cursor += pageSize
			if m.cursor >= len(visibleNodes) {
				m.cursor = len(visibleNodes) - 1
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
		case key.Matches(msg, keys.Copy):
			if m.selected != nil {
				query := m.selected.buildJqQuery()
				m.jqQuery = query
				_, _ = fmt.Fprint(os.Stderr, osc52.New(query))
			}
		case key.Matches(msg, keys.Search):
			m.searchMode = true
		case key.Matches(msg, keys.Help):
			m.showHelp = !m.showHelp
		case key.Matches(msg, keys.Wrap):
			m.wrapValues = !m.wrapValues
		case msg.String() == "space":
			visibleNodes := m.root.getAllVisibleNodes()
			if m.cursor < len(visibleNodes) {
				current := visibleNodes[m.cursor]
				if current.Type == "object" || current.Type == "array" {
					current.Expanded = !current.Expanded
				}
			}
		}

	case tea.MouseMsg:
		titleHeight := 2
		searchHeight := 0
		if m.searchMode || m.searchTerm != "" {
			searchHeight = 1
		}
		queryHeight := 0
		if m.jqQuery != "" && m.selected != nil {
			queryHeight = 4
		}
		helpHeight := 2
		treeHeight := m.height - titleHeight - searchHeight - queryHeight - helpHeight - 1

		treeStartY := titleHeight + searchHeight
		if msg.Y >= treeStartY && msg.Y < treeStartY+treeHeight {
			visibleNodes := m.root.getAllVisibleNodes()
			viewHeight := treeHeight - 1
			startIdx := 0
			endIdx := len(visibleNodes)
			if len(visibleNodes) > viewHeight {
				if m.cursor >= startIdx+viewHeight {
					startIdx = m.cursor - viewHeight + 1
				}
				if m.cursor < startIdx {
					startIdx = m.cursor
				}
				endIdx = startIdx + viewHeight
				if endIdx > len(visibleNodes) {
					endIdx = len(visibleNodes)
				}
			}

			rel := msg.Y - treeStartY
			if rel > 0 {
				idx := startIdx + (rel - 1)
				if idx < 0 {
					idx = 0
				}
				if idx >= len(visibleNodes) {
					idx = len(visibleNodes) - 1
				}

				switch msg.Type {
				case tea.MouseLeft:
					m.cursor = idx
					if idx >= 0 && idx < len(visibleNodes) {
						m.selected = visibleNodes[idx]
						m.jqQuery = m.selected.buildJqQuery()
					}
				case tea.MouseRight:
					if idx >= 0 && idx < len(visibleNodes) {
						node := visibleNodes[idx]
						if node.Type == "object" || node.Type == "array" {
							node.Expanded = !node.Expanded
						}
					}
				case tea.MouseWheelUp:
					if m.cursor > 0 {
						m.cursor--
					}
				case tea.MouseWheelDown:
					if m.cursor < len(visibleNodes)-1 {
						m.cursor++
					}
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

	// Calculate heights for each section
	titleHeight := 2 // title + margin
	searchHeight := 0
	if m.searchMode || m.searchTerm != "" {
		searchHeight = 1
	}
	queryHeight := 0
	if m.jqQuery != "" && m.selected != nil {
		queryHeight = 4 // header + query + example + margin
	}
	helpHeight := 2

	// Tree gets remaining height
	treeHeight := m.height - titleHeight - searchHeight - queryHeight - helpHeight - 1

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

	// JSON Tree View with fixed height
	treeView := m.renderTreeView(treeHeight)
	treeStyle := lipgloss.NewStyle().
		Width(m.width).
		Height(treeHeight)
	sections = append(sections, treeStyle.Render(treeView))

	// JQ Query Display
	if m.jqQuery != "" && m.selected != nil {
		querySection := m.renderQuerySection()
		sections = append(sections, querySection)
	}

	// Help menu (multi-line)
	var helpLines []string
	if m.searchMode {
		helpLines = append(helpLines, helpStyle.Render("↑/↓ navigate • type to search"))
		helpLines = append(helpLines, helpStyle.Render("Esc exit search • Enter exit"))
	} else {
		wrapIndicator := ""
		if m.wrapValues {
			wrapIndicator = " [wrap: on]"
		}
		helpLines = append(helpLines, helpStyle.Render("Mouse: click select • right-click toggle • scroll"))
		helpLines = append(helpLines, helpStyle.Render("Enter select • y copy • ? help • w wrap • / search • q quit"+wrapIndicator))
	}
	sections = append(sections, lipgloss.JoinVertical(lipgloss.Left, helpLines...))

	content := lipgloss.JoinVertical(lipgloss.Left, sections...)

	// Apply full terminal size
	return lipgloss.NewStyle().
		Width(m.width).
		Height(m.height).
		Render(content)
}

func (m model) renderTreeView(availableHeight int) string {
	var visibleNodes []*JSONNode
	if m.searchMode || m.searchTerm != "" {
		visibleNodes = m.filtered
	} else {
		visibleNodes = m.root.getAllVisibleNodes()
	}

	var lines []string
	header := headerStyle.Render(fmt.Sprintf("JSON Structure (%d nodes)", len(visibleNodes)))
	lines = append(lines, header)

	// Calculate viewport (subtract 1 for header)
	viewHeight := availableHeight - 1
	if viewHeight < 1 {
		viewHeight = 10
	}

	startIdx := 0
	endIdx := len(visibleNodes)

	if len(visibleNodes) > viewHeight {
		// Keep cursor in view
		if m.cursor >= startIdx+viewHeight {
			startIdx = m.cursor - viewHeight + 1
		}
		if m.cursor < startIdx {
			startIdx = m.cursor
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
	indentLen := len(indent)

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
	keyPartLen := 0
	if node.Key != "" {
		keyPartLen = len(keyName) + 1 // +1 for colon
		if isSelected {
			parts = append(parts, keyName+":")
		} else {
			styledKey := keyName + ":"
			if m.searchTerm != "" {
				styledKey = m.highlightMatch(styledKey, keyStyle)
			} else {
				styledKey = keyStyle.Render(styledKey)
			}
			parts = append(parts, styledKey)
		}
	}

	// Add value preview
	valuePreview := node.getValuePreview()
	var styledValue string
	if isSelected {
		// No color styling when selected - let selectedStyle handle it
		styledValue = valuePreview
	} else {
		// Apply highlighting if searching
		if m.searchTerm != "" {
			styledValue = m.highlightMatch(valuePreview, m.getStyleForType(node.Type))
		} else {
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
		}
	}

	if node.Key != "" {
		parts = append(parts, " "+styledValue)
	} else {
		parts = append(parts, styledValue)
	}

	line := strings.Join(parts, "")

	// Apply word wrap if enabled
	if m.wrapValues && m.width > 0 {
		line = m.wrapLine(line, valuePreview, indentLen+1+keyPartLen+1, node.Type) // +1 for indicator, +1 for space
	}

	if isSelected {
		return selectedStyle.Render(line)
	}

	return line
}

func (m model) getStyleForType(nodeType string) lipgloss.Style {
	switch nodeType {
	case "string":
		return stringStyle
	case "number":
		return numberStyle
	case "boolean":
		return boolStyle
	case "null":
		return nullStyle
	default:
		return lipgloss.NewStyle()
	}
}

func (m model) highlightMatch(text string, baseStyle lipgloss.Style) string {
	if m.searchTerm == "" {
		return baseStyle.Render(text)
	}

	lower := strings.ToLower(text)
	searchLower := strings.ToLower(m.searchTerm)
	idx := strings.Index(lower, searchLower)

	if idx == -1 {
		return baseStyle.Render(text)
	}

	var result strings.Builder
	lastEnd := 0

	for idx != -1 {
		// Add text before match
		if idx > lastEnd {
			result.WriteString(baseStyle.Render(text[lastEnd:idx]))
		}
		// Add highlighted match
		matchEnd := idx + len(m.searchTerm)
		result.WriteString(matchStyle.Render(text[idx:matchEnd]))
		lastEnd = matchEnd

		// Find next match
		nextIdx := strings.Index(lower[lastEnd:], searchLower)
		if nextIdx == -1 {
			idx = -1
		} else {
			idx = lastEnd + nextIdx
		}
	}

	// Add remaining text
	if lastEnd < len(text) {
		result.WriteString(baseStyle.Render(text[lastEnd:]))
	}

	return result.String()
}

func (m model) wrapLine(line string, value string, prefixLen int, nodeType string) string {
	if m.width <= 0 || len(line) <= m.width {
		return line
	}

	// Only wrap string values that are long
	if nodeType != "string" || len(value) < 50 {
		return line
	}

	// Calculate available width for value
	availableWidth := m.width - prefixLen - 4 // some margin
	if availableWidth < 20 {
		return line
	}

	// Get the prefix (everything before the value)
	valueStart := strings.Index(line, value)
	if valueStart == -1 {
		return line
	}
	prefix := line[:valueStart]
	wrapIndent := strings.Repeat(" ", prefixLen)

	// Wrap the value
	var result strings.Builder
	result.WriteString(prefix)

	remaining := value
	firstLine := true
	for len(remaining) > 0 {
		if !firstLine {
			result.WriteString("\n")
			result.WriteString(wrapIndent)
		}
		if len(remaining) <= availableWidth {
			result.WriteString(remaining)
			break
		}
		// Find a good break point
		breakAt := availableWidth
		for breakAt > 0 && remaining[breakAt] != ' ' {
			breakAt--
		}
		if breakAt == 0 {
			breakAt = availableWidth
		}
		result.WriteString(remaining[:breakAt])
		remaining = strings.TrimLeft(remaining[breakAt:], " ")
		firstLine = false
	}

	return result.String()
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
		example := helpStyle.Render(fmt.Sprintf("Example: cat %s | jq '%s'", m.filename, path))
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
	lines = append(lines, "  y       Copy jq query to clipboard")
	lines = append(lines, "  /       Search (start typing)")
	lines = append(lines, "  w       Toggle word wrap for long values")
	lines = append(lines, "  Esc     Clear selection")
	lines = append(lines, "  ?       Toggle this help")
	lines = append(lines, "  q       Quit")

	// Mouse
	lines = append(lines, headerStyle.Render("Mouse:"))
	lines = append(lines, "  Click   Select node")
	lines = append(lines, "  Right   Toggle expand/collapse on object/array")
	lines = append(lines, "  Wheel   Scroll up/down")

	// Examples
	lines = append(lines, headerStyle.Render("Examples:"))
	lines = append(lines, "  cat api.json | jqpick")
	lines = append(lines, "  echo '{\"users\":[{\"name\":\"John\"}]}' | jqpick")
	lines = append(lines, "  curl -s https://api.example.com/data | jqpick")

	return strings.Join(lines, "\n")
}
