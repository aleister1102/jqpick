.PHONY: build test install uninstall clean help release bump-patch bump-minor bump-major

BINARY_NAME=jqpick
BUILD_DIR=dist
VERSION=$(shell git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
NEXT_PATCH=$(shell echo $(VERSION) | awk -F. '{print $$1"."$$2"."$$3+1}')
NEXT_MINOR=$(shell echo $(VERSION) | awk -F. '{print $$1"."$$2+1".0"}')
NEXT_MAJOR=$(shell echo $(VERSION) | awk -F. '{v=$$1; sub(/v/,"",v); print "v"v+1".0.0"}')
COMMIT=$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
DATE=$(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
LDFLAGS=-ldflags "-X main.Version=$(VERSION) -X main.Commit=$(COMMIT) -X main.Date=$(DATE) -s -w"

help: ## Show help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

version: ## Show current version
	@echo "Current: $(VERSION)"
	@echo "Patch:   $(NEXT_PATCH)"
	@echo "Minor:   $(NEXT_MINOR)"
	@echo "Major:   $(NEXT_MAJOR)"

build: ## Build binary
	@go build $(LDFLAGS) -o $(BINARY_NAME) .

test: ## Run tests
	@go test ./...

install: build ## Install to ~/.local/bin
	@mkdir -p $(HOME)/.local/bin
	@install -m 755 $(BINARY_NAME) $(HOME)/.local/bin/$(BINARY_NAME)

uninstall: ## Uninstall
	@rm -f $(HOME)/.local/bin/$(BINARY_NAME)

clean: ## Clean build artifacts
	@rm -f $(BINARY_NAME)
	@rm -rf $(BUILD_DIR)

release: ## Release new version (usage: make release TAG=v1.0.0)
	@if [ -z "$(TAG)" ]; then echo "Usage: make release TAG=v1.0.0"; exit 1; fi
	@echo "Releasing $(TAG)..."
	@go test ./...
	@rm -rf $(BUILD_DIR) && mkdir -p $(BUILD_DIR)
	@echo "Building binaries..."
	@GOOS=linux GOARCH=amd64 go build -ldflags "-X main.Version=$(TAG) -X main.Commit=$(COMMIT) -X main.Date=$(DATE) -s -w" -o $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64 .
	@GOOS=linux GOARCH=arm64 go build -ldflags "-X main.Version=$(TAG) -X main.Commit=$(COMMIT) -X main.Date=$(DATE) -s -w" -o $(BUILD_DIR)/$(BINARY_NAME)-linux-arm64 .
	@GOOS=darwin GOARCH=amd64 go build -ldflags "-X main.Version=$(TAG) -X main.Commit=$(COMMIT) -X main.Date=$(DATE) -s -w" -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-amd64 .
	@GOOS=darwin GOARCH=arm64 go build -ldflags "-X main.Version=$(TAG) -X main.Commit=$(COMMIT) -X main.Date=$(DATE) -s -w" -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-arm64 .
	@GOOS=windows GOARCH=amd64 go build -ldflags "-X main.Version=$(TAG) -X main.Commit=$(COMMIT) -X main.Date=$(DATE) -s -w" -o $(BUILD_DIR)/$(BINARY_NAME)-windows-amd64.exe .
	@GOOS=windows GOARCH=arm64 go build -ldflags "-X main.Version=$(TAG) -X main.Commit=$(COMMIT) -X main.Date=$(DATE) -s -w" -o $(BUILD_DIR)/$(BINARY_NAME)-windows-arm64.exe .
	@cd $(BUILD_DIR) && shasum -a 256 * > checksums.txt
	@echo "Creating GitHub release..."
	@git tag -a $(TAG) -m "Release $(TAG)"
	@git push origin $(TAG)
	@gh release create $(TAG) $(BUILD_DIR)/* --title "$(BINARY_NAME) $(TAG)" --generate-notes
	@echo "Done: $(TAG)"

bump-patch: ## Release next patch version
	@$(MAKE) release TAG=$(NEXT_PATCH)

bump-minor: ## Release next minor version
	@$(MAKE) release TAG=$(NEXT_MINOR)

bump-major: ## Release next major version
	@$(MAKE) release TAG=$(NEXT_MAJOR)
