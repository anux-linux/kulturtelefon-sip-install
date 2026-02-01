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

verbose "Installing drachtio dependencies"
apt-get install -y libcurl4-openssl-dev libboost-all-dev libssl-dev autoconf automake libtool

verbose "Installing Node.js and PM2"
apt-get install -y nodejs npm
npm install -g pm2

# Only build if drachtio-server binary doesn't exist
if [ ! -f /usr/local/bin/drachtio-server ]; then
    verbose "Building drachtio-server from source"
    cd /usr/local/src

    # Clone only if directory doesn't exist
    if [ ! -d drachtio-server ]; then
        git clone --recurse-submodules https://github.com/davehorton/drachtio-server.git
    fi

    cd drachtio-server
    git submodule update --init --recursive
    ./bootstrap.sh
    mkdir -p build && cd build
    ../configure
    make
    make install
else
    verbose "drachtio-server already installed, skipping build"
fi

verbose "Creating drachtio configuration directories"
mkdir -p /etc/drachtio
mkdir -p /var/log/drachtio

# Only create config if it doesn't exist (preserve existing secrets)
if [ ! -f /etc/drachtio/drachtio.conf.xml ]; then
    verbose "Installing drachtio configuration file"
    cp "${SCRIPT_DIR}/resources/drachtio/drachtio.conf.xml" /etc/drachtio/drachtio.conf.xml

    # Replace placeholder with actual secret
    sed -i "s/DRACHTIO_SECRET_PLACEHOLDER/${drachtio_secret}/" /etc/drachtio/drachtio.conf.xml
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

