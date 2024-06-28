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

