#!/bin/sh

# Get script directory from parameter or determine it locally
SCRIPT_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"

#includes
. "$SCRIPT_DIR/resources/config.sh"
. "$SCRIPT_DIR/resources/colors.sh"

sh "$SCRIPT_DIR/resources/switch/package-all.sh" "$SCRIPT_DIR"
