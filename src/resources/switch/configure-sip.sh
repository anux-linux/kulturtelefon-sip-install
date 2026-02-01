#!/bin/sh

# Get script directory from parameter or determine it locally
SCRIPT_DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"

# Includes
. "$SCRIPT_DIR/resources/config.sh"
. "$SCRIPT_DIR/resources/colors.sh"

FS_PROFILE_DIR="/etc/freeswitch/sip_profiles"
CONFIG_DIR="$SCRIPT_DIR/resources/switch/sip_profiles"

verbose "Configuring FreeSWITCH SIP profiles for localhost-only access"

# Check if FreeSWITCH profile directory exists
if [ ! -d "$FS_PROFILE_DIR" ]; then
    error "FreeSWITCH SIP profile directory not found: $FS_PROFILE_DIR"
    exit 1
fi

# Disable IPv6 profiles (rename to .disabled)
verbose "Disabling IPv6 SIP profiles"
if [ -f "$FS_PROFILE_DIR/internal-ipv6.xml" ]; then
    mv "$FS_PROFILE_DIR/internal-ipv6.xml" "$FS_PROFILE_DIR/internal-ipv6.xml.disabled"
    verbose "Disabled internal-ipv6 profile"
fi

if [ -f "$FS_PROFILE_DIR/external-ipv6.xml" ]; then
    mv "$FS_PROFILE_DIR/external-ipv6.xml" "$FS_PROFILE_DIR/external-ipv6.xml.disabled"
    verbose "Disabled external-ipv6 profile"
fi

# Backup original profiles
verbose "Backing up original SIP profiles"
if [ -f "$FS_PROFILE_DIR/internal.xml" ] && [ ! -f "$FS_PROFILE_DIR/internal.xml.orig" ]; then
    cp "$FS_PROFILE_DIR/internal.xml" "$FS_PROFILE_DIR/internal.xml.orig"
fi

if [ -f "$FS_PROFILE_DIR/external.xml" ] && [ ! -f "$FS_PROFILE_DIR/external.xml.orig" ]; then
    cp "$FS_PROFILE_DIR/external.xml" "$FS_PROFILE_DIR/external.xml.orig"
fi

# Install custom SIP profiles
verbose "Installing custom SIP profiles (localhost-only)"
cp "$CONFIG_DIR/internal.xml" "$FS_PROFILE_DIR/internal.xml"
cp "$CONFIG_DIR/external.xml" "$FS_PROFILE_DIR/external.xml"

# Set proper permissions
chown freeswitch:freeswitch "$FS_PROFILE_DIR/internal.xml"
chown freeswitch:freeswitch "$FS_PROFILE_DIR/external.xml"
chmod 644 "$FS_PROFILE_DIR/internal.xml"
chmod 644 "$FS_PROFILE_DIR/external.xml"

# Enable and restart FreeSWITCH
verbose "Enabling FreeSWITCH service"
systemctl enable freeswitch

verbose "Restarting FreeSWITCH"
systemctl restart freeswitch

# Wait for FreeSWITCH to start
sleep 3

# Check if FreeSWITCH is running
if systemctl is-active --quiet freeswitch; then
    verbose "FreeSWITCH configured successfully"
    verbose "Internal profile: 127.0.0.1:5066"
    verbose "External profile: 127.0.0.1:5086"
else
    error "FreeSWITCH failed to start. Check logs: journalctl -u freeswitch"
    exit 1
fi
