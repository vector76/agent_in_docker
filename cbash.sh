#!/bin/bash
set -euo pipefail

# Load container config from .env.container
if [ ! -f .env.container ]; then
    echo ".env.container file not found. Copy .env.container.example to .env.container and customize."
    exit 1
fi

IMAGE_NAME=""
CONTAINER_NAME=""
while IFS='=' read -r key value; do
    case "$key" in
        IMAGE_NAME) IMAGE_NAME="$value" ;;
        CONTAINER_NAME) CONTAINER_NAME="$value" ;;
    esac
done < .env.container

if [ -z "$IMAGE_NAME" ]; then
    echo "IMAGE_NAME not set in .env.container."
    exit 1
fi
if [ -z "$CONTAINER_NAME" ]; then
    echo "CONTAINER_NAME not set in .env.container."
    exit 1
fi

# Check if container exists
if ! docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    echo "Container $CONTAINER_NAME does not exist. Run rebuild.sh first."
    exit 1
fi

# Check if running
RUNNING=$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || echo "false")
if [ "$RUNNING" != "true" ]; then
    echo "Starting container $CONTAINER_NAME..."
    docker start "$CONTAINER_NAME"
fi

# Exec into interactive bash as devuser
echo "Opening shell in $CONTAINER_NAME..."
docker exec -it -u devuser "$CONTAINER_NAME" bash

# After shell exit, count remaining bash processes (default to 0 if fails)
COUNT=$(docker top "$CONTAINER_NAME" 2>/dev/null | grep -c "bash") || COUNT=0

# If no more bash processes, stop the container
if [ "$COUNT" -eq 0 ]; then
    echo "No more active shells. Stopping container $CONTAINER_NAME..."
    docker stop "$CONTAINER_NAME"
else
    echo "$COUNT active shell(s) remaining. Container stays running."
fi
