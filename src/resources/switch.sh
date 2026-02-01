#!/bin/sh

# Get script directory from parameter or determine it locally
SCRIPT_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"

#includes
. "$SCRIPT_DIR/resources/config.sh"
. "$SCRIPT_DIR/resources/colors.sh"

# Install FreeSWITCH packages
verbose "Installing FreeSWITCH packages"
sh "$SCRIPT_DIR/resources/switch/package-all.sh" "$SCRIPT_DIR"

# Check if FreeSWITCH was installed successfully
if [ -f /usr/bin/freeswitch ] || [ -f /usr/local/bin/freeswitch ]; then
    verbose "FreeSWITCH installed successfully"

    # Configure SIP profiles for localhost-only access
    sh "$SCRIPT_DIR/resources/switch/configure-sip.sh" "$SCRIPT_DIR"
else
    error "FreeSWITCH installation failed"
    exit 1
fi
