#!/bin/bash

# String manipulation utilities for deployment scripts
#
# Purpose: Consistent string handling and formatting
# Usage: source ../common/functions/string-functions.sh
#
# Functions:
#   sanitize_name()     - Clean resource names
#   parse_azure_id()    - Extract parts from Azure resource IDs
#   validate_json()     - Validate JSON strings
#   mask_secrets()      - Hide sensitive values in logs
#   colorize()          - Add color to terminal output
#   trim()              - Trim whitespace
#   to_upper()          - Convert to uppercase
#   to_lower()          - Convert to lowercase
#   escape_json()       - Escape JSON special characters

# ============================================================================
# Name Sanitization
# ============================================================================

# Sanitize resource names (remove invalid characters, convert to lowercase)
# Usage: name=$(sanitize_name "My-Resource Name!" "lowercase")
sanitize_name() {
    local name="$1"
    local case_mode="${2:-lowercase}"

    # Remove invalid characters (keep alphanumerics, hyphens, underscores)
    name=$(echo "$name" | sed 's/[^a-zA-Z0-9_-]//g')

    # Apply case conversion
    case "$case_mode" in
        lowercase)
            name=$(echo "$name" | tr '[:upper:]' '[:lower:]')
            ;;
        uppercase)
            name=$(echo "$name" | tr '[:lower:]' '[:upper:]')
            ;;
        *)
            name=$(echo "$name" | tr '[:upper:]' '[:lower:]')
            ;;
    esac

    echo "$name"
}

# Generate unique resource name (append timestamp)
# Usage: name=$(generate_unique_name "myresource")
generate_unique_name() {
    local base_name="$1"
    local timestamp
    timestamp=$(date +%s | tail -c 6)

    echo "${base_name}${timestamp}"
}

# Ensure resource name length is valid for Azure
# Usage: name=$(ensure_name_length "very-long-name-here" 24)
ensure_name_length() {
    local name="$1"
    local max_length="${2:-24}"

    if [[ ${#name} -gt $max_length ]]; then
        name="${name:0:$max_length}"
    fi

    echo "$name"
}

# ============================================================================
# Azure Resource ID Parsing
# ============================================================================

# Parse Azure resource ID and extract parts
# Usage: parse_azure_id "subscription" "/subscriptions/xxx/resourceGroups/yyy/providers/Microsoft.Compute/virtualMachines/zzz"
parse_azure_id() {
    local part="$1"
    local resource_id="$2"

    case "$part" in
        subscription)
            echo "$resource_id" | sed 's|.*/subscriptions/\([^/]*\).*|\1|'
            ;;
        resource-group)
            echo "$resource_id" | sed 's|.*/resourceGroups/\([^/]*\).*|\1|'
            ;;
        provider)
            echo "$resource_id" | sed 's|.*/providers/\([^/]*\).*|\1|'
            ;;
        resource-type)
            echo "$resource_id" | sed 's|.*/providers/[^/]*/\([^/]*\).*|\1|'
            ;;
        resource-name)
            echo "$resource_id" | sed 's|.*/\([^/]*\)$|\1|'
            ;;
        *)
            log_error "Unknown part: $part"
            return 1
            ;;
    esac
}

# Extract subscription ID from resource ID
# Usage: sub_id=$(get_subscription_from_id "$resource_id")
get_subscription_from_id() {
    local resource_id="$1"
    parse_azure_id "subscription" "$resource_id"
}

# Extract resource group from resource ID
# Usage: rg=$(get_rg_from_id "$resource_id")
get_rg_from_id() {
    local resource_id="$1"
    parse_azure_id "resource-group" "$resource_id"
}

# ============================================================================
# JSON Handling
# ============================================================================

# Validate JSON string format
# Usage: if validate_json '{"key": "value"}'; then echo "Valid"; fi
validate_json() {
    local json_string="$1"

    if echo "$json_string" | jq empty 2>/dev/null; then
        return 0
    else
        log_error "Invalid JSON: $json_string"
        return 1
    fi
}

# Extract value from JSON
# Usage: value=$(json_extract '{"key": "value"}' ".key")
json_extract() {
    local json_string="$1"
    local path="$2"

    echo "$json_string" | jq -r "$path" 2>/dev/null
}

# Escape special JSON characters
# Usage: escaped=$(escape_json "text with \"quotes\" and \\ backslashes")
escape_json() {
    local text="$1"

    # Escape backslashes first, then quotes
    text="${text//\\/\\\\}"
    text="${text//\"/\\\"}"

    echo "$text"
}

# ============================================================================
# Security & Masking
# ============================================================================

# Mask sensitive values in logs (passwords, keys, tokens)
# Usage: masked=$(mask_secrets "password123secret")
mask_secrets() {
    local text="$1"
    local mask_length="${2:-4}"

    # Find patterns that look like secrets (long strings of random chars)
    # This is a simple heuristic implementation

    # Mask any 20+ character strings that aren't IDs
    text=$(echo "$text" | sed -E 's/([a-zA-Z0-9!@#$%^&*_+=-]{20,})/[MASKED]/g')

    echo "$text"
}

# Check if text contains sensitive keywords
# Usage: if contains_secrets "text with password=secret"; then echo "Found secret"; fi
contains_secrets() {
    local text="$1"
    local keywords=("password" "secret" "token" "key" "apikey" "api_key" "auth" "credential")

    for keyword in "${keywords[@]}"; do
        if echo "$text" | grep -qi "$keyword"; then
            return 0
        fi
    done

    return 1
}

