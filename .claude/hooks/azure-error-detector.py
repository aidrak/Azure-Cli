#!/usr/bin/env python3
"""
Azure Error Detector - PostToolUse Hook
========================================
Detects Azure operation failures and provides fix context to Claude
for automatic self-healing.

Triggers on:
- Bash commands containing "engine.sh" or "az "
- Non-zero exit codes

Returns JSON that tells Claude to:
1. Read error-patterns.yaml
2. Find matching pattern
3. Apply fix (edit YAML or retry)
"""
import json
import sys
import os

def main():
    # Read hook input from stdin
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    # Only process Bash tool
    tool = data.get("tool_name")
    if tool != "Bash":
        sys.exit(0)

    # Get response details
    resp = data.get("tool_response", {})
    exit_code = resp.get("exitCode", 0)

    # Only trigger on failures
    if exit_code == 0:
        sys.exit(0)

    # Get command and output
    inp = data.get("tool_input", {})
    command = inp.get("command", "")
    stderr = resp.get("stderr", "")
    stdout = resp.get("stdout", "")

    # Only trigger for Azure-related commands
    azure_commands = ["engine.sh", "az ", "az.cmd", "workflow-engine.sh"]
    if not any(cmd in command for cmd in azure_commands):
        sys.exit(0)

    # Extract error context
    error_output = stderr if stderr else stdout
    error_info = {
        "command": command[:300],
        "exit_code": exit_code,
        "error_output": error_output[:1000]
    }

    # Build response for Claude
    output = {
        "decision": "block",
        "reason": (
            "Azure operation failed. Apply self-healing protocol:\n"
            "1. Read error-patterns.yaml to find matching pattern\n"
            "2. If auto_fix: true, apply the fix_action and retry\n"
            "3. If auto_fix: false, inform user what manual action is needed"
        ),
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": json.dumps(error_info, indent=2)
        }
    }

    print(json.dumps(output))
    sys.exit(0)

if __name__ == "__main__":
    main()
