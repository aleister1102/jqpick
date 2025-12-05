# JQPick

Interactive TUI for exploring JSON and building jq queries.

![demo](https://github.com/aleister1102/jqpick/assets/demo.gif)

## Install

```bash
# From source
go install github.com/aleister1102/jqpick@latest

# Or clone and build
git clone https://github.com/aleister1102/jqpick
cd jqpick
make install
```

## Usage

```bash
cat data.json | jqpick
curl -s https://api.github.com/users/octocat | jqpick
```

## Controls

| Key | Action |
|-----|--------|
| `↑/k` `↓/j` | Navigate |
| `←/h` `→/l` | Collapse/Expand |
| `Enter` | Select & show jq query |
| `/` | Search |
| `w` | Toggle word wrap |
| `?` | Help |
| `q` | Quit |

## Development

```bash
make build    # Build binary
make test     # Run tests
make install  # Install to /usr/local/bin
```

## Release

```bash
make release TAG=v1.0.0
```

## License

MIT
