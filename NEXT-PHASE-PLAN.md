# Azure CLI Capability System - Next Phase Implementation Plan

**Date:** 2025-12-06
**Status:** Planning
**Migration Status:** ✓ COMPLETE (79 operations migrated)

---

## Overview

This document outlines the next phase of work to complete the capability-based operation system, with agent assignments optimized for complexity and token usage.

---

## Short Term Tasks (Sprint 1)

### Task 1: Update Execution Engine for New Schema
**Priority:** HIGH
**Complexity:** HIGH
**Agent:** Sonnet
**Estimated Tokens:** 40k-60k
**Dependencies:** None

**Objective:** Modify `core/engine.sh` and related core components to support the new capability-based schema while maintaining backward compatibility with legacy module format.

**Current State:**
- Engine expects operations in `modules/*/operations/`
- Engine parses old module.yaml format
- Engine looks for operations by module name

**Required Changes:**
1. Add capability-based operation discovery (`capabilities/*/operations/`)
2. Parse new operation schema (capability, operation_mode, resource_type)
3. Handle new parameter format (required/optional with types)
4. Support new idempotency checks (check_command)
5. Execute new validation framework
6. Handle rollback procedures
7. Track fixes array for self-healing
8. Maintain backward compatibility with legacy modules

**Files to Modify:**
- `core/engine.sh` - Main orchestration logic
- `core/template-engine.sh` - Variable substitution
- `core/progress-tracker.sh` - Operation tracking
- `core/config-manager.sh` - Parameter loading

**Deliverables:**
- Updated engine supporting both formats
- Capability discovery mechanism
- Operation lookup by capability + operation_id
- Validation of new schema fields
- Test run of 3-5 migrated operations

---

### Task 2: Create capability-system-design.md
**Priority:** HIGH
**Complexity:** MEDIUM
**Agent:** Haiku
**Estimated Tokens:** 15k-25k
**Dependencies:** None

**Objective:** Create comprehensive design documentation for the capability-based system.

**Content Requirements:**
1. **Architecture Overview**
   - Capability-based organization
   - Operation schema definition
   - Execution flow diagrams

2. **Schema Reference**
   - All fields with types and descriptions
   - Example operations for each capability
   - Parameter types and validation rules

3. **Capability Domains**
   - networking (23 operations)
   - storage (6 operations)
   - identity (18 operations)
   - compute (13 operations)
   - avd (12 operations)
   - management (2 operations)

4. **Operation Lifecycle**
   - Discovery → Validation → Execution → Verification
   - Idempotency checks
   - Rollback procedures
   - Self-healing tracking

5. **Migration Guide**
   - Converting legacy to capability format
   - Testing migrated operations
   - Best practices

**Deliverables:**
- `docs/capability-system-design.md` (comprehensive reference)
- Include examples from all 7 capabilities
- Diagrams (ASCII art acceptable)

---

### Task 3: Update MIGRATION-INDEX.md with All Operations
**Priority:** MEDIUM
**Complexity:** LOW
**Agent:** Haiku
**Estimated Tokens:** 10k-15k
**Dependencies:** None

**Objective:** Update MIGRATION-INDEX.md to reflect all 79 migrated operations instead of just the original 5 POC operations.

**Required Updates:**
1. Update operation count (5 → 79)
2. List all operations by capability
3. Update statistics (file sizes, parameters, validation checks, rollback steps)
4. Add batch migration information
5. Cross-reference docs/migration/migration-complete-report.md
6. Update known limitations section

**Reference Files:**
- docs/migration/migration-complete-report.md (source of truth)
- All capabilities/*/operations/*.yaml files

**Deliverables:**
- Updated MIGRATION-INDEX.md with complete inventory

---

### Task 4: Implement Automated Validation in CI/CD
**Priority:** MEDIUM
**Complexity:** MEDIUM
**Agent:** Sonnet
**Estimated Tokens:** 25k-35k
**Dependencies:** None

**Objective:** Create automated validation pipeline for all capability operations.

**Validation Components:**

1. **YAML Syntax Validation**
   - Parse all .yaml files in capabilities/*/operations/
   - Check for syntax errors
   - Validate against schema

2. **Schema Compliance Validation**
   - Verify all required fields present
   - Check field types (duration.expected = integer, etc.)
   - Validate enums (operation_mode, duration.type)
   - Ensure parameter types defined

3. **PowerShell Script Validation**
   - Extract PowerShell from template.command
   - Basic syntax check (if possible)
   - Variable placeholder validation ({{VAR_NAME}})

4. **Dependency Validation**
   - Check that prerequisites reference real operations
   - Detect circular dependencies
   - Validate dependency chains

5. **Documentation Validation**
   - Ensure all operations have descriptions
   - Check parameter documentation
   - Validate rollback procedures

