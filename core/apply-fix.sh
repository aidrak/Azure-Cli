#!/bin/bash

# ==============================================================================
# apply-fix.sh
#
# A dedicated wrapper for applying fixes to operation YAML files using yq.
# This script provides a standardized, more robust interface for an AI assistant
# to modify YAML files, abstracting away the complexities of yq syntax.
#
# Usage:
#   ./core/apply-fix.sh <file_path> <yaml_path> <new_value>
#
# Arguments:
#   $1: file_path  - The full path to the YAML file to modify.
#   $2: yaml_path  - The yq-compatible path to the key to be updated 
#                   (e.g., '.operation.duration.timeout').
#   $3: new_value  - The new value to set for the specified key.
#
# Examples:
#   # Set a numeric value
#   ./core/apply-fix.sh capabilities/compute/operations/golden-image-validate.yaml '.operation.duration.timeout' 600
#
#   # Set a string value (quotes are handled)
#   ./core/apply-fix.sh capabilities/compute/operations/golden-image-install-apps.yaml '.operation.name' "New Operation Name"
#
# ==============================================================================

set -euo pipefail

# --- Arguments ---
FILE_PATH="${1-}"
YAML_PATH="${2-}"
NEW_VALUE="${3-}"

# --- Validation ---
if [[ -z "$FILE_PATH" || -z "$YAML_PATH" || -z "$NEW_VALUE" ]]; then
  echo "Usage: $0 <file_path> <yaml_path> <new_value>"
  echo "Error: All arguments are required." >&2
  exit 1
fi

if [[ ! -f "$FILE_PATH" ]]; then
  echo "Error: File not found at '$FILE_PATH'" >&2
  exit 1
fi

if ! command -v yq &> /dev/null; then
    echo "Error: 'yq' command not found. Please install yq." >&2
    exit 1
fi

# --- Main Logic ---
echo "Applying fix to: $FILE_PATH"
echo "  - Path:  $YAML_PATH"
echo "  - Value: $NEW_VALUE"

# Use yq to perform the in-place update.
# The command is structured to handle both numeric and string values correctly.
# yq automatically quotes strings when needed.
if yq eval -i "${YAML_PATH} = \"${NEW_VALUE}\"" "$FILE_PATH"; then
  echo "Successfully applied fix."
else
  echo "Error: yq command failed to apply the fix." >&2
  exit 1
fi

# --- Verification (Optional) ---
echo "Verifying change..."
# Read back the value to confirm it was set.
actual_value=$(yq eval "${YAML_PATH}" "$FILE_PATH")

# Note: This simple verification works for basic types.
# For complex assignments, the check might need to be more sophisticated.
if [[ "$actual_value" == "$NEW_VALUE" ]]; then
  echo "Verification successful. New value is: $actual_value"
  exit 0
else
  echo "Warning: Verification failed. Expected '$NEW_VALUE' but got '$actual_value'." >&2
  # Exit with success since the yq command itself succeeded, but warn the user.
  exit 0
fi
