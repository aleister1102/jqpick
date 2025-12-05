#!/usr/bin/env bash
set -euo pipefail

BINARY_NAME="jqpick"
BUILD_DIR="dist"
VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 v1.5.0"
    exit 1
fi

[[ ! "$VERSION" =~ ^v ]] && VERSION="v$VERSION"

if git rev-parse "$VERSION" &> /dev/null; then
    echo "Tag $VERSION already exists"
    exit 1
fi

# Run tests
echo "Running tests..."
go test ./...

# Build binaries
echo "Building binaries..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

COMMIT=$(git rev-parse --short HEAD)
DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
LDFLAGS="-X main.Version=$VERSION -X main.Commit=$COMMIT -X main.Date=$DATE -s -w"

PLATFORMS=("linux/amd64" "linux/arm64" "darwin/amd64" "darwin/arm64" "windows/amd64" "windows/arm64")

for platform in "${PLATFORMS[@]}"; do
    OS="${platform%/*}"
    ARCH="${platform#*/}"
    OUTPUT="$BUILD_DIR/${BINARY_NAME}-${OS}-${ARCH}"
    [[ "$OS" == "windows" ]] && OUTPUT="${OUTPUT}.exe"
    
    echo "  $OS/$ARCH"
    GOOS="$OS" GOARCH="$ARCH" go build -ldflags "$LDFLAGS" -o "$OUTPUT" .
done

# Create archives
echo "Creating archives..."
cd "$BUILD_DIR"
for binary in ${BINARY_NAME}-*; do
    [[ ! -f "$binary" ]] && continue
    if [[ "$binary" =~ \.exe$ ]]; then
        zip -q "${binary%.exe}.zip" "$binary"
    else
        tar -czf "${binary}.tar.gz" "$binary"
    fi
done

# Checksums
shasum -a 256 *.tar.gz *.zip > checksums.txt
cd - > /dev/null

# Create tag and push
echo "Creating tag $VERSION..."
git tag -a "$VERSION" -m "Release $VERSION"
git push origin "$VERSION"

# Create release
echo "Creating GitHub release..."
gh release create "$VERSION" \
    "$BUILD_DIR"/*.tar.gz \
    "$BUILD_DIR"/*.zip \
    "$BUILD_DIR"/checksums.txt \
    --title "$BINARY_NAME $VERSION" \
    --generate-notes

echo "Done: $VERSION"
