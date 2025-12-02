# JQPick - Interactive JSON Explorer and JQ Query Builder

JQPick is an interactive Terminal User Interface (TUI) tool that helps you explore JSON data and learn jq queries by example. Simply pipe JSON data into JQPick and navigate through the structure with your keyboard - it will show you the exact jq query that would select each node.

## Features

- 🎯 **Interactive Navigation**: Navigate JSON structure with arrow keys
- 🔍 **Search**: Find specific keys or values in your JSON
- 📚 **JQ Query Learning**: See the exact jq query for any node
- 🎨 **Syntax Highlighting**: Color-coded JSON values for better readability
- 📖 **Expand/Collapse**: Focus on relevant parts of large JSON files
- ⌨️ **Vim-style Controls**: Use hjkl keys for navigation
- 🚀 **Real-time**: Instant feedback as you navigate

## Installation

```bash
go install github.com/user/jqpick@latest
```

Or build from source:

```bash
git clone https://github.com/user/jqpick
cd jqpick
go build -o jqpick .
```

## Usage

### Basic Usage

```bash
# Explore a JSON file
cat data.json | jqpick

# Explore API responses
curl -s https://api.github.com/users/github | jqpick

# Explore nested JSON
echo '{"users":[{"name":"John","age":30}]}' | jqpick
```

### Interactive Controls

| Key | Action |
|-----|--------|
| `↑/k` | Move cursor up |
| `↓/j` | Move cursor down |
| `←/h` | Collapse current node |
| `→/l` | Expand current node |
| `Space` | Toggle expand/collapse |
| `Enter` | Select node and show jq query |
| `/` | Start search mode |
| `Esc` | Clear search/exit search mode |
| `?` | Toggle help |
| `q` | Quit |

## Examples

### Example 1: Exploring API Data

```bash
# Get GitHub user data and explore it
curl -s https://api.github.com/users/octocat | jqpick

# Navigate to the "public_repos" field
# JQPick shows: .public_repos
# Use it: curl -s https://api.github.com/users/octocat | jq '.public_repos'
```

### Example 2: Complex Nested Data

```bash
# Explore a complex JSON structure
cat << EOF | jqpick
{
  "company": {
    "employees": [
      {
        "name": "Alice",
        "department": "Engineering",
        "skills": ["Go", "Python", "JavaScript"]
      },
      {
        "name": "Bob", 
        "department": "Marketing",
        "skills": ["SEO", "Content", "Analytics"]
      }
    ]
  }
}
EOF

# Navigate to Alice's skills
# JQPick shows: .company.employees[0].skills
# Use it: echo '$json' | jq '.company.employees[0].skills'
```

### Example 3: Learning JQ Queries

```bash
# Start with any JSON file
cat config.json | jqpick

# Navigate to find what you need
# JQPick shows you the exact query syntax:
# - Object access: .key.subkey
# - Array access: .array[0]
# - Nested access: .object.array[0].field
```

## JQ Query Patterns

JQPick helps you learn these common jq patterns:

| Pattern | Example | Description |
|---------|---------|-------------|
| Root | `.` | The entire JSON document |
| Object field | `.name` | Access object property |
| Nested field | `.user.name` | Access nested property |
| Array element | `.items[0]` | Access array element by index |
| Array field | `.users[0].name` | Access field in array element |

## Tips

1. **Start Simple**: Begin with basic JSON to understand the navigation
2. **Use Search**: Press `/` to search for specific keys or values
3. **Expand/Collapse**: Use arrow keys and space to focus on relevant sections
4. **Practice**: The more you use it, the more intuitive jq becomes
5. **Copy Queries**: Select nodes with Enter to see the exact jq syntax

## Building from Source

Requirements:
- Go 1.21 or later

```bash
git clone https://github.com/user/jqpick
cd jqpick
go mod download
go build -o jqpick .
```

## Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest features
- Submit pull requests
- Improve documentation

## License

MIT License - see LICENSE file for details.

## Acknowledgments

Built with:
- [Bubble Tea](https://github.com/charmbracelet/bubbletea) - TUI framework
- [Lipgloss](https://github.com/charmbracelet/lipgloss) - Styling
- [Bubbles](https://github.com/charmbracelet/bubbles) - UI components