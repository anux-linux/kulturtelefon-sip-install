# FreeSWITCH SignalWire token (must be set via environment variable)
if [ -z "$SWITCH_TOKEN" ]; then
    echo "Error: SWITCH_TOKEN environment variable is not set"
    exit 1
fi
switch_token="$SWITCH_TOKEN"

# Drachtio admin connection secret
drachtio_secret=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)