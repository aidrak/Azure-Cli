# Workflow Engine

The Workflow Engine orchestrates multi-step deployments by chaining together individual operations in a declarative, YAML-based format.

## Overview

The workflow engine provides:
- **Sequential Execution**: Steps execute one after another in defined order
- **State Tracking**: Complete execution history stored in JSON state files
- **Error Handling**: Configurable continue-on-error behavior per step
- **Logging**: Comprehensive structured logging of all workflow activity
- **Variable Substitution**: Environment variables and config values automatically substituted
- **Extensible Design**: Foundation for future dependency resolution and parallel execution

## Architecture

```
workflow-engine.sh
├── Validation (validate_workflow)
│   ├── Check YAML syntax
│   ├── Verify required fields
│   └── Validate step definitions
│
├── Execution (execute_workflow)
│   ├── Initialize state
│   ├── Log operation start
│   ├── Execute steps sequentially
│   ├── Track progress
│   └── Update final status
│
├── State Management
│   ├── Workflow state JSON
│   ├── Step-level tracking
│   └── Execution artifacts
│
└── Querying
    ├── Get execution status
    └── List all executions
```

## Workflow YAML Format

### Basic Structure

```yaml
workflow:
  id: "unique-workflow-identifier"
  name: "Human-Readable Name"
  description: "Optional description"

  steps:
    - name: "Step Name"
      operation: "path/to/operation.yaml"
      continue_on_error: false
      parameters:
        key: "value"
```

### Field Definitions

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `workflow.id` | Yes | String | Unique identifier for the workflow (no spaces) |
| `workflow.name` | Yes | String | Human-readable workflow name |
| `workflow.description` | No | String | Optional description |
| `workflow.steps` | Yes | Array | List of steps to execute |

### Step Fields

| Field | Required | Type | Default | Description |
|-------|----------|------|---------|-------------|
| `name` | Yes | String | - | Human-readable step name |
| `operation` | Yes | String | - | Path to operation YAML file |
| `continue_on_error` | No | Boolean | `false` | Continue workflow if step fails |
| `parameters` | No | Object | `{}` | Step-specific parameters |

## Usage

### Sourcing the Engine

```bash
source core/workflow-engine.sh
```

### Executing a Workflow

```bash
# Basic execution
execute_workflow "workflows/my-deployment.yaml"

# Force mode (skip prerequisite validation)
execute_workflow "workflows/my-deployment.yaml" "true"
```

### Validating a Workflow

```bash
# Check workflow YAML structure and fields
validate_workflow "workflows/my-deployment.yaml"
```

### Previewing a Workflow

```bash
# Display workflow structure without executing
preview_workflow "workflows/my-deployment.yaml"
```

### Checking Status

```bash
# Get status of a specific execution
get_workflow_status "wf_simple-deployment_20251206_120000_a1b2"

# List all workflow executions
list_workflow_executions
```

## Workflow Example

### Basic Deployment

```yaml
workflow:
  id: "golden-image-deployment"
  name: "Golden Image Deployment"
  description: "Create and configure a golden image VM"

  steps:
    - name: "Create Temporary VM"
      operation: "modules/05-golden-image/operations/00-create-vm.yaml"
      continue_on_error: false

    - name: "Validate VM Creation"
      operation: "modules/05-golden-image/operations/01-validate-vm.yaml"
      continue_on_error: false

    - name: "System Preparation"
      operation: "modules/05-golden-image/operations/02-system-prep.yaml"
      continue_on_error: false

    - name: "Install FSLogix"
      operation: "modules/05-golden-image/operations/03-install-fslogix.yaml"
      continue_on_error: true
```

## State Management

### State File Location

Workflow state is stored in JSON format at:
```
artifacts/workflow-state/wf_{workflow_id}_{timestamp}_{random}.json
```

### State File Structure

```json
{
  "execution_id": "wf_workflow_id_20251206_120000_a1b2",
  "workflow_id": "workflow_id",
  "workflow_name": "Workflow Name",
  "status": "completed|running|failed",
  "start_time": "2025-12-06T12:00:00.000Z",
  "end_time": "2025-12-06T12:05:23.456Z",
  "total_steps": 4,
  "completed_steps": 4,
  "failed_steps": [],
  "skipped_steps": [],
  "steps": {
    "step_0": {
      "index": 0,
      "name": "Create VM",
      "status": "completed",
      "output": "...",
      "completed_at": "2025-12-06T12:01:00.000Z"
    }
  }
}
```

## Error Handling

### Default Behavior (continue_on_error: false)

When a step fails, the entire workflow is aborted:

```yaml
steps:
  - name: "Critical Step"
    operation: "critical-operation.yaml"
    continue_on_error: false  # Fails the workflow
```

### Continue on Error

Steps can be marked to continue on error for optional operations:

```yaml
steps:
  - name: "Optional Configuration"
    operation: "optional-config.yaml"
    continue_on_error: true  # Workflow continues even if this fails
```

## Dependencies (Future Enhancement)

The current implementation executes steps sequentially. Future enhancements will support:

