#!/usr/bin/env python3
"""
Document-Recovery Hook
Tracks errors and blocks ONLY when Claude successfully recovers (error → success pattern).
Forces documentation of the workaround via code comment.
"""
import json, sys, os
from pathlib import Path

STATE_FILE = ".claude/hooks/.error-state.json"
MONITORED = {"Bash": "exit_code", "Edit": "error", "Write": "error", "Grep": "error",
             "Glob": "error", "WebFetch": "error", "Read": "error", "Task": "error"}

data = json.load(sys.stdin)
tool = data.get("tool_name", "")
if tool not in MONITORED:
    sys.exit(0)

resp = data.get("tool_response", {})
inp = data.get("tool_input", {})

# Detect current tool state
is_error = False
if tool == "Bash" and resp.get("exit_code", 0) != 0:
    is_error = True
    error_info = {"tool": tool, "cmd": inp.get("command", "")[:100],
                  "stderr": resp.get("stderr", "")[:150], "exit_code": resp.get("exit_code")}
elif resp.get("error") or resp.get("success") is False:
    is_error = True
    error_info = {"tool": tool, "cmd": str(inp)[:100],
                  "error": str(resp.get("error", resp.get("message", "Unknown")))[:150]}

# Load previous state
root = Path(os.environ.get("CLAUDE_PROJECT_DIR", data.get("cwd", ".")))
state_path = root / STATE_FILE
state_path.parent.mkdir(parents=True, exist_ok=True)

prev_state = {}
if state_path.exists():
    try:
        prev_state = json.loads(state_path.read_text())
    except:
        pass

# State machine logic
if is_error:
    # Save error state for next call
    state_path.write_text(json.dumps(error_info))
    sys.exit(0)  # Don't block on initial error
else:
    # Success - check if previous call was an error (recovery detected!)
    if prev_state:
        # Recovery pattern detected: error → success
        msg = f"""⚠️  RECOVERY DETECTED - Documentation Required

Previous operation failed but you've now succeeded. Document the workaround!

Failed: {prev_state.get('tool', 'Unknown')} - {prev_state.get('cmd', '')[:80]}
Error: {prev_state.get('stderr', prev_state.get('error', 'Unknown'))[:100]}

You MUST add a code comment explaining how you overcame this issue.
Add the comment to the relevant file (script, config, etc.) before continuing."""

        print(msg.strip(), file=sys.stderr)
        # Keep state until documented - block with exit 2
        sys.exit(2)

    # Clear state on success (no previous error or already documented)
    if state_path.exists():
        state_path.unlink()
    sys.exit(0)
