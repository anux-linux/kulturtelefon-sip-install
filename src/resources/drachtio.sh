#!/bin/sh

#move to script directory so all relative paths work
cd "$(dirname "$0")"

# Save script directory for later use
SCRIPT_DIR="$(pwd)"

#add the includes
. ./config.sh
. ./colors.sh

# Generate random secret for drachtio admin connection if not already set
if [ -z "$drachtio_secret" ]; then
    drachtio_secret=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
fi

verbose "Installing drachtio dependencies"
apt-get install -y libcurl4-openssl-dev libboost-all-dev

verbose "Installing Node.js and PM2"
apt-get install -y nodejs npm
npm install -g pm2

verbose "Building drachtio-server from source"
cd /usr/local/src
git clone --depth 1 https://github.com/davehorton/drachtio-server.git
cd drachtio-server
./bootstrap.sh
mkdir -p build && cd build
../configure --enable-ssl=yes
make
make install

verbose "Creating drachtio configuration directories"
mkdir -p /etc/drachtio
mkdir -p /var/log/drachtio

verbose "Installing drachtio configuration file"
cp "${SCRIPT_DIR}/drachtio/drachtio.conf.xml" /etc/drachtio/drachtio.conf.xml

# Replace placeholder with actual secret
sed -i "s/DRACHTIO_SECRET_PLACEHOLDER/${drachtio_secret}/" /etc/drachtio/drachtio.conf.xml

verbose "Installing drachtio systemd service"
cp "${SCRIPT_DIR}/drachtio/drachtio.service" /etc/systemd/system/drachtio.service

verbose "Enabling and starting drachtio service"
systemctl daemon-reload
systemctl enable drachtio
systemctl start drachtio

verbose "Drachtio installation complete"
verbose "Admin port: 9022"
verbose "Admin secret stored in /etc/drachtio/drachtio.conf.xml"

