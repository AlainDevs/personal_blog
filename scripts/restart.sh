#!/bin/bash

# Default options
NO_BUILD=false
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
            NO_BUILD=true
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

echo "Restarting Docker Compose services..."

# Stop all services
./scripts/stop.sh

# Start services with specified options
START_OPTIONS=""
if [ "$NO_BUILD" = true ]; then
    START_OPTIONS+=" -N"
fi
if [ "$NO_CACHE" = true ]; then
    START_OPTIONS+=" -n"
fi

./scripts/start.sh $START_OPTIONS

echo "Services restarted."