# Safe log function that masks secrets
# Usage: safe_log "operation completed with password=$secret"
safe_log() {
    local message="$1"

    if contains_secrets "$message"; then
        message=$(mask_secrets "$message")
        log_warning "Log message contained sensitive data - masked output"
    fi

    log_info "$message"
}

# ============================================================================
# Text Formatting
# ============================================================================

# Trim leading and trailing whitespace
# Usage: trimmed=$(trim "  text with spaces  ")
trim() {
    local text="$1"
    text="${text#"${text%%[![:space:]]*}"}"  # Remove leading whitespace
    text="${text%"${text##*[![:space:]]}"}"  # Remove trailing whitespace
    echo "$text"
}

# Convert to uppercase
# Usage: upper=$(to_upper "text")
to_upper() {
    echo "${1}" | tr '[:lower:]' '[:upper:]'
}

# Convert to lowercase
# Usage: lower=$(to_lower "TEXT")
to_lower() {
    echo "${1}" | tr '[:upper:]' '[:lower:]'
}

# Convert kebab-case to snake_case
# Usage: result=$(kebab_to_snake "my-resource-name")
kebab_to_snake() {
    echo "${1}" | tr '-' '_'
}

# Convert snake_case to kebab-case
# Usage: result=$(snake_to_kebab "my_resource_name")
snake_to_kebab() {
    echo "${1}" | tr '_' '-'
}

# ============================================================================
# String Testing
# ============================================================================

# Check if string is empty or whitespace
# Usage: if is_empty "$var"; then echo "Empty"; fi
is_empty() {
    local text="$1"
    text=$(trim "$text")
    [[ -z "$text" ]]
}

# Check if string matches pattern (regex)
# Usage: if matches "email@example.com" ".*@.*\.com"; then ... fi
matches() {
    local text="$1"
    local pattern="$2"

    [[ "$text" =~ $pattern ]]
}

# Check if string contains substring
# Usage: if contains "hello world" "world"; then ... fi
contains() {
    local text="$1"
    local substring="$2"

    [[ "$text" == *"$substring"* ]]
}

# Check if string starts with prefix
# Usage: if starts_with "resource-group" "resource"; then ... fi
starts_with() {
    local text="$1"
    local prefix="$2"

    [[ "$text" == "$prefix"* ]]
}

# Check if string ends with suffix
# Usage: if ends_with "resource-group" "group"; then ... fi
ends_with() {
    local text="$1"
    local suffix="$2"

    [[ "$text" == *"$suffix" ]]
}

# ============================================================================
# String Replacement
# ============================================================================

# Replace first occurrence
# Usage: result=$(replace_first "hello hello world" "hello" "goodbye")
replace_first() {
    local text="$1"
    local search="$2"
    local replacement="$3"

    echo "${text/$search/$replacement}"
}

# Replace all occurrences
# Usage: result=$(replace_all "hello hello world" "hello" "goodbye")
replace_all() {
    local text="$1"
    local search="$2"
    local replacement="$3"

    echo "${text//$search/$replacement}"
}

# ============================================================================
# Terminal Coloring
# ============================================================================

# Color codes
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"
RESET="\033[0m"

# Colorize text
# Usage: colorized=$(colorize "text" "green")
colorize() {
    local text="$1"
    local color="${2:-default}"

    case "$color" in
        red)
            echo -e "${RED}${text}${RESET}"
            ;;
        green)
            echo -e "${GREEN}${text}${RESET}"
            ;;
        yellow)
            echo -e "${YELLOW}${text}${RESET}"
            ;;
        blue)
            echo -e "${BLUE}${text}${RESET}"
            ;;
        magenta)
            echo -e "${MAGENTA}${text}${RESET}"
            ;;
        cyan)
            echo -e "${CYAN}${text}${RESET}"
            ;;
        white)
            echo -e "${WHITE}${text}${RESET}"
            ;;
        *)
            echo "$text"
            ;;
    esac
}

# Create a formatted header
# Usage: print_header "Section Title"
print_header() {
    local text="$1"
    local width="${2:-80}"

    printf "%-${width}s\n" " " | tr ' ' '='
    echo -e "${CYAN}${text}${RESET}"
    printf "%-${width}s\n" " " | tr ' ' '='
    echo ""
}

# Create a formatted line
# Usage: print_line "Key" "Value" 30
print_line() {
    local key="$1"
    local value="$2"
    local width="${3:-40}"

    printf "%-${width}s : %s\n" "$key" "$value"
}

# ============================================================================
# Initialization
# ============================================================================

# Require logging functions
if ! declare -f log_info &>/dev/null; then
    log_info() { echo "INFO: $*"; }
    log_error() { echo "ERROR: $*" >&2; }
fi

# Export all functions
export -f sanitize_name
export -f generate_unique_name
export -f ensure_name_length
export -f parse_azure_id
export -f get_subscription_from_id
export -f get_rg_from_id
export -f validate_json
export -f json_extract
export -f escape_json
export -f mask_secrets
export -f contains_secrets
export -f safe_log
export -f trim
export -f to_upper
export -f to_lower
export -f kebab_to_snake
export -f snake_to_kebab
export -f is_empty
export -f matches
export -f contains
export -f starts_with
export -f ends_with
export -f replace_first
export -f replace_all
export -f colorize
export -f print_header
export -f print_line
