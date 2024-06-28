#!/bin/bash

# Install socat if not already installed
if ! command -v socat &> /dev/null; then
    echo "socat is not installed. Installing..."
    brew install socat
fi

# Function to start the clipboard relay
start_clipboard_relay() {
    echo "Starting clipboard relay..."
    socat tcp-listen:8121,fork,bind=127.0.0.1,reuseaddr EXEC:'pbcopy',nofork &
    echo $! > /tmp/clipboard_relay.pid
}

# Check if the relay is already running
if [ -f /tmp/clipboard_relay.pid ]; then
    if ps -p $(cat /tmp/clipboard_relay.pid) > /dev/null; then
        echo "Clipboard relay is already running."
    else
        start_clipboard_relay
    fi
else
    start_clipboard_relay
fi

# Keep the script running
while true; do
    sleep 60
done