#!/bin/bash

# Default options
DO_BUILD=true # New default: build by default
NO_CACHE=false

# Function to display usage
usage() {
    echo "Usage: $0 [-N|--no-build] [-n|--no-cache]"
    echo "  -N, --no-build     Do not build images before starting (skip rebuild)."
    echo "  -n, --no-cache     Build images without using cache (only applies if building)."
    exit 1
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -N|--no-build)
            DO_BUILD=false
            ;;
        -n|--no-cache)
            NO_CACHE=true
            ;;
        *)
            echo "Unknown parameter: $1"
            usage
            ;;
    esac
    shift
done

echo "Starting Docker Compose services..."

BUILD_OPTIONS=""
if [ "$DO_BUILD" = true ]; then
    BUILD_OPTIONS="--build"
    if [ "$NO_CACHE" = true ]; then
        BUILD_OPTIONS+=" --no-cache"
        echo "Building services with --no-cache..."
    else
        echo "Building services..."
    fi
fi

# Start services
docker-compose up -d $BUILD_OPTIONS

echo "Services started."