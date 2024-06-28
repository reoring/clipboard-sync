# Clipboard Sharing between macOS and Linux Devcontainers

This project provides a solution for seamless clipboard sharing between macOS hosts and Linux-based development containers (devcontainers). It allows you to copy text from your devcontainer and paste it directly into applications on your macOS, enhancing your development workflow.

## Problem

When working with devcontainers, the clipboard is typically isolated from the host system. This means that text copied inside the container (using commands like `xclip` or `xsel`) is not available on the macOS clipboard. This isolation can significantly slow down workflows that require frequent transfer of code snippets or text between the devcontainer and macOS applications.

## Solution

Our solution involves three main components:

1. A clipboard relay script on macOS using `socat`.
2. A custom script in the devcontainer to intercept and forward clipboard commands.
3. SSH reverse port forwarding to securely connect the two environments.

## Prerequisites

- macOS host system
- Linux-based devcontainer
- SSH access to your devcontainer
- `socat` installed on macOS (can be installed via Homebrew)
- `netcat` installed in the devcontainer

## Setup

### 1. macOS Clipboard Relay

Save the following script as `macos_clipboard_relay.sh` on your macOS:

```bash
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
```

Make it executable:

```bash
chmod +x macos_clipboard_relay.sh
```

### 2. Devcontainer Clipboard Forwarding

Save the following script in your devcontainer:

```bash
#!/bin/bash

# Install netcat if not already installed
sudo apt-get update && sudo apt-get install -y netcat

# Create the updated clipboard forwarding script
cat << EOF > /usr/local/bin/clipboard_forward.sh
#!/bin/bash
echo "Debug: clipboard_forward.sh called with args: \$@" >> /tmp/clipboard_debug.log

# Function to forward to netcat
forward_to_netcat() {
    echo "Debug: Forwarding input to netcat" >> /tmp/clipboard_debug.log
    tee /tmp/clipboard_content.log | nc -w 1 localhost 8121
    echo "Debug: netcat exit code: \$?" >> /tmp/clipboard_debug.log
}

# Check if we're being asked to output clipboard content
if [[ "\$*" == *"-o"* ]] || [[ "\$*" == *"--output"* ]]; then
    echo "Debug: Output requested, but not implemented" >> /tmp/clipboard_debug.log
    exit 0
fi

# If -selection clipboard is present, read from stdin
if [[ "\$*" == *"-selection clipboard"* ]]; then
    forward_to_netcat
    exit 0
fi

# For other cases, check for input flags
for arg in "\$@"
do
  case "\$arg" in
    -i|--input|-in)
    forward_to_netcat
    exit 0
    ;;
  esac
done

# If no matching args found, still forward (this catches the case with no args)
forward_to_netcat

echo "Debug: End of script reached" >> /tmp/clipboard_debug.log
EOF

# Make the script executable
chmod +x /usr/local/bin/clipboard_forward.sh

# Create symlinks for xsel and xclip (if they don't exist)
ln -sf /usr/local/bin/clipboard_forward.sh /usr/local/bin/xsel
ln -sf /usr/local/bin/clipboard_forward.sh /usr/local/bin/xclip

# Add to PATH if necessary
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc

# Source .bashrc to update PATH in current session
source ~/.bashrc

echo "Clipboard forwarding set up using netcat with timeout"
```

Make it executable and run it in your devcontainer.

### 3. SSH Configuration

Add the following to your `~/.ssh/config` file on macOS:

```
Host devcontainer
    HostName your-devcontainer-host
    User your-username
    RemoteForward 8121 localhost:8121
```

Replace `your-devcontainer-host` and `your-username` with your actual devcontainer host and username.

## Usage

1. Start the macOS clipboard relay:
   ```
   ./macos_clipboard_relay.sh
   ```

2. Connect to your devcontainer using SSH:
   ```
   ssh devcontainer
   ```

3. In your devcontainer, use `xclip` or `xsel` as you normally would. The content will be forwarded to your macOS clipboard.

   Example:
   ```bash
   echo "Hello from devcontainer" | xclip -selection clipboard
   ```

4. The copied text should now be available in your macOS clipboard.

## Troubleshooting

- Check the debug logs in `/tmp/clipboard_debug.log` on the devcontainer.
- Ensure the macOS relay script is running.
- Verify that the SSH connection includes the reverse port forwarding.

## Contributing

Contributions to improve the scripts or documentation are welcome. Please feel free to submit a pull request or open an issue for any bugs or feature requests.

## License

[MIT License](LICENSE)
