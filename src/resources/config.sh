switch_token= "changeme"

# Drachtio admin connection secret
drachtio_secret=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)