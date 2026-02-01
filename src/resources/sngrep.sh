#!/bin/sh

# Get script directory from parameter or determine it locally
SCRIPT_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"

#includes
. "$SCRIPT_DIR/resources/config.sh"
. "$SCRIPT_DIR/resources/colors.sh"

#add sngrep
verboseq "Installing sngrep"
apt-get install -y sngrep
