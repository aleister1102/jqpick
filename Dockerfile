# Build stage
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the binary
RUN make build

# Runtime stage
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache ca-certificates

# Create non-root user
RUN addgroup -g 1000 jqpick && \
    adduser -D -u 1000 -G jqpick jqpick

# Copy binary from builder
COPY --from=builder /app/jqpick /usr/local/bin/jqpick

# Make binary executable
RUN chmod +x /usr/local/bin/jqpick

# Switch to non-root user
USER jqpick

# Set entrypoint
ENTRYPOINT ["jqpick"]

# Default command (show help)
CMD ["--help"]

# Labels
LABEL maintainer="JQPick Team"
LABEL description="Interactive JSON Explorer and JQ Query Builder"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/user/jqpick"
LABEL org.opencontainers.image.description="Interactive JSON Explorer and JQ Query Builder"
LABEL org.opencontainers.image.licenses="MIT"