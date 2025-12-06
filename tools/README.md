# Tools Directory

## Overview

The tools directory contains utility scripts and helper programs that support the capability-based deployment system. These tools assist with validation, testing, discovery, code generation, and operational tasks.

## Tool Categories

### Validation Tools

Tools for validating configuration and operation definitions:

- **`validate-capability.sh`** - Validate capability.yaml structure and schema
- **`validate-operation.sh`** - Validate operation YAML files
- **`validate-workflow.sh`** - Validate workflow definitions
- **`validate-config.sh`** - Validate user configuration files
- **`lint-yaml.sh`** - YAML syntax and style checking

### Discovery Tools

Tools for discovering and analyzing Azure resources:

- **`discover-resources.sh`** - Discover existing Azure resources
- **`analyze-dependencies.sh`** - Analyze resource dependencies
- **`generate-config.sh`** - Generate config from existing resources
- **`export-state.sh`** - Export current state of resources

### Testing Tools

Tools for testing operations and workflows:

- **`test-operation.sh`** - Test individual operations
- **`test-workflow.sh`** - Test complete workflows
- **`dry-run.sh`** - Simulate execution without making changes
- **`cleanup-test-resources.sh`** - Clean up test deployments

### Code Generation

Tools for generating boilerplate code:

- **`generate-capability.sh`** - Generate new capability structure
- **`generate-operation.sh`** - Generate operation template
- **`generate-workflow.sh`** - Generate workflow template
- **`generate-docs.sh`** - Generate documentation from code

### Operational Tools

Tools for managing and operating deployments:

- **`list-capabilities.sh`** - List all available capabilities
- **`list-operations.sh`** - List operations for a capability
- **`show-dependency-graph.sh`** - Visualize operation dependencies
- **`check-health.sh`** - Health check for deployed resources
- **`cost-estimate.sh`** - Estimate deployment costs

### Migration Tools

Tools for migrating from legacy system:

- **`migrate-module.sh`** - Convert old module to capability/operation
- **`migrate-config.sh`** - Convert config.env to config.yaml
- **`compare-configs.sh`** - Compare old and new configurations

## Common Tool Usage

### Validate Capability Definition

```bash
./tools/validate-capability.sh capabilities/compute/capability.yaml
```

Output:
```
✓ Schema validation passed
✓ Required fields present
✓ Resource types valid
✓ Dependencies resolved
✓ Validation rules defined
```

### Generate New Capability

```bash
./tools/generate-capability.sh monitoring
```

Creates:
```
capabilities/monitoring/
  ├── capability.yaml
  ├── README.md
  └── operations/
```

### Discover Existing Resources

```bash
./tools/discover-resources.sh \
  --subscription "sub-id" \
  --resource-group "rg-avd-prod" \
  --output discovered-resources.yaml
```

### Test Operation

```bash
./tools/test-operation.sh \
  --capability compute \
  --operation vm-create \
  --config test-config.yaml \
  --dry-run
```

### Show Dependency Graph

```bash
./tools/show-dependency-graph.sh \
  --workflow deploy-avd-complete \
  --format svg \
  --output workflow-graph.svg
```

### Cost Estimate

```bash
./tools/cost-estimate.sh \
  --workflow deploy-avd-complete \
  --config prod-config.yaml \
  --region eastus
```

## Tool Development Guidelines

### Script Standards

1. **Shebang**: Use `#!/usr/bin/env bash`
2. **Error Handling**: Set `set -euo pipefail`
3. **Help Text**: Provide `-h/--help` option
4. **Exit Codes**: Use meaningful exit codes
5. **Logging**: Use consistent logging functions

### Example Tool Template