**Deliverables:**
- `.github/workflows/validate-operations.yml` (or equivalent)
- `scripts/validate-operations.sh` (validation script)
- `scripts/validate-schema.py` (Python schema validator)
- CI/CD integration instructions

---

### Task 5: Test Sample Operations End-to-End
**Priority:** HIGH
**Complexity:** MEDIUM
**Agent:** Sonnet
**Estimated Tokens:** 30k-40k
**Dependencies:** Task 1 (Engine Update)

**Objective:** Perform end-to-end testing of migrated operations across all capabilities.

**Test Plan:**

1. **Select Test Operations** (one from each capability):
   - networking: vnet-create.yaml
   - storage: account-create.yaml
   - identity: group-create.yaml
   - compute: vm-create.yaml
   - avd: hostpool-create.yaml
   - management: resource-group-create.yaml

2. **Test Scenarios:**
   - Fresh execution (create resources)
   - Idempotency check (run again, should skip)
   - Validation checks (verify resources exist)
   - Rollback procedures (cleanup)

3. **Validation Points:**
   - Operation discovery works
   - Parameter substitution correct
   - Idempotency check executes
   - PowerShell script runs successfully
   - Azure resources created
   - Validation passes
   - Rollback cleans up

**Deliverables:**
- Test execution report
- Bug/issue list (if any)
- Recommendations for engine improvements

---

## Medium Term Tasks (Sprint 2-3)

### Task 6: Decommission Legacy Module System
**Priority:** MEDIUM
**Complexity:** LOW
**Agent:** Haiku
**Estimated Tokens:** 10k-15k
**Dependencies:** Task 1, Task 5 (validation that new system works)

**Objective:** Archive legacy module system and update documentation.

**Actions:**
1. Move `modules/` directory to `legacy/modules/` (archive)
2. Update all documentation references
3. Remove legacy-specific code from engine (if desired)
4. Update README.md and CLAUDE.md
5. Create migration completion notice

**Deliverables:**
- Archived legacy system
- Updated documentation
- Clean project structure

---

### Task 7: Create Capability Management Tools
**Priority:** MEDIUM
**Complexity:** MEDIUM
**Agent:** Sonnet
**Estimated Tokens:** 30k-45k
**Dependencies:** Task 1

**Objective:** Build CLI tools for managing capabilities and operations.

**Tools to Create:**

1. **capability-cli.sh** - Main CLI tool
   ```bash
   ./capability-cli.sh list                          # List all capabilities
   ./capability-cli.sh show networking               # Show all networking ops
   ./capability-cli.sh info vnet-create              # Show operation details
   ./capability-cli.sh validate vnet-create          # Validate operation schema
   ./capability-cli.sh create my-capability          # Create new capability
   ./capability-cli.sh add-operation networking my-op # Create operation template
   ```

2. **Operation Template Generator**
   - Create skeleton operation YAML
   - Prompt for required fields
   - Generate with proper schema

3. **Capability Statistics**
   - Count operations per capability
   - Show parameter usage
   - Identify missing validations/rollbacks

**Deliverables:**
- `tools/capability-cli.sh` - Management CLI
- `tools/operation-template.yaml` - Template generator
- `tools/capability-stats.sh` - Statistics tool
- Documentation in `docs/capability-tools.md`

---

### Task 8: Implement Capability Discovery Framework
**Priority:** MEDIUM
**Complexity:** MEDIUM
**Agent:** Sonnet
**Estimated Tokens:** 25k-35k
**Dependencies:** Task 1

**Objective:** Create dynamic capability and operation discovery system.

**Features:**

1. **Capability Registry**
   - Auto-discover all capabilities in `capabilities/`
   - Load metadata (description, operations count)
   - Cache for performance

2. **Operation Index**
   - Build searchable operation index
   - Support lookup by:
     - Operation ID
     - Capability
     - Resource type
     - Operation mode

3. **Metadata Extraction**
   - Parse all operation YAML files
   - Extract parameters, prerequisites, duration
   - Build dependency graph

4. **Search and Filter**
   - Find operations by keyword
   - Filter by capability or resource type
   - Query by operation mode (create, configure, validate)

**Deliverables:**
- `core/capability-discovery.sh` - Discovery engine
- `core/operation-index.sh` - Indexing system
- Integration with main engine
- Performance optimization (caching)

---

### Task 9: Build Automated Dependency Resolver
**Priority:** HIGH
**Complexity:** HIGH
**Agent:** Opus
**Estimated Tokens:** 50k-70k
**Dependencies:** Task 8 (Discovery Framework)

**Objective:** Create intelligent dependency resolution system for operation execution.

**Features:**

1. **Dependency Graph Builder**
   - Parse all operation prerequisites
   - Build directed acyclic graph (DAG)
   - Detect circular dependencies

2. **Execution Order Planner**
   - Topological sort of operations
   - Identify parallel execution opportunities
   - Respect sequential constraints

