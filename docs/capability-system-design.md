# Capability System Design

## 1. Architecture Overview

The Capability System is a modular architecture for managing Azure infrastructure operations. It replaces the legacy module-based system with a granular, capability-oriented approach.

### Key Concepts

*   **Capability**: A logical grouping of related operations (e.g., `networking`, `storage`, `avd`).
*   **Operation**: A single, atomic unit of work (e.g., `vnet-create`, `hostpool-update`).
*   **Schema**: A standardized YAML format for defining operations.
*   **Engine**: The core execution logic that interprets operations and manages state.

### Directory Structure

```
capabilities/
├── [capability_name]/
│   ├── capability.yaml       # Metadata about the capability
│   └── operations/
│       ├── [operation_id].yaml  # Operation definition
│       └── ...
```

## 2. Operation Schema

Each operation is defined in a YAML file with the following structure:

```yaml
operation:
  id: "unique-operation-id"
  name: "Human Readable Name"
  description: "Description of what this operation does"
  capability: "capability-name"
  operation_mode: "create|update|delete|configure|validate"
  resource_type: "Microsoft.Provider/resourceType"

  duration:
    expected: 60  # seconds
    timeout: 300  # seconds
    type: "FAST|NORMAL|SLOW"

  parameters:
    required:
      - name: "param_name"
        type: "string|int|bool"
        description: "Description"
        default: "{{CONFIG_VAR}}"
    optional: []

  template:
    type: "powershell-local"
    command: |
      # script content here
      # supports {{VAR}} substitution

  validation:
    enabled: true
    checks:
      - type: "resource_exists"
        resource_type: "..."
        resource_name: "..."

  rollback:
    enabled: true
    steps:
      - name: "Cleanup"
        command: "..."
```

## 3. Execution Flow

1.  **Discovery**: The engine scans `capabilities/` for operation definitions.
2.  **Parsing**: YAML files are parsed, and metadata is extracted.
3.  **Configuration**: Variables are substituted using `config.yaml` values.
4.  **Prerequisite Check**: Dependencies are validated before execution.
5.  **Execution**: The `template.command` is executed (locally or remotely).
6.  **Validation**: Post-execution checks verify the desired state.
7.  **State Tracking**: Execution status is recorded in `state.json` and SQLite DB.

## 4. Migration Guide

### Converting Legacy Modules

1.  Identify the legacy shell script or function.
2.  Create a new YAML file in the appropriate `capabilities/[domain]/operations/` folder.
3.  Extract the logic into the `template.command` block.
4.  Replace bash variables (`$VAR`) with template placeholders (`{{VAR}}`).
5.  Define required parameters in the `parameters` section.
6.  Add validation and rollback logic.

### Variable Substitution

*   **Legacy**: `$VAR` (Bash)
*   **Capability**: `{{VAR}}` (Template) -> substituted before execution.

## 5. Best Practices

*   **Atomicity**: Operations should do one thing well.
*   **Idempotency**: Operations should be safe to run multiple times. Use `idempotency` checks.
*   **Validation**: Always define validation checks to ensure success.
*   **Rollback**: Provide rollback steps for resource creation operations.