```bash
#!/usr/bin/env bash
set -euo pipefail

# Tool metadata
TOOL_NAME="example-tool"
TOOL_VERSION="1.0.0"
TOOL_DESCRIPTION="Brief description of tool purpose"

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

# Function: Show help
show_help() {
    cat <<EOF
Usage: ${TOOL_NAME} [OPTIONS]

${TOOL_DESCRIPTION}

Options:
    -h, --help              Show this help message
    -v, --version           Show version information
    --config FILE           Configuration file
    --output FILE           Output file
    --verbose               Enable verbose output

Examples:
    ${TOOL_NAME} --config config.yaml
    ${TOOL_NAME} --config config.yaml --output result.yaml

EOF
}

# Function: Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "${TOOL_NAME} version ${TOOL_VERSION}"
                exit 0
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Function: Validate inputs
validate_inputs() {
    if [[ -z "${CONFIG_FILE:-}" ]]; then
        error "Config file required. Use --config option."
        exit 1
    fi

    if [[ ! -f "${CONFIG_FILE}" ]]; then
        error "Config file not found: ${CONFIG_FILE}"
        exit 1
    fi
}

# Function: Main logic
main() {
    parse_args "$@"
    validate_inputs

    info "Starting ${TOOL_NAME}..."

    # Tool implementation here

    success "Completed successfully"
}

# Execute main
main "$@"
```

### Logging Functions

Use consistent logging from `core/common.sh`:

```bash
# Information
info "Processing file: ${filename}"

# Success
success "Operation completed"

# Warning
warn "Configuration may be suboptimal"

# Error
error "Failed to validate schema"

# Debug (only shown with --verbose)
debug "Variable value: ${var}"
```

### Exit Codes

Use standard exit codes:

- `0` - Success
- `1` - General error
- `2` - Invalid arguments
- `3` - File not found
- `4` - Validation failed
- `5` - Execution failed

## Planned Tools

### High Priority

- [ ] `validate-capability.sh` - Capability validation
- [ ] `validate-operation.sh` - Operation validation
- [ ] `validate-workflow.sh` - Workflow validation
- [ ] `generate-capability.sh` - Capability generator
- [ ] `generate-operation.sh` - Operation generator
- [ ] `list-capabilities.sh` - List all capabilities
- [ ] `list-operations.sh` - List operations

### Medium Priority

- [ ] `discover-resources.sh` - Resource discovery
- [ ] `generate-config.sh` - Config generation from resources
- [ ] `test-operation.sh` - Operation testing
- [ ] `show-dependency-graph.sh` - Dependency visualization
- [ ] `check-health.sh` - Health checking
- [ ] `migrate-module.sh` - Module migration

### Low Priority

- [ ] `cost-estimate.sh` - Cost estimation
- [ ] `compare-configs.sh` - Config comparison
- [ ] `generate-docs.sh` - Documentation generation
- [ ] `cleanup-test-resources.sh` - Test cleanup
- [ ] `export-state.sh` - State export

## Integration with Core Engine

Tools integrate with the core engine through:

### 1. Configuration Loading

```bash
# Load configuration
source "${SCRIPT_DIR}/../core/config-manager.sh"
load_config "${CONFIG_FILE}"
```

### 2. State Management

```bash
# Access state
source "${SCRIPT_DIR}/../core/state-manager.sh"
get_state "key"
set_state "key" "value"
```

### 3. Discovery Engine

```bash
# Use discovery
source "${SCRIPT_DIR}/../core/discovery-engine.sh"
discover_resource "resourceType" "resourceName"
```

### 4. Query Engine

```bash
# Query resources
source "${SCRIPT_DIR}/../core/query-engine.sh"
query_resource "resourceType" "filter"
```

## Testing Tools

All tools should have corresponding tests:

```
tools/
  ├── validate-capability.sh
  └── tests/
      ├── test-validate-capability.sh
      └── fixtures/
          ├── valid-capability.yaml
          └── invalid-capability.yaml
```

Run tool tests:

```bash
# Run all tool tests
./tools/tests/run-all-tests.sh

# Run specific tool test
./tools/tests/test-validate-capability.sh
```

## Documentation

Each tool should have:

1. **Inline help** (`--help` option)
2. **Usage examples** in help text
3. **Comments** explaining complex logic
4. **README entry** (this file) with overview

## Contributing Tools

When adding a new tool:

1. Use the template above as starting point
2. Follow naming convention: `verb-noun.sh`
3. Add comprehensive help text
4. Include usage examples
5. Write tests for the tool
6. Update this README
7. Document in relevant capability/workflow docs

## Related Documentation

- [Execution Engine](../docs/02-execution-engine.md)
- [State Management](../docs/05-state-and-logging.md)
- [Discovery Engine](../docs/discovery-engine.md)
- [Development Rules](../docs/03-development-rules.md)
