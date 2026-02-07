# FreeSWITCH SignalWire token (must be set via environment variable)
if [ -z "$SWITCH_TOKEN" ]; then
    echo "Error: SWITCH_TOKEN environment variable is not set"
    exit 1
fi
switch_token="$SWITCH_TOKEN"