package main

import (
	"encoding/json"
	"testing"
)

func TestBuildJqQuery(t *testing.T) {
	testJSON := `{
		"users": [
			{
				"name": "John",
				"age": 30
			},
			{
				"name": "Jane",
				"age": 25
			}
		],
		"settings": {
			"theme": "dark",
			"notifications": true
		}
	}`

	var data interface{}
	json.Unmarshal([]byte(testJSON), &data)
	root := buildJSONTree(data, nil, "")

	tests := []struct {
		name     string
		nodePath []string
		expected string
	}{
		{
			name:     "Root node",
			nodePath: []string{},
			expected: ".",
		},
		{
			name:     "Users array",
			nodePath: []string{"users"},
			expected: ".users",
		},
		{
			name:     "First user",
			nodePath: []string{"users", "0"},
			expected: ".users[0]",
		},
		{
			name:     "First user's name",
			nodePath: []string{"users", "0", "name"},
			expected: ".users[0].name",
		},
		{
			name:     "Settings object",
			nodePath: []string{"settings"},
			expected: ".settings",
		},
		{
			name:     "Theme setting",
			nodePath: []string{"settings", "theme"},
			expected: ".settings.theme",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			node := root
			for _, key := range tt.nodePath {
				found := false
				for _, child := range node.Children {
					if child.Key == key {
						node = child
						found = true
						break
					}
				}
				if !found {
					t.Fatalf("Node path not found: %v", tt.nodePath)
				}
			}

			query := node.buildJqQuery()
			if query != tt.expected {
				t.Errorf("Expected query %s, got %s", tt.expected, query)
			}
		})
	}
}

func TestBuildJqQueryArrayRoot(t *testing.T) {
	// Test JSON array as root
	testJSON := `[{"name": "John"}, {"name": "Jane"}]`

	var data interface{}
	json.Unmarshal([]byte(testJSON), &data)
	root := buildJSONTree(data, nil, "")

	tests := []struct {
		name     string
		nodePath []string
		expected string
	}{
		{
			name:     "Root array",
			nodePath: []string{},
			expected: ".",
		},
		{
			name:     "First element",
			nodePath: []string{"0"},
			expected: ".[0]",
		},
		{
			name:     "First element name",
			nodePath: []string{"0", "name"},
			expected: ".[0].name",
		},
		{
			name:     "Second element",
			nodePath: []string{"1"},
			expected: ".[1]",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			node := root
			for _, key := range tt.nodePath {
				found := false
				for _, child := range node.Children {
					if child.Key == key {
						node = child
						found = true
						break
					}
				}
				if !found {
					t.Fatalf("Node path not found: %v", tt.nodePath)
				}
			}

			query := node.buildJqQuery()
			if query != tt.expected {
				t.Errorf("Expected query %s, got %s", tt.expected, query)
			}
		})
	}
}

func TestNodeMatchesSearch(t *testing.T) {
	testJSON := `{"users": [{"name": "John", "age": 30}]}`

	var data interface{}
	json.Unmarshal([]byte(testJSON), &data)
	root := buildJSONTree(data, nil, "")

	tests := []struct {
		name     string
		nodePath []string
		search   string
		expected bool
	}{
		{
			name:     "Match key",
			nodePath: []string{"users"},
			search:   "users",
			expected: true,
		},
		{
			name:     "Match value",
			nodePath: []string{"users", "0", "name"},
			search:   "john",
			expected: true,
		},
		{
			name:     "Match type",
			nodePath: []string{"users"},
			search:   "array",
			expected: true,
		},
		{
			name:     "No match",
			nodePath: []string{"users"},
			search:   "nonexistent",
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			node := root
			for _, key := range tt.nodePath {
				for _, child := range node.Children {
					if child.Key == key {
						node = child
						break
					}
				}
			}

			result := node.matchesSearch(tt.search)
			if result != tt.expected {
				t.Errorf("Expected %v for search '%s', got %v", tt.expected, tt.search, result)
			}
		})
	}
}
