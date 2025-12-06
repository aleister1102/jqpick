# JQPick

Interactive TUI for exploring JSON and building jq queries.

## Install

```bash
go install github.com/aleister1102/jqpick@latest
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
