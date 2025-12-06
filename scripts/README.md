# Operation Validation Scripts

Automated validation framework for capability operation YAML files with CI/CD integration.

## Overview

This validation suite ensures all operation files in `capabilities/*/operations/` comply with the capability schema, have valid syntax, properly reference variables, and maintain valid dependencies.

## Scripts

### 1. validate-yaml-syntax.sh

**Purpose:** Validate YAML syntax for all operation files

**Usage:**
```bash
./scripts/validate-yaml-syntax.sh [path]
```

**Features:**
- Uses `yq` or Python YAML parser to validate syntax
- Reports file path and line number for errors
- Generates summary statistics
- Exit code: 0 = all valid, 1 = syntax errors found

**Example:**
```bash
# Validate all operations
./scripts/validate-yaml-syntax.sh

# Validate specific directory
./scripts/validate-yaml-syntax.sh capabilities/networking/operations

# Validate single file
./scripts/validate-yaml-syntax.sh capabilities/storage/operations/account-create.yaml
```

**Output:**
```
======================================================================
YAML Syntax Validation
======================================================================

Using validator: yq

✓ capabilities/avd/operations/appgroup-create.yaml
✓ capabilities/avd/operations/hostpool-create.yaml
✗ capabilities/compute/operations/vm-create.yaml - YAML syntax error
  Error: yaml: line 45: did not find expected key

======================================================================
YAML Syntax Validation Summary
======================================================================
  Total:  85
  Passed: 84
  Failed: 1
```

---

### 2. validate-schema.py

**Purpose:** Validate operations comply with the capability schema

**Usage:**
```bash
python3 scripts/validate-schema.py [path]
```

**Features:**
- Validates all required fields are present
- Checks field types (integers, booleans, strings)
- Validates enums (operation_mode, capability, duration.type)
- Validates parameter structure
- Validates rollback and validation sections
- Comprehensive error reporting

**Required Fields:**
- `operation.id`
- `operation.name`
- `operation.description`
- `operation.capability`
- `operation.operation_mode`
- `operation.resource_type`
- `operation.duration.expected`
- `operation.duration.timeout`
- `operation.duration.type`
- `operation.template.type`
- `operation.template.command`

**Valid Enums:**
```yaml
operation_mode: [create, configure, validate, update, delete, read, modify, adopt, assign, verify, add, remove, drain]
duration.type: [FAST, NORMAL, WAIT]
capability: [networking, storage, identity, compute, avd, management]
template.type: [powershell-local, powershell-remote, azure-cli, bash]
```

**Example:**
```bash
# Validate all operations
python3 scripts/validate-schema.py

# Validate specific capability
python3 scripts/validate-schema.py capabilities/networking

# Validate single file
python3 scripts/validate-schema.py capabilities/storage/operations/account-create.yaml
```

**Output:**
```
======================================================================
Schema Validation Report
======================================================================

✓ capabilities/avd/operations/appgroup-create.yaml
✗ capabilities/compute/operations/vm-create.yaml
  - Missing required field: operation.duration.expected
  - Invalid operation_mode: 'build' (must be one of: create, configure, ...)
  - duration.timeout must be integer, got: str

======================================================================
Schema Validation Summary
======================================================================
  Total:  85
  Passed: 83
  Failed: 2

Failed files:
  - capabilities/compute/operations/vm-create.yaml (2 error(s))
  - capabilities/storage/operations/account-delete.yaml (1 error(s))
```

---

### 3. validate-variables.sh

**Purpose:** Validate all `{{PLACEHOLDER}}` variables have corresponding definitions

**Usage:**
```bash
./scripts/validate-variables.sh [path]
```

**Features:**
- Extracts all `{{VARIABLE}}` placeholders from template commands
- Checks if variables exist in:
  1. `config.yaml` (configuration values)
  2. Operation parameters (required/optional)
  3. Common engine-provided variables (AZURE_*, etc.)
- Reports undefined variables per file
- Generates global list of undefined variables

**Common Variables (Engine-Provided):**
```
AZURE_SUBSCRIPTION_ID
AZURE_TENANT_ID
AZURE_LOCATION
AZURE_RESOURCE_GROUP
AZURE_ENVIRONMENT
MANAGED_IDENTITY_NAME
RESOURCE_TAGS
DEPLOYMENT_ID
TIMESTAMP
OPERATION_ID
```

**Example:**
```bash
# Validate all operations
./scripts/validate-variables.sh

# Validate specific capability
./scripts/validate-variables.sh capabilities/identity
```