```yaml
workflow:
  steps:
    - name: "Step 1"
      id: "step-1"
      operation: "op1.yaml"

    - name: "Step 2"
      id: "step-2"
      operation: "op2.yaml"
      depends_on: ["step-1"]  # Wait for step-1 to complete

    - name: "Step 3 (Parallel)"
      id: "step-3"
      operation: "op3.yaml"
      parallel: true  # Can run parallel to other parallel steps
```

## Integration Points

### Config Manager

Workflows automatically use variables from `config.yaml`:

```bash
# In operation.yaml, use {{VAR_NAME}} placeholders
# The workflow engine substitutes these automatically
```

### Executor

Workflows use the existing `execute_operation()` function from `executor.sh`:

```bash
# Each workflow step invokes an operation
execute_operation "path/to/operation.yaml"
```

### State Manager

Workflow state is tracked in the SQLite state database:

```bash
# Workflow executions are recorded in state.json
create_operation "workflow_exec_id" "workflow-engine"
```

### Logger

All workflow activity is logged via `logger.sh`:

```bash
log_operation_start "workflow_exec_id" "Workflow Name"
log_info "Step message" "workflow_exec_id"
log_operation_complete "workflow_exec_id" duration exit_code
```

## Implementation Details

### Key Functions

| Function | Purpose |
|----------|---------|
| `execute_workflow()` | Main entry point - executes workflow from YAML file |
| `validate_workflow()` | Validates workflow YAML structure |
| `preview_workflow()` | Displays workflow structure without executing |
| `init_workflow_state()` | Creates initial state JSON |
| `update_step_state()` | Records step execution result |
| `update_workflow_status()` | Updates overall workflow status |
| `get_workflow_status()` | Retrieves workflow execution status |
| `list_workflow_executions()` | Lists all workflow executions |

### Variable Substitution

Variables are substituted using `envsubst` from loaded config:

```bash
# These are automatically available in operations
export AZURE_RESOURCE_GROUP="my-rg"
export NETWORKING_VNET_NAME="my-vnet"

# Operations can use: {{AZURE_RESOURCE_GROUP}}, {{NETWORKING_VNET_NAME}}
```

## Logging and Artifacts

### Workflow Logs

Workflow execution logs are stored at:
```
artifacts/workflow-logs/{execution_id}.log
```

### Structured Logs

All activities are logged to:
```
artifacts/logs/deployment_YYYYMMDD.jsonl
```

### Artifacts Directory

```
artifacts/
├── workflow-state/        # Workflow execution state JSON files
├── workflow-logs/         # Workflow execution logs
├── logs/                  # Structured JSONL logs
├── outputs/               # Operation outputs (JSON)
└── scripts/               # Generated scripts
```

## Command-Line Interface

The workflow engine can be invoked directly:

```bash
# Execute workflow
./core/workflow-engine.sh execute workflows/my-workflow.yaml

# Validate workflow
./core/workflow-engine.sh validate workflows/my-workflow.yaml

# Preview workflow
./core/workflow-engine.sh preview workflows/my-workflow.yaml

# Check status
./core/workflow-engine.sh status wf_workflow_id_timestamp_hash

# List executions
./core/workflow-engine.sh list
```

## Troubleshooting

### Workflow Not Found
```
ERROR: Workflow file not found: workflows/my-workflow.yaml
```
**Solution**: Verify the workflow file path exists.

### Invalid YAML
```
ERROR: Invalid YAML in workflow file
```
**Solution**: Check YAML syntax with `yq e '.' workflows/my-workflow.yaml`

### Missing Required Field
```
ERROR: Workflow missing required field: .workflow.id
```
**Solution**: Ensure all required fields are present in workflow YAML.

### Operation Not Found
```
ERROR: Operation file not found: modules/01-networking/operations/op.yaml
```
**Solution**: Verify operation file path and that it exists.

### Step Execution Failed
```
ERROR: Step failed: Create VM
```
**Solution**:
- Check operation error logs in `artifacts/logs/`
- Review step output in workflow state JSON
- Use `get_workflow_status` to see detailed failure info

## Future Enhancements

Planned features for workflow engine v2:

1. **Dependency Resolution**
   - Support `depends_on` for explicit step ordering
   - DAG analysis and cycle detection

2. **Parallel Execution**
   - Mark steps as `parallel: true`
   - Execute independent steps concurrently
   - Manage resource limits

3. **Conditional Steps**
   - Skip steps based on conditions
   - Conditional branching based on step results

4. **Retry Logic**
   - Configure retry attempts per step
   - Backoff strategies

5. **Parameters and Variables**
   - Pass parameters between steps
   - Capture outputs from previous steps

6. **Templates**
   - Reusable workflow templates
   - Parameterized workflows

7. **Hooks**
   - Pre/post-workflow hooks
   - Pre/post-step hooks
   - Custom notifications

## See Also

- [Executor Guide](executor-guide.md)
- [State Manager Guide](state-manager-guide.md)
- [Configuration Guide](../docs/01-configuration.md)
