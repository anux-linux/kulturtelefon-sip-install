#!/bin/sh

#move to script directory so all relative paths work
cd "$(dirname "$0")"

#includes
. ./config.sh
. ./colors.sh

#add sngrep
verboseq "Installing sngrep"
apt-get install -y sngrep