3. **Smart Execution**
   - Auto-execute prerequisites first
   - Run independent operations in parallel
   - Handle failures gracefully

4. **Dependency Validation**
   - Verify all prerequisites exist
   - Check for broken references
   - Suggest missing dependencies

**Example:**
```bash
# User requests: ./engine.sh run hostpool-create
# System auto-executes in order:
1. resource-group-create
2. vnet-create (parallel with storage-account-create)
3. subnet-create
4. vm-create
5. golden-image-* (9 operations in sequence)
6. image-create
7. hostpool-create ← original request
```

**Deliverables:**
- `core/dependency-resolver.sh` - DAG builder and resolver
- `core/execution-planner.sh` - Execution order optimizer
- Integration with engine.sh
- Visualization tool (optional)

---

### Task 10: Add Operation Health Checks
**Priority:** MEDIUM
**Complexity:** MEDIUM
**Agent:** Sonnet
**Estimated Tokens:** 25k-35k
**Dependencies:** Task 1

**Objective:** Implement health monitoring for deployed resources.

**Health Check System:**

1. **Health Check Definitions**
   - Add `health_check` section to operation schema
   - Define check commands
   - Specify expected results

2. **Health Monitor**
   - Run health checks on deployed resources
   - Track resource state over time
   - Alert on failures

3. **Self-Healing Triggers**
   - Detect failed health checks
   - Trigger automatic remediation
   - Log healing actions in `fixes` array

4. **Health Dashboard**
   - Show status of all deployed resources
   - Historical health data
   - Failure trends

**Deliverables:**
- Health check framework
- Integration with operations
- `./engine.sh health` command
- Self-healing automation

---

## Known Issues to Address

### Issue 1: Missing Operation 02-system-prep.yaml
**Priority:** LOW
**Complexity:** LOW
**Agent:** Haiku
**Estimated Tokens:** 5k-10k

**Objective:** Investigate and resolve missing golden-image operation.

**Actions:**
1. Search legacy modules for 02-system-prep.yaml
2. Check if merged into another operation
3. Create operation if needed
4. Document findings

---

## Agent Assignment Summary

| Task | Priority | Agent | Est. Tokens | Duration |
|------|----------|-------|-------------|----------|
| 1. Engine Update | HIGH | **Sonnet** | 40k-60k | 2-3 hours |
| 2. Design Doc | HIGH | **Haiku** | 15k-25k | 1 hour |
| 3. Update Index | MEDIUM | **Haiku** | 10k-15k | 30 min |
| 4. CI/CD Validation | MEDIUM | **Sonnet** | 25k-35k | 1-2 hours |
| 5. End-to-End Tests | HIGH | **Sonnet** | 30k-40k | 2 hours |
| 6. Decommission Legacy | MEDIUM | **Haiku** | 10k-15k | 30 min |
| 7. Management Tools | MEDIUM | **Sonnet** | 30k-45k | 2 hours |
| 8. Discovery Framework | MEDIUM | **Sonnet** | 25k-35k | 1-2 hours |
| 9. Dependency Resolver | HIGH | **Opus** | 50k-70k | 3-4 hours |
| 10. Health Checks | MEDIUM | **Sonnet** | 25k-35k | 1-2 hours |
| 11. Missing Operation | LOW | **Haiku** | 5k-10k | 30 min |

**Total Estimated Tokens:** ~265k-355k across all tasks
**Recommended Parallel Execution:** Tasks 2, 3, 4 can run in parallel with Task 1

---

## Execution Strategy

### Phase 1: Foundation (Sprint 1 - Week 1)
**Run in Parallel:**
- Task 1 (Sonnet) - Engine Update
- Task 2 (Haiku) - Design Documentation
- Task 3 (Haiku) - Update Index
- Task 4 (Sonnet) - CI/CD Validation

**Sequential:**
- Task 5 (Sonnet) - End-to-End Tests (after Task 1)

### Phase 2: Enhancement (Sprint 2-3 - Week 2-3)
**Run in Parallel:**
- Task 7 (Sonnet) - Management Tools
- Task 8 (Sonnet) - Discovery Framework
- Task 6 (Haiku) - Decommission Legacy

**Sequential:**
- Task 9 (Opus) - Dependency Resolver (after Task 8)
- Task 10 (Sonnet) - Health Checks

### Phase 3: Cleanup
- Task 11 (Haiku) - Missing Operation Investigation

---

## Success Criteria

- ✓ Engine supports new capability schema
- ✓ All 79 operations executable via new engine
- ✓ Automated validation passing
- ✓ End-to-end tests passing
- ✓ Complete documentation available
- ✓ Dependency resolution working
- ✓ Health checks implemented
- ✓ Legacy system archived

---

**Generated:** 2025-12-06
**Next Review:** After Phase 1 completion
