#!/bin/sh

# Get script directory from parameter or determine it locally
SCRIPT_DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"

# Includes
. "$SCRIPT_DIR/resources/config.sh"
. "$SCRIPT_DIR/resources/colors.sh"

FS_PROFILE_DIR="/etc/freeswitch/sip_profiles"
FS_AUTOLOAD_DIR="/etc/freeswitch/autoload_configs"
FS_MODULES_CONF="$FS_AUTOLOAD_DIR/modules.conf.xml"
CONFIG_DIR="$SCRIPT_DIR/resources/switch/sip_profiles"
EVENTSOCKET_CONFIG_DIR="$SCRIPT_DIR/resources/switch/config"
HTTP_CACHE_DIR="/var/cache/freeswitch/http_cache"

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

# Configure mod_http_cache
verbose "Configuring mod_http_cache"

# Deploy http_cache config
if [ -f "$FS_AUTOLOAD_DIR/http_cache.conf.xml" ] && [ ! -f "$FS_AUTOLOAD_DIR/http_cache.conf.xml.orig" ]; then
    cp "$FS_AUTOLOAD_DIR/http_cache.conf.xml" "$FS_AUTOLOAD_DIR/http_cache.conf.xml.orig"
fi
cp "$EVENTSOCKET_CONFIG_DIR/http_cache.conf.xml" "$FS_AUTOLOAD_DIR/http_cache.conf.xml"
chown freeswitch:freeswitch "$FS_AUTOLOAD_DIR/http_cache.conf.xml"
chmod 644 "$FS_AUTOLOAD_DIR/http_cache.conf.xml"

# Create cache directory with correct ownership
mkdir -p "$HTTP_CACHE_DIR"
chown -R freeswitch:freeswitch "$HTTP_CACHE_DIR"
chmod 750 "$HTTP_CACHE_DIR"

# Enable mod_http_cache in modules.conf.xml if not already active
if [ -f "$FS_MODULES_CONF" ]; then
    if grep -q '<load module="mod_http_cache"/>' "$FS_MODULES_CONF"; then
        verbose "mod_http_cache already enabled in modules.conf.xml"
    elif grep -q 'mod_http_cache' "$FS_MODULES_CONF"; then
        # Uncomment the existing (commented-out) entry
        sed -i 's|<!--[[:space:]]*<load module="mod_http_cache"/>.*-->|  <load module="mod_http_cache"/>|' "$FS_MODULES_CONF"
        verbose "mod_http_cache uncommented in modules.conf.xml"
    else
        # Insert before closing </modules> tag
        sed -i 's|</modules>|  <load module="mod_http_cache"/>\n</modules>|' "$FS_MODULES_CONF"
        verbose "mod_http_cache added to modules.conf.xml"
    fi
else
    error "modules.conf.xml not found at $FS_MODULES_CONF"
    exit 1
fi

# Enable mod_hash in modules.conf.xml if not already active. It provides the
# `limit` application used by the dialplan to cap simultaneous callers on
# stream and podcast subscriptions (the `caller` add-on). Inert on its own:
# with no limit actions in any dialplan a loaded mod_hash does nothing, so this
# is safe to ship ahead of the dialplan change that needs it.
if [ -f "$FS_MODULES_CONF" ]; then
    # Anchored to the start of the line (whitespace aside) so a commented-out
    # `<!-- <load module="mod_hash"/> -->` does NOT count as already enabled.
    # Stock modules.conf.xml ships mod_hash commented out, so an unanchored
    # match here would report success and leave the module unloaded — and the
    # dialplan's `limit` action would then be an unknown application.
    if grep -qE '^[[:space:]]*<load module="mod_hash"/>' "$FS_MODULES_CONF"; then
        verbose "mod_hash already enabled in modules.conf.xml"
    elif grep -q 'mod_hash' "$FS_MODULES_CONF"; then
        # Uncomment the existing (commented-out) entry
        sed -i 's|<!--[[:space:]]*<load module="mod_hash"/>.*-->|  <load module="mod_hash"/>|' "$FS_MODULES_CONF"
        verbose "mod_hash uncommented in modules.conf.xml"
    else
        # Insert before closing </modules> tag
        sed -i 's|</modules>|  <load module="mod_hash"/>\n</modules>|' "$FS_MODULES_CONF"
        verbose "mod_hash added to modules.conf.xml"
    fi
else
    error "modules.conf.xml not found at $FS_MODULES_CONF"
    exit 1
fi

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
