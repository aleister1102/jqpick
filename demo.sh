#!/bin/bash

# JQPick Demo Script

echo "🎯 JQPick - Interactive JSON Explorer Demo"
echo "=========================================="
echo

# Create sample JSON data
cat > sample_data.json << 'EOF'
{
  "api": {
    "version": "2.0",
    "endpoints": {
      "users": "/api/v2/users",
      "posts": "/api/v2/posts",
      "comments": "/api/v2/comments"
    },
    "limits": {
      "requests_per_minute": 1000,
      "requests_per_hour": 50000
    }
  },
  "users": [
    {
      "id": 1,
      "name": "Alice Johnson",
      "email": "alice@example.com",
      "active": true,
      "roles": ["admin", "user"],
      "profile": {
        "age": 28,
        "location": "San Francisco",
        "interests": ["programming", "hiking", "photography"]
      }
    },
    {
      "id": 2,
      "name": "Bob Smith", 
      "email": "bob@example.com",
      "active": false,
      "roles": ["user"],
      "profile": {
        "age": 32,
        "location": "New York",
        "interests": ["music", "cooking"]
      }
    }
  ],
  "metadata": {
    "generated_at": "2023-12-01T10:00:00Z",
    "total_users": 2,
    "version": "1.0.0"
  }
}
EOF

echo "📋 Sample JSON data created: sample_data.json"
echo
echo "🔍 Let's explore the data with JQPick!"
echo "   - Use arrow keys to navigate"
echo "   - Press Enter to see jq queries"
echo "   - Press / to search"
echo "   - Press q to quit"
echo
echo "💡 Try navigating to:"
echo "   - users[0].name (should show: .users[0].name)"
echo "   - api.endpoints.users (should show: .api.endpoints.users)"
echo "   - metadata.total_users (should show: .metadata.total_users)"
echo

# Check if jqpick binary exists
if [ ! -f "jqpick" ]; then
    echo "❌ jqpick binary not found. Building..."
    go build -o jqpick .
fi

echo "🚀 Starting JQPick..."
echo "   Command: cat sample_data.json | ./jqpick"
echo

# Run JQPick
cat sample_data.json | ./jqpick

echo
echo "✨ Demo completed!"
echo "🧹 Cleaning up..."
rm -f sample_data.json