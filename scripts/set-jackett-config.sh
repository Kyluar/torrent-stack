#!/usr/bin/env bash
#
# Configure the qBittorrent Jackett search plugin using the values from
# Jackett's own configuration file:
#   - API key: $CONFIG_PATH/Jackett/ServerConfig.json ("APIKey")
#   - URL:     http://jackett:<Port from ServerConfig.json>
#
# The config directory is taken from CONFIG_PATH (environment variable or
# .env), defaulting to ./config.
#
# Usage:
#   ./scripts/set-jackett-config.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

# Resolve the config directory the same way Docker Compose does: an explicit
# environment variable wins, then CONFIG_PATH from .env, then ./config.
config_path="${CONFIG_PATH:-}"
if [[ -z "$config_path" && -f "$ENV_FILE" ]]; then
    config_path="$(sed -n 's/^[[:space:]]*CONFIG_PATH[[:space:]]*=[[:space:]]*//p' "$ENV_FILE" | tail -n 1)"
    # Strip CRLF and optional surrounding quotes.
    config_path="${config_path%$'\r'}"
    config_path="${config_path%\"}"; config_path="${config_path#\"}"
    config_path="${config_path%\'}"; config_path="${config_path#\'}"
fi

config_path="${config_path:-./config}"

if [[ "$config_path" != /* ]]; then
    config_path="$PROJECT_ROOT/${config_path#./}"
fi

CONFIG_DIR="${config_path%/}"
CONFIG_FILE="$CONFIG_DIR/qBittorrent/nova3/engines/jackett.json"
SERVER_CONFIG_FILE="$CONFIG_DIR/Jackett/ServerConfig.json"

if [[ $# -gt 0 ]]; then
    echo "Error: this script does not accept arguments." >&2
    echo "Usage: $0" >&2
    exit 1
fi

if [[ ! -f "$SERVER_CONFIG_FILE" ]]; then
    echo "Error: could not find Jackett configuration at:" >&2
    echo "  $SERVER_CONFIG_FILE" >&2
    echo "Start Jackett once so it creates the file." >&2
    exit 1
fi

# Extract a string value from a flat JSON file.
json_string() {
    local file="$1" key="$2"
    sed -n "s/^[[:space:]]*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$file" | head -n 1
}

# Extract a numeric value from a flat JSON file.
json_number() {
    local file="$1" key="$2"
    sed -n "s/^[[:space:]]*\"${key}\"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p" "$file" | head -n 1
}

API_KEY="$(json_string "$SERVER_CONFIG_FILE" "APIKey")"
if [[ -z "$API_KEY" ]]; then
    echo "Error: could not read \"APIKey\" from $SERVER_CONFIG_FILE" >&2
    exit 1
fi

port="$(json_number "$SERVER_CONFIG_FILE" "Port")"
if [[ -z "$port" ]]; then
    echo "Error: could not read \"Port\" from $SERVER_CONFIG_FILE" >&2
    exit 1
fi

# qBittorrent reaches Jackett through the Docker Compose network using the
# service name as hostname.
base_path="$(json_string "$SERVER_CONFIG_FILE" "BasePathOverride")"
[[ "$base_path" == "/" ]] && base_path=""
base_path="${base_path%/}"

URL="http://jackett:${port}${base_path}"

# Escape characters that would break the JSON string.
json_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '%s' "$value"
}

escaped_key="$(json_escape "$API_KEY")"
escaped_url="$(json_escape "$URL")"

# Keep the existing plugin options when they are present.
thread_count=20
tracker_first=false

if [[ -f "$CONFIG_FILE" ]]; then
    existing_value="$(sed -n 's/^[[:space:]]*"thread_count"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$CONFIG_FILE" | head -n 1)"
    [[ -n "$existing_value" ]] && thread_count="$existing_value"

    existing_value="$(sed -n 's/^[[:space:]]*"tracker_first"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p' "$CONFIG_FILE" | head -n 1)"
    [[ -n "$existing_value" ]] && tracker_first="$existing_value"
fi

mkdir -p "$(dirname "$CONFIG_FILE")"

tmp_file="${CONFIG_FILE}.tmp"
cat > "$tmp_file" <<EOF
{
    "api_key": "$escaped_key",
    "thread_count": $thread_count,
    "tracker_first": $tracker_first,
    "url": "$escaped_url"
}
EOF
mv "$tmp_file" "$CONFIG_FILE"

masked_key="${API_KEY:0:4}...${API_KEY: -4}"
echo "Jackett configuration updated in ${CONFIG_FILE}"
echo "  api_key: ${masked_key}"
echo "  url:     ${URL}"
