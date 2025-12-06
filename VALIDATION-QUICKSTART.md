# Operation Validation - Quick Start Guide

## Overview

This project includes an automated validation framework for all capability operation YAML files. The framework ensures code quality, consistency, and correctness before deployment.

## Installation (One-Time Setup)

```bash
# 1. Install Python dependencies
pip install pyyaml

# 2. Install yq (optional but recommended for faster validation)
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

# 3. Make validation scripts executable (if not already)
chmod +x scripts/*.sh scripts/*.py

# 4. Verify installation
./scripts/validate-operations.sh --help
```

## Daily Workflow

### Before Committing Changes

Always run validation before committing operation files:

```bash
# Validate all operations
./scripts/validate-operations.sh

# Or validate just your changes
./scripts/validate-operations.sh capabilities/networking
```

### Running Individual Validations

```bash
# 1. YAML Syntax Check (fastest)
./scripts/validate-yaml-syntax.sh

# 2. Schema Compliance (most important)
python3 scripts/validate-schema.py

# 3. Variable References
python3 scripts/validate-variables.py

# 4. Dependencies
python3 scripts/validate-dependencies.py
```

## Understanding Results

### ✓ Success (Green)
```
✓ capabilities/networking/operations/vnet-create.yaml
```
File passed validation - no action needed.

### ✗ Failure (Red)
```
✗ capabilities/storage/operations/account-create.yaml
  - Missing required field: operation.duration.timeout
  - Invalid operation_mode: 'build'
```
File has errors - fix before committing.

## Common Issues & Fixes

### 1. Missing Required Field

**Error:**
```
✗ Missing required field: operation.duration.expected
```

**Fix:**
Add the missing field to your operation YAML:
```yaml
operation:
  duration:
    expected: 60    # seconds
    timeout: 180    # seconds
    type: "NORMAL"
```

### 2. Invalid Enum Value

**Error:**
```
✗ Invalid operation_mode: 'build' (must be one of: create, configure, ...)
```

**Fix:**
Use a valid enum value:
```yaml
operation:
  operation_mode: "create"  # Valid values: create, configure, validate, update, delete, read, modify
```

### 3. Undefined Variable

**Error:**
```
✗ Undefined variables:
    - {{MY_CUSTOM_VAR}}
```

**Fix (Option 1):** Add to config.yaml:
```yaml
my:
  custom:
    var: "value"
```

**Fix (Option 2):** Add to operation parameters:
```yaml
operation:
  parameters:
    required:
      - name: "MY_CUSTOM_VAR"
        type: "string"
        description: "My custom variable"
```

### 4. Missing Dependency

**Error:**
```
✗ Missing dependency: network-setup
```

**Fix:**
Ensure the referenced operation exists or update the dependency:
```yaml
operation:
  requires:
    - vnet-create  # Must match an existing operation.id
```

## Pre-Commit Hook (Recommended)

Automatically validate before every commit:

```bash
# Create pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
if git diff --cached --name-only | grep -q "^capabilities/.*/operations/.*\.yaml$"; then
    echo "Validating operations..."
    ./scripts/validate-operations.sh || exit 1
fi
EOF

chmod +x .git/hooks/pre-commit
```

## CI/CD Integration

The validation suite automatically runs on:
- ✓ Every push to operation files
- ✓ Every pull request
- ✓ Manual workflow trigger

View results in the GitHub Actions tab.

## Performance

Typical execution times:
- Single operation: <1 second
- Full suite (79 ops): ~11 seconds

## Getting Help

### Documentation
- **Full documentation:** [scripts/README.md](scripts/README.md)
- **Test report:** [VALIDATION-TEST-REPORT.md](VALIDATION-TEST-REPORT.md)
- **Schema reference:** [docs/04-module-structure.md](docs/04-module-structure.md)

### Troubleshooting

**Validation scripts not found:**
```bash
chmod +x scripts/*.sh scripts/*.py
```

**Python module errors:**
```bash
pip install pyyaml
```

**yq not found:**
```bash
# Skip - scripts will fall back to Python YAML parser
```

## Quick Reference

### Valid Enum Values

**operation_mode:**
- create
- configure
- validate
- update
- delete
- read
- modify
- adopt
- assign
- verify
- add
- remove
- drain

**duration.type:**
- FAST (< 30 seconds)
- NORMAL (30-120 seconds)
- WAIT (> 120 seconds)
- LONG (> 300 seconds)

**capability:**
- networking
- storage
- identity
- compute
- avd
- management

**template.type:**
- powershell-local
- powershell-remote
- powershell-vm-command
- azure-cli
- bash
- bash-script

### Required Fields

Every operation MUST have:
```yaml
operation:
  id: "operation-id"
  name: "Operation Name"
  description: "What this operation does"
  capability: "networking"
  operation_mode: "create"
  resource_type: "Microsoft.Network/virtualNetworks"

  duration:
    expected: 60
    timeout: 180
    type: "NORMAL"

  parameters:
    required: []
    optional: []

  template:
    type: "powershell-local"
    command: |
      # Your PowerShell command here
```

## Support

If you encounter issues not covered here:
1. Check [scripts/README.md](scripts/README.md) for detailed docs
2. Review [VALIDATION-TEST-REPORT.md](VALIDATION-TEST-REPORT.md) for known issues
3. Contact the team with the error output

---

**Remember:** Always run `./scripts/validate-operations.sh` before committing operation files!