**Output:**
```
======================================================================
Variable Reference Validation
======================================================================

✓ capabilities/avd/operations/appgroup-create.yaml
✗ capabilities/storage/operations/account-create.yaml
  Undefined variables:
    - {{STORAGE_ACCOUNT_SKU}}
    - {{CUSTOM_SETTING}}

======================================================================
Variable Reference Validation Summary
======================================================================
  Total files:       85
  Files with issues: 3
  Undefined vars:    5

Undefined variables across all files:
  - {{STORAGE_ACCOUNT_SKU}}
  - {{CUSTOM_SETTING}}
  - {{UNKNOWN_VAR}}

Note: These variables should be defined in:
  1. config.yaml (as configuration values)
  2. operation.parameters.required or .optional (as operation parameters)
  3. Added to COMMON_VARS in this script (if engine-provided)
```

---

### 4. validate-dependencies.sh

**Purpose:** Validate operation prerequisites reference real operations

**Usage:**
```bash
./scripts/validate-dependencies.sh [path]
```

**Features:**
- Extracts all operation IDs and their `requires` dependencies
- Checks that referenced operations exist
- Detects circular dependencies using depth-first search
- Generates dependency statistics
- Reports missing dependencies and cycles

**Example:**
```bash
# Validate all operations
./scripts/validate-dependencies.sh

# Validate specific capability
./scripts/validate-dependencies.sh capabilities/avd
```

**Output:**
```
======================================================================
Dependency Validation
======================================================================

Analyzing operation dependencies...

Loaded 85 operations

✓ All dependencies reference existing operations

✓ No circular dependencies detected

======================================================================
Dependency Statistics
======================================================================
  Total operations:           85
  Operations with deps:       23
  Total dependencies:         45
  Max dependencies per op:    5
  Most dependent operation:   golden-image-validate
```

**Example with Errors:**
```
✗ Missing Dependencies Found:

  Operation: vm-create
  File: capabilities/compute/operations/vm-create.yaml
  Missing dependency: network-setup-missing

✗ Circular Dependencies Found:

  Cycle 1: op-a -> op-b -> op-c -> op-a
```

---

### 5. validate-operations.sh

**Purpose:** Run all validation checks in sequence (main runner)

**Usage:**
```bash
./scripts/validate-operations.sh [path]
```

**Features:**
- Runs all 4 validation scripts in order
- Continues on error to show all failures
- Generates comprehensive summary report
- Exit code: 0 = all passed, 1 = any failed

**Example:**
```bash
# Validate all operations
./scripts/validate-operations.sh

# Validate specific capability
./scripts/validate-operations.sh capabilities/networking
```

**Output:**
```
======================================================================
                    OPERATION VALIDATION SUITE
======================================================================

Target: capabilities

======================================================================
[1/4] YAML Syntax Validation
======================================================================

... (output from validate-yaml-syntax.sh) ...

======================================================================
[2/4] Schema Compliance Validation
======================================================================

... (output from validate-schema.py) ...

======================================================================
[3/4] Variable Reference Validation
======================================================================

... (output from validate-variables.sh) ...

======================================================================
[4/4] Dependency Validation
======================================================================

... (output from validate-dependencies.sh) ...

======================================================================
                        VALIDATION SUMMARY
======================================================================

✓ YAML Syntax Validation
✓ Schema Compliance Validation
✗ Variable Reference Validation
✓ Dependency Validation

======================================================================
FAILED - 1 validation(s) failed
======================================================================

Please fix the issues reported above and run again.
```

---

## CI/CD Integration

### GitHub Actions Workflow

**File:** `.github/workflows/validate-operations.yml`

**Triggers:**
- Push to `capabilities/*/operations/*.yaml`
- Pull requests modifying operation files
- Push to validation scripts
- Manual workflow dispatch

**Jobs:**

1. **validate** - Runs each validation individually with continue-on-error
   - Generates validation report in GitHub Actions summary
   - Shows which validations passed/failed

2. **validate-suite** - Runs the full suite with `validate-operations.sh`
   - Single comprehensive run
   - Fails on first error

**Setup:**
```yaml
- Install Python 3.11
- Install pyyaml
- Install yq
- Make scripts executable
- Run validations
```

**Viewing Results:**

Go to Actions tab in GitHub repository:
- Click on the workflow run
- View "Summary" for validation report table
- View individual step logs for detailed error messages

---

## Installation

### Prerequisites

**Required:**
- Python 3.8+ with PyYAML (`pip install pyyaml`)
- Bash 4.0+

**Optional (but recommended):**
- `yq` for faster YAML parsing
  ```bash
  sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
  sudo chmod +x /usr/local/bin/yq
  ```

### Setup

