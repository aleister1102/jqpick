package main

import (
	"fmt"
	"strconv"
	"strings"
)

func buildJSONTree(data interface{}, parent *JSONNode, key string) *JSONNode {
	node := &JSONNode{
		Key:      key,
		Value:    data,
		Parent:   parent,
		Expanded: true,
		Children: []*JSONNode{},
	}

	switch v := data.(type) {
	case map[string]interface{}:
		node.Type = "object"
		for k, val := range v {
			child := buildJSONTree(val, node, k)
			node.Children = append(node.Children, child)
		}
	case []interface{}:
		node.Type = "array"
		for i, val := range v {
			child := buildJSONTree(val, node, strconv.Itoa(i))
			node.Children = append(node.Children, child)
		}
	case string:
		node.Type = "string"
	case float64:
		node.Type = "number"
	case bool:
		node.Type = "boolean"
	case nil:
		node.Type = "null"
	}

	return node
}

func (n *JSONNode) getDisplayName() string {
	if n.Parent != nil && n.Parent.Type == "array" {
		return fmt.Sprintf("[%s]", n.Key)
	}
	return n.Key
}

func (n *JSONNode) getValuePreview() string {
	switch n.Type {
	case "string":
		str := n.Value.(string)
		if len(str) > 50 {
			return fmt.Sprintf("\"%s...\"", str[:47])
		}
		return fmt.Sprintf("\"%s\"", str)
	case "number":
		return fmt.Sprintf("%v", n.Value)
	case "boolean":
		return fmt.Sprintf("%v", n.Value)
	case "null":
		return "null"
	case "object":
		return fmt.Sprintf("{...} (%d keys)", len(n.Children))
	case "array":
		return fmt.Sprintf("[...] (%d items)", len(n.Children))
	default:
		return fmt.Sprintf("%v", n.Value)
	}
}

func (n *JSONNode) getAllVisibleNodes() []*JSONNode {
	var nodes []*JSONNode
	var collectNodes func(*JSONNode)
	
	collectNodes = func(node *JSONNode) {
		nodes = append(nodes, node)
		if node.Expanded {
			for _, child := range node.Children {
				collectNodes(child)
			}
		}
	}
	
	collectNodes(n)
	return nodes
}

func (n *JSONNode) matchesSearch(term string) bool {
	if term == "" {
		return true
	}
	
	termLower := strings.ToLower(term)
	
	// Check key
	if strings.Contains(strings.ToLower(n.Key), termLower) {
		return true
	}
	
	// Check value preview
	if strings.Contains(strings.ToLower(n.getValuePreview()), termLower) {
		return true
	}
	
	// Check type
	if strings.Contains(strings.ToLower(n.Type), termLower) {
		return true
	}
	
	return false
}

func (n *JSONNode) buildJqQuery() string {
	if n.Parent == nil {
		return "."
	}
	
	// Build the path from root to this node
	var pathParts []string
	current := n
	
	for current.Parent != nil {
		if current.Parent.Type == "array" {
			pathParts = append([]string{fmt.Sprintf("[%s]", current.Key)}, pathParts...)
		} else {
			pathParts = append([]string{current.Key}, pathParts...)
		}
		current = current.Parent
	}
	
	// Build the query
	query := ""
	for _, part := range pathParts {
		if strings.HasPrefix(part, "[") {
			// Array access - append directly
			query += part
		} else {
			// Object field access - add dot separator
			if query == "" {
				query = "." + part
			} else {
				query += "." + part
			}
		}
	}
	
	return query
}