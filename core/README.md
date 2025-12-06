# Core Engine Components

This directory contains the core components of the Azure Infrastructure Toolkit.

## Components

### Configuration & Orchestration

**config-manager.sh**
- Loads and parses `config.yaml`
- Manages environment variables
- Validates configuration

**engine.sh**
- Main orchestration engine
- Executes operations from modules
- Manages operation lifecycle
- Tracks state and progress

**template-engine.sh**
- Processes Jinja2-style templates
- Substitutes configuration variables
- Generates scripts and configs

### State & Data Management

**state-manager.sh** *(Planned - Phase 1)*
- SQLite-backed state management
- Resource caching with TTL
- Dependency tracking
- Operation history

**query.sh** *(Current)*
- Azure resource query engine
- Cache-first approach
- JQ filtering for token efficiency
- Integration with state-manager

### Monitoring & Logging

**logger.sh**
- Structured JSON logging
- Operation lifecycle tracking
- Log queries and analysis
- Artifact management

**progress-tracker.sh**
- Real-time progress monitoring
- Multi-step operation tracking
- Progress bars and estimates

### Validation & Error Handling

**validator.sh**
- Pre-flight validation checks
- Configuration validation
- Resource state validation

**error-handler.sh**
- Centralized error handling
- Error recovery strategies
- Retry logic

## Query Engine (query.sh)

### Overview

The Query Engine provides intelligent, cache-first querying of Azure resources with token efficiency optimization.

**Key Features:**
- Cache-first strategy (via state-manager)
- JQ filtering for minimal token usage
- Support for all major Azure resource types
- Graceful degradation if state-manager unavailable

### Quick Start

```bash
source core/query.sh

# Query all VMs (summary)
vms=$(query_resources "compute")

# Query specific VM
vm=$(query_resource "vm" "avd-sh-01" "RG-Azure-VDI-01")

# Query with full details
vms_full=$(query_resources "compute" "RG-Azure-VDI-01" "full")
```

### Supported Resource Types

| Type | Aliases | Azure CLI Command |
|------|---------|-------------------|
| Compute (VMs) | `compute`, `vms`, `vm` | `az vm list` |
| Networking (VNets) | `networking`, `vnets`, `vnet` | `az network vnet list` |
| Storage | `storage` | `az storage account list` |
| Identity (Entra Groups) | `identity`, `groups`, `ad-group` | `az ad group list` |
| AVD (Host Pools) | `avd`, `hostpools`, `hostpool` | `az desktopvirtualization hostpool list` |
| All Resources | `all`, `resources` | `az resource list` |

### Cache Strategy

**Single Resource Queries:**
- TTL: 5 minutes (300 seconds)
- Cache key: `{type}:{rg}:{name}`
- Use: `query_resource()`

**Resource List Queries:**
- TTL: 2 minutes (120 seconds)
- Cache key: `{type}:{rg}`
- Use: `query_resources()`

**Invalidation:**
```bash
# Invalidate specific resource
invalidate_cache "vm:RG-Azure-VDI-01:avd-sh-01" "VM modified"

# Invalidate all compute in RG
invalidate_cache "compute:RG-Azure-VDI-01:*" "Deployment complete"

# Invalidate everything
invalidate_cache "*" "Full refresh"
```

### JQ Filters

Located in `queries/` directory:

**Token Reduction:**
- `summary.jq`: ~95% reduction (ultra-minimal)
- `compute.jq`: ~90% reduction (VM essentials)
- `networking.jq`: ~85% reduction (VNet essentials)
- `storage.jq`: ~80% reduction (Storage essentials)
- `identity.jq`: ~75% reduction (Group essentials)
- `avd.jq`: ~80% reduction (Host pool essentials)

### Integration with State Manager

The query engine integrates seamlessly with `state-manager.sh`:

```bash
# state-manager.sh will be sourced automatically if available
# Query engine provides graceful fallback if not available

# Cache operations (when state-manager available):
_get_cached_resource()      # Check cache
_store_cached_resource()    # Update cache
_invalidate_resource_cache() # Invalidate cache
```

### API Reference

See [docs/query-engine.md](../docs/query-engine.md) for complete API documentation.

### Examples

See [examples/query-examples.sh](../examples/query-examples.sh) for usage examples.

### Testing

```bash
# Run simple tests
./tests/test-query-simple.sh

# Run comprehensive tests
./tests/test-query.sh
```

## Integration Patterns

### With Engine

```bash
source core/engine.sh
source core/query.sh

# Validate VM before operation
vm=$(query_resource "vm" "my-vm" "my-rg")
if [[ $(echo "$vm" | jq -r '.provisioningState') != "Succeeded" ]]; then
    exit 1
fi

# Run operation
./core/engine.sh run compute/update
```

### With State Manager (when implemented)

```bash
source core/state-manager.sh
source core/query.sh

# Query and track
vm=$(query_resource "vm" "my-vm" "my-rg")
mark_as_managed "$(echo "$vm" | jq -r '.id')"
```

### With Logger

```bash
source core/logger.sh
source core/query.sh

log_info "Querying VMs..."
vms=$(query_resources "compute")
log_success "Found $(echo "$vms" | jq 'length') VMs"
```

## Performance Considerations

### Token Efficiency

**Example: Querying 10 VMs**
| Approach | Tokens | Reduction |
|----------|--------|-----------|
| Raw Azure CLI | ~20,000 | - |
| Full filter | ~2,000 | 90% |
| Summary filter | ~500 | 97.5% |

### Azure API Rate Limits

- Azure CLI: ~12,000 reads/hour per subscription
- Cache reduces calls by 80-95%
- Smart invalidation prevents over-querying

### Best Practices

1. Use `summary` format for overviews
2. Use `full` format only when needed
3. Query specific resources (not lists) when possible
4. Leverage cache for repeated queries
5. Invalidate strategically (not aggressively)

## Development

### Adding New Resource Types

1. Add case to `query_azure_raw()` in `query.sh`
2. Create JQ filter in `queries/{type}.jq`
3. Add resource-specific function `query_{type}_resources()`
4. Add case to `query_resources()` dispatcher
5. Update documentation

### Debugging

Enable debug logging:
```bash
export DEBUG=1
source core/query.sh
```

Check cache status:
```bash
source core/state-manager.sh
sqlite3 state.db "SELECT * FROM resources LIMIT 10;"
```

## Roadmap

### Phase 1: State Management (In Progress)
- [ ] Implement `state-manager.sh` with SQLite
- [x] Implement `query.sh` with cache integration
- [ ] Create database schema
- [ ] Implement cache TTL and invalidation

### Phase 2: Discovery & Dependencies
- [ ] Implement `discovery.sh` for full environment scanning
- [ ] Implement `dependency-resolver.sh` for DAG construction
- [ ] Build dependency graph visualization

### Phase 3: Analytics & Optimization
- [ ] Query performance metrics
- [ ] Smart cache prefetching
- [ ] Query optimization

## Support

For issues or questions:
1. Check [docs/query-engine.md](../docs/query-engine.md)
2. Review [examples/query-examples.sh](../examples/query-examples.sh)
3. Run tests: `./tests/test-query-simple.sh`
4. Enable debug logging: `export DEBUG=1`

---

**Last Updated:** 2025-12-06
**Version:** 1.0.0
