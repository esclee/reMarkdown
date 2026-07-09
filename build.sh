#!/bin/bash

# Default to arm64 if no architecture is specified
ARCH=${1:-arm64}

# Validate architecture
if [[ "$ARCH" != "arm64" && "$ARCH" != "armv7h" ]]; then
    echo "Error: Unsupported architecture '$ARCH'. Supported: arm64, armv7h"
    exit 1
fi

echo "Building for architecture: $ARCH"

rm -rf rmd
mkdir -p rmd/backend
cp manifest.json rmd
cp icon.png rmd
rcc --binary -o rmd/resources.rcc application.qrc

# Build the Go binary for the specified architecture
if [[ "$ARCH" == "armv7h" ]]; then
    # armv7h uses GOARCH=arm with GOARM=7
    GOOS=linux GOARCH=arm GOARM=7 go build -o remarkdown .
else
    # arm64 maps directly
    GOOS=linux GOARCH=$ARCH go build -o remarkdown .
fi

if [ ! -f remarkdown ]; then
    echo "Error: Build failed - remarkdown binary not created"
    exit 1
fi

cp remarkdown rmd/backend/entry

echo "Build completed successfully for $ARCH"
