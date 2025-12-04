#!/bin/bash

# Installation script for protoc and Go plugins

set -e

echo "Installing Protocol Buffers compiler and Go plugins..."

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

case "${OS}" in
    Linux*)
        echo "Detected Linux"
        if command -v apt-get &> /dev/null; then
            echo "Installing via apt..."
            sudo apt-get update
            sudo apt-get install -y protobuf-compiler
        elif command -v yum &> /dev/null; then
            echo "Installing via yum..."
            sudo yum install -y protobuf-compiler
        elif command -v pacman &> /dev/null; then
            echo "Installing via pacman..."
            sudo pacman -S protobuf
        else
            echo "Could not detect package manager. Please install protobuf-compiler manually."
            exit 1
        fi
        ;;
    Darwin*)
        echo "Detected macOS"
        if command -v brew &> /dev/null; then
            echo "Installing via Homebrew..."
            brew install protobuf
        else
            echo "Homebrew not found. Please install Homebrew first: https://brew.sh"
            exit 1
        fi
        ;;
    *)
        echo "Unsupported OS: ${OS}"
        exit 1
        ;;
esac

# Install Go plugins
echo ""
echo "Installing Go protobuf plugins..."
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

# Verify installation
echo ""
echo "Verifying installation..."
protoc --version
echo ""

# Check if Go bin is in PATH
GOBIN=$(go env GOPATH)/bin
if [[ ":$PATH:" != *":$GOBIN:"* ]]; then
    echo "WARNING: $GOBIN is not in your PATH"
    echo "Add the following to your shell profile (.bashrc, .zshrc, etc.):"
    echo "  export PATH=\"\$PATH:\$(go env GOPATH)/bin\""
else
    echo "Go bin directory is in PATH ✓"
fi

echo ""
echo "Installation complete!"
echo ""
echo "You can now run: make proto"
