#!/bin/sh

# Get script directory from parameter or determine it locally
SCRIPT_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"

#add the includes
. "$SCRIPT_DIR/resources/config.sh"
. "$SCRIPT_DIR/resources/colors.sh"

# Generate random secret for drachtio admin connection if not already set
if [ -z "$drachtio_secret" ]; then
    drachtio_secret=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
fi

# Auto-detect network configuration if not already set
if [ -z "$drachtio_external_ip" ]; then
    verbose "Auto-detecting external IP address"
    drachtio_external_ip=$(curl -s --max-time 5 ifconfig.me || curl -s --max-time 5 icanhazip.com || curl -s --max-time 5 ipinfo.io/ip)
fi

if [ -z "$drachtio_dns_name" ]; then
    verbose "Auto-detecting DNS name"
    # Try reverse DNS lookup, fall back to hostname
    drachtio_dns_name=$(dig +short -x "$drachtio_external_ip" 2>/dev/null | sed 's/\.$//' || hostname -f)
    # If still empty, use the external IP as fallback
    if [ -z "$drachtio_dns_name" ]; then
        drachtio_dns_name="$drachtio_external_ip"
    fi
fi

verbose "External IP: $drachtio_external_ip"
verbose "DNS name: $drachtio_dns_name"

verbose "Installing drachtio dependencies"
apt-get install -y libcurl4-openssl-dev libboost-all-dev libssl-dev autoconf automake libtool libtool-bin cmake curl dnsutils

verbose "Installing Node.js and PM2"
apt-get install -y nodejs npm
npm install -g pm2

verbose "Setting up drachtio-server source"
cd /usr/local/src

NEEDS_BUILD=false

# Clone if directory doesn't exist
if [ ! -d drachtio-server ]; then
    verbose "Cloning drachtio-server repository"
    git clone --recurse-submodules https://github.com/davehorton/drachtio-server.git
    NEEDS_BUILD=true
fi

cd drachtio-server

# Check current commit before pull
OLD_HEAD=$(git rev-parse HEAD 2>/dev/null || echo "none")

# Pull latest changes
verbose "Pulling latest drachtio-server updates"
git fetch --all
git pull origin main || git pull origin master
git submodule update --init --recursive

# Check if there are new changes
NEW_HEAD=$(git rev-parse HEAD)
if [ "$OLD_HEAD" != "$NEW_HEAD" ]; then
    verbose "New updates found, rebuild required"
    NEEDS_BUILD=true
fi

# Build if binary doesn't exist or if there are updates
if [ ! -f /usr/local/bin/drachtio-server ] || [ "$NEEDS_BUILD" = true ]; then
    verbose "Building drachtio-server from source"
    ./bootstrap.sh
    mkdir -p build && cd build
    ../configure
    make
    make install
else
    verbose "drachtio-server is up to date, skipping build"
fi

verbose "Creating drachtio configuration directories"
mkdir -p /etc/drachtio
mkdir -p /var/log/drachtio
mkdir -p /var/log/drachtio/archive

# Only create config if it doesn't exist (preserve existing secrets)
if [ ! -f /etc/drachtio/drachtio.conf.xml ]; then
    verbose "Installing drachtio configuration file"
    cp "${SCRIPT_DIR}/resources/drachtio/drachtio.conf.xml" /etc/drachtio/drachtio.conf.xml

    # Replace placeholders with actual values
    sed -i "s/DRACHTIO_SECRET_PLACEHOLDER/${drachtio_secret}/" /etc/drachtio/drachtio.conf.xml
    sed -i "s/DRACHTIO_EXTERNAL_IP_PLACEHOLDER/${drachtio_external_ip}/" /etc/drachtio/drachtio.conf.xml
    sed -i "s/DRACHTIO_DNS_PLACEHOLDER/${drachtio_dns_name}/" /etc/drachtio/drachtio.conf.xml
else
    verbose "drachtio config already exists, skipping (preserving existing secret)"
fi

verbose "Installing drachtio systemd service"
cp "${SCRIPT_DIR}/resources/drachtio/drachtio.service" /etc/systemd/system/drachtio.service

verbose "Enabling and restarting drachtio service"
systemctl daemon-reload
systemctl enable drachtio
systemctl restart drachtio

verbose "Drachtio installation complete"
verbose "Admin port: 9022"
verbose "Admin secret stored in /etc/drachtio/drachtio.conf.xml"