```bash
# Make all scripts executable
chmod +x scripts/*.sh
chmod +x scripts/*.py

# Install Python dependencies
pip install pyyaml

# Test the suite
./scripts/validate-operations.sh
```

---

## Local Development Workflow

### Before Committing

Run the validation suite on your changes:

```bash
# Validate all operations
./scripts/validate-operations.sh

# Validate specific capability you modified
./scripts/validate-operations.sh capabilities/networking
```

### Pre-commit Hook (Optional)

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash
# Validate operations before commit

# Check if any operation files are staged
if git diff --cached --name-only | grep -q "^capabilities/.*/operations/.*\.yaml$"; then
    echo "Validating operation files..."

    # Run validation suite
    ./scripts/validate-operations.sh

    if [ $? -ne 0 ]; then
        echo ""
        echo "❌ Validation failed. Please fix errors before committing."
        exit 1
    fi
fi

exit 0
```

```bash
chmod +x .git/hooks/pre-commit
```

---

## Troubleshooting

### Common Issues

**Issue:** `yq: command not found`
```bash
# Install yq
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

**Issue:** `ModuleNotFoundError: No module named 'yaml'`
```bash
# Install PyYAML
pip install pyyaml
```

**Issue:** `Permission denied` when running scripts
```bash
# Make scripts executable
chmod +x scripts/*.sh
chmod +x scripts/*.py
```

**Issue:** Schema validation fails with "Missing required field"
- Check that all required fields are present in the operation YAML
- Verify field names match exactly (case-sensitive)
- Use dot notation: `operation.duration.expected`

**Issue:** Variable validation reports undefined variables
- Add variable to `config.yaml` if it's a configuration value
- Add to `operation.parameters.required` or `.optional` if it's a parameter
- Add to `COMMON_VARS` in `validate-variables.sh` if it's engine-provided

**Issue:** Dependency validation reports missing dependencies
- Ensure referenced operation IDs exist
- Check spelling of dependency operation IDs
- Verify operation files are in the correct directory structure

---

## Extending the Validation Suite

### Adding New Validations

1. Create new script in `scripts/` directory
   ```bash
   scripts/validate-my-check.sh
   ```

2. Follow the standard format:
   - Accept optional path argument
   - Use colored output (RED, GREEN, YELLOW)
   - Print summary statistics
   - Exit with 0 (success) or 1 (failure)

3. Add to `validate-operations.sh`:
   ```bash
   run_validation \
       "My Custom Validation" \
       "$SCRIPT_DIR/validate-my-check.sh" \
       "5" \
       || true
   ```

4. Add to GitHub Actions workflow:
   ```yaml
   - name: Run My Custom Validation
     id: my-check
     run: ./scripts/validate-my-check.sh
     continue-on-error: true
   ```

### Adding New Schema Fields

Edit `scripts/validate-schema.py`:

1. Add to `REQUIRED_FIELDS`:
   ```python
   REQUIRED_FIELDS = [
       # ... existing fields ...
       'operation.my_new_field',
   ]
   ```

2. Add enum validation if needed:
   ```python
   VALID_MY_ENUM = ['value1', 'value2']

   if 'my_field' in operation:
       if operation['my_field'] not in VALID_MY_ENUM:
           errors.append(f"Invalid my_field: {operation['my_field']}")
   ```

---

## Performance

### Benchmarks

On a typical codebase with 85 operations:

| Validation | Time | Operations/sec |
|------------|------|----------------|
| YAML Syntax | 2.1s | 40 ops/s |
| Schema Compliance | 1.8s | 47 ops/s |
| Variable References | 3.2s | 26 ops/s |
| Dependencies | 1.5s | 56 ops/s |
| **Total Suite** | **8.6s** | **10 ops/s** |

### Optimization Tips

- Use `yq` instead of Python for YAML parsing (2x faster)
- Run validations in parallel for large codebases
- Cache operation metadata between validations
- Use CI/CD caching for Python dependencies

---

## Support

### Reporting Issues

If you find bugs or have feature requests:

1. Check existing issues
2. Provide sample operation file that fails
3. Include full error output
4. Specify Python/Bash/yq versions

### Contributing

1. Follow existing script patterns
2. Add comprehensive error messages
3. Update this README
4. Test on all 85+ operations
5. Ensure CI/CD pipeline passes

---

## License

Part of the Azure VDI Deployment Engine project.

---

## Related Documentation

- [ARCHITECTURE.md](../ARCHITECTURE.md) - System architecture
- [docs/04-module-structure.md](../docs/04-module-structure.md) - Operation YAML format
- [.github/workflows/validate-operations.yml](../.github/workflows/validate-operations.yml) - CI/CD configuration
