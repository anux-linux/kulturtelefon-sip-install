#!/bin/sh

# Get script directory from parameter or determine it locally
SCRIPT_DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"

# Includes
. "$SCRIPT_DIR/resources/config.sh"
. "$SCRIPT_DIR/resources/colors.sh"

FS_PROFILE_DIR="/etc/freeswitch/sip_profiles"
FS_AUTOLOAD_DIR="/etc/freeswitch/autoload_configs"
CONFIG_DIR="$SCRIPT_DIR/resources/switch/sip_profiles"
EVENTSOCKET_CONFIG_DIR="$SCRIPT_DIR/resources/switch/config"

# Auto-detect public IP if not already set
if [ -z "$freeswitch_public_ip" ]; then
    verbose "Auto-detecting public IP address"
    freeswitch_public_ip=$(curl -s --max-time 5 ifconfig.me || curl -s --max-time 5 icanhazip.com || curl -s --max-time 5 ipinfo.io/ip)
fi

if [ -z "$freeswitch_public_ip" ]; then
    error "Failed to detect public IP address"
    exit 1
fi

verbose "Public IP: $freeswitch_public_ip"
verbose "Configuring FreeSWITCH SIP profiles for public internet access"

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
verbose "Installing custom SIP profiles"
cp "$CONFIG_DIR/internal.xml" "$FS_PROFILE_DIR/internal.xml"
cp "$CONFIG_DIR/external.xml" "$FS_PROFILE_DIR/external.xml"

# Replace placeholder with actual public IP
sed -i "s/FREESWITCH_PUBLIC_IP_PLACEHOLDER/${freeswitch_public_ip}/g" "$FS_PROFILE_DIR/internal.xml"
sed -i "s/FREESWITCH_PUBLIC_IP_PLACEHOLDER/${freeswitch_public_ip}/g" "$FS_PROFILE_DIR/external.xml"

# Set proper permissions
chown freeswitch:freeswitch "$FS_PROFILE_DIR/internal.xml"
chown freeswitch:freeswitch "$FS_PROFILE_DIR/external.xml"
chmod 644 "$FS_PROFILE_DIR/internal.xml"
chmod 644 "$FS_PROFILE_DIR/external.xml"

# Configure Event Socket
verbose "Configuring Event Socket with auto-generated password"

# Generate random 12-character password
event_socket_password=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 12)

# Backup original event_socket.conf.xml if it exists
if [ -f "$FS_AUTOLOAD_DIR/event_socket.conf.xml" ] && [ ! -f "$FS_AUTOLOAD_DIR/event_socket.conf.xml.orig" ]; then
    cp "$FS_AUTOLOAD_DIR/event_socket.conf.xml" "$FS_AUTOLOAD_DIR/event_socket.conf.xml.orig"
fi

# Install event socket configuration
cp "$EVENTSOCKET_CONFIG_DIR/event_socket.conf.xml" "$FS_AUTOLOAD_DIR/event_socket.conf.xml"

# Replace placeholder with generated password
sed -i "s/EVENT_SOCKET_PASSWORD_PLACEHOLDER/${event_socket_password}/g" "$FS_AUTOLOAD_DIR/event_socket.conf.xml"

# Set proper permissions
chown freeswitch:freeswitch "$FS_AUTOLOAD_DIR/event_socket.conf.xml"
chmod 644 "$FS_AUTOLOAD_DIR/event_socket.conf.xml"

# Store the password in a secure file for later reference
echo "$event_socket_password" > "$SCRIPT_DIR/.event_socket_password"
chmod 600 "$SCRIPT_DIR/.event_socket_password"

verbose "Event Socket password saved to: $SCRIPT_DIR/.event_socket_password"

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
    verbose "External profile SIP: $freeswitch_public_ip:5060"
    verbose "Internal profile SIP: $freeswitch_public_ip:5066"
    verbose "RTP media IP: $freeswitch_public_ip"
    verbose "Event Socket: localhost:8021"
    verbose "Event Socket password: $event_socket_password"
else
    error "FreeSWITCH failed to start. Check logs: journalctl -u freeswitch"
    exit 1
fi
