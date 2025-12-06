# Claude Code Hooks

This directory contains hook scripts that run automatically at various points in Claude Code's lifecycle.

## Available Hooks

### validate-yaml.sh
**Trigger:** `PostToolUse` (after Write/Edit tools)  
**Purpose:** Validates YAML operation files for syntax and required fields

### check-config.sh
**Trigger:** `SessionStart` (when Claude Code starts)  
**Purpose:** Reminds to load configuration from config.yaml

For complete documentation, see the hooks section in the main CLAUDE.md file.
