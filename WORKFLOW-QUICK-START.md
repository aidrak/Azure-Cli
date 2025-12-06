# Workflow Engine - Quick Start Guide

## What is the Workflow Engine?

The Workflow Engine orchestrates multi-step deployments by executing operations in sequence, tracking state, and logging activity. It's the automation backbone for complex Azure VDI deployments.

## Basic Workflow YAML

Create a file `workflows/my-deployment.yaml`:

```yaml
workflow:
  id: "my-deployment"
  name: "My Deployment Workflow"
  description: "Deploy networking, storage, and compute"

  steps:
    - name: "Create Virtual Network"
      operation: "modules/01-networking/operations/01-create-vnet.yaml"

    - name: "Create Storage Account"
      operation: "modules/02-storage/operations/01-create-storage.yaml"

    - name: "Optional Configuration"
      operation: "modules/02-storage/operations/02-configure-storage.yaml"
      continue_on_error: true  # Skip this step if it fails
```

## Run Your Workflow

### Preview Before Executing

See what will be executed without making changes:

```bash
./core/workflow-engine.sh preview workflows/my-deployment.yaml
```

Output shows:
- Workflow name and ID
- Step names in order
- Operations that will be executed

### Execute the Workflow

```bash
./core/workflow-engine.sh execute workflows/my-deployment.yaml
```

The engine will:
1. Validate the workflow YAML
2. Log the operation start
3. Execute each step sequentially
4. Track progress in real-time
5. Save state to `artifacts/workflow-state/`
6. Output the execution ID (for status checking)

### Check Execution Status

```bash
./core/workflow-engine.sh status wf_my-deployment_20251206_120000_a1b2
```

Shows:
- Overall status (completed/running/failed)
- Number of completed steps
- Failed steps (if any)
- Timestamps and duration

### List All Executions

```bash
./core/workflow-engine.sh list
```

Shows all workflow executions with timestamps and status.

## Sourcing in Scripts

Use the engine from within your scripts:

```bash
#!/bin/bash

source core/workflow-engine.sh

# Validate before executing
if validate_workflow "workflows/my-deployment.yaml"; then
    echo "Workflow is valid, executing..."
    execute_workflow "workflows/my-deployment.yaml"
else
    echo "Workflow validation failed"
    exit 1
fi
```

## Common Patterns

### Critical Steps (Stop on Failure)

```yaml
steps:
  - name: "Create Base Infrastructure"
    operation: "modules/01-networking/operations/base.yaml"
    continue_on_error: false  # Default - workflow stops if this fails
```

### Optional Steps (Continue on Failure)

```yaml
steps:
  - name: "Advanced Configuration"
    operation: "modules/advanced-config.yaml"
    continue_on_error: true  # Workflow continues if this fails
```

### Sequential Deployment

```yaml
steps:
  - name: "Step 1: Networking"
    operation: "modules/01-networking/create.yaml"

  - name: "Step 2: Storage"
    operation: "modules/02-storage/create.yaml"

  - name: "Step 3: Compute"
    operation: "modules/03-compute/create.yaml"
```

## Checking Logs

### Workflow Execution Log

Located at: `artifacts/workflow-logs/{execution_id}.log`

### Structured Logs

All workflow activities logged to: `artifacts/logs/deployment_YYYYMMDD.jsonl`

Query by workflow:
```bash
jq 'select(.operation_id | startswith("wf_my-deployment"))' artifacts/logs/deployment_*.jsonl
```

### Operation Output

Each operation produces output in: `artifacts/outputs/`

## Workflow State Files

Located at: `artifacts/workflow-state/wf_{id}_{timestamp}_{hash}.json`

View workflow state:
```bash
jq '.' artifacts/workflow-state/wf_my-deployment_*.json
```

## Validation

Check if a workflow is valid:

```bash
./core/workflow-engine.sh validate workflows/my-deployment.yaml
```

Checks:
- Valid YAML syntax
- Required fields present (id, name, steps)
- Each step has name and operation
- Operation files can be found

## Troubleshooting

### Operation File Not Found

```
ERROR: Operation file not found: modules/01-networking/operations/op.yaml
```

**Solution**: Verify the operation file exists at the specified path.

### Workflow Missing Required Field

```
ERROR: Workflow missing required field: .workflow.id
```

**Solution**: Ensure your workflow YAML has all required fields:
- `workflow.id` - Unique identifier
- `workflow.name` - Human-readable name
- `workflow.steps` - Array of steps

### Step Failed

View the operation output:
```bash
./core/workflow-engine.sh status wf_my-workflow_timestamp_hash
```

Check detailed logs:
```bash
tail -f artifacts/logs/deployment_$(date +%Y%m%d).jsonl
```

## Real-World Examples

### Deploy Golden Image

```yaml
workflow:
  id: "golden-image-deployment"
  name: "Deploy Golden Image VM"

  steps:
    - name: "Create Temporary VM"
      operation: "modules/05-golden-image/operations/00-create-vm.yaml"

    - name: "System Preparation"
      operation: "modules/05-golden-image/operations/02-system-prep.yaml"

    - name: "Install FSLogix"
      operation: "modules/05-golden-image/operations/03-install-fslogix.yaml"

    - name: "Finalize Image"
      operation: "modules/05-golden-image/operations/10-finalize.yaml"
```

### Deploy Session Hosts

```yaml
workflow:
  id: "session-host-deployment"
  name: "Deploy Session Hosts"

  steps:
    - name: "Create Networking"
      operation: "modules/01-networking/operations/create-subnet.yaml"

    - name: "Create VM Instances"
      operation: "modules/06-session-host-deployment/operations/01-create-vms.yaml"

    - name: "Join Domain"
      operation: "modules/06-session-host-deployment/operations/02-domain-join.yaml"

    - name: "Install Session Host"
      operation: "modules/06-session-host-deployment/operations/03-install-sh.yaml"

    - name: "Register with Host Pool"
      operation: "modules/06-session-host-deployment/operations/04-register.yaml"
```

## Key Points to Remember

1. **Workflows are declarative** - You declare what you want, the engine executes it
2. **State is tracked** - Every execution is recorded in artifacts/workflow-state/
3. **Operations are reused** - Workflows orchestrate existing operations
4. **Logging is comprehensive** - All activity logged to both console and structured logs
5. **Errors are handled** - Use `continue_on_error` for non-critical steps
6. **Preview first** - Always preview before executing

## Next Steps

1. **Create your first workflow** - Copy example and modify for your needs
2. **Preview it** - Check the structure with `preview`
3. **Validate it** - Check syntax with `validate`
4. **Execute it** - Run with `execute`
5. **Check status** - Review results with `status`
6. **Examine logs** - Debug with logs if needed

## Documentation

- Full technical docs: [WORKFLOW-ENGINE.md](core/WORKFLOW-ENGINE.md)
- Implementation summary: [WORKFLOW-ENGINE-SUMMARY.md](WORKFLOW-ENGINE-SUMMARY.md)
- Architecture overview: [ARCHITECTURE.md](ARCHITECTURE.md)

## Support

Questions or issues? Check:
1. [WORKFLOW-ENGINE.md](core/WORKFLOW-ENGINE.md) - Full documentation
2. [WORKFLOW-ENGINE-SUMMARY.md](WORKFLOW-ENGINE-SUMMARY.md) - Implementation details
3. `artifacts/logs/` - Check execution logs
4. `artifacts/workflow-state/` - Review workflow state

---

**Ready to deploy?** Create your first workflow and run:

```bash
./core/workflow-engine.sh execute workflows/my-workflow.yaml
```
