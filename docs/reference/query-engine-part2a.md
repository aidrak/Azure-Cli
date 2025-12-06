# Query all VMs
vms=$(query_resources "compute")
echo "$vms" | jq -r '.[] | "\(.name) - \(.powerState)"'

# Query specific VM
vm=$(query_resource "vm" "avd-sh-01" "RG-Azure-VDI-01")
echo "$vm" | jq -r '.vmSize'
```

### Cache-First with Fallback

```bash
# Try cache first, fallback to Azure on miss
resource=$(query_resource "vm" "my-vm" "my-rg")

# Force fresh query by invalidating cache first
invalidate_cache "vm:my-rg:my-vm" "Force refresh"
resource=$(query_resource "vm" "my-vm" "my-rg")
```

### Bulk Queries with Filtering

```bash
# Query all VMs, filter in JQ
all_vms=$(query_resources "compute" "" "full")
running_vms=$(echo "$all_vms" | jq '[.[] | select(.powerState == "VM running")]')

echo "Running VMs: $(echo "$running_vms" | jq 'length')"
```

### Multi-Resource Queries

```bash
# Query multiple resource types
compute=$(query_resources "compute")
networking=$(query_resources "networking")
storage=$(query_resources "storage")

# Combine into single summary
jq -n \
    --argjson c "$compute" \
    --argjson n "$networking" \
    --argjson s "$storage" \
    '{
        compute: ($c | length),
        networking: ($n | length),
        storage: ($s | length)
    }'
```

### Error Handling

```bash
# Query with error handling
if ! vm=$(query_resource "vm" "my-vm" "my-rg" 2>/dev/null); then
    log_error "Failed to query VM"
    exit 1
fi

# Check if resource exists
if [[ -z "$vm" ]] || [[ "$vm" == "null" ]]; then
    log_error "VM not found"
    exit 1
fi
```

---

## Performance Considerations

### Cache TTL Strategy

- **Single Resource:** 300s (5 min)
  - Assumption: Individual resources change infrequently
  - Longer TTL reduces Azure API calls

- **Resource Lists:** 120s (2 min)
  - Assumption: Lists may change more frequently
  - Shorter TTL for fresher data

### Token Efficiency

**Example: Querying 10 VMs**

| Approach | Total Tokens | Efficiency |
|----------|--------------|------------|
| Raw Azure CLI output | ~20,000 | Baseline |
| Full filter (`compute.jq`) | ~2,000 | 90% reduction |
| Summary filter | ~500 | 97.5% reduction |

**Best Practices:**
1. Use `summary` format for overviews
2. Use `full` format only when needed
3. Query specific resources when possible (not lists)
4. Leverage cache for repeated queries

### Azure API Rate Limits

Azure CLI has rate limits. The cache helps by:
- Reducing redundant API calls
- Batch queries when possible
- Invalidate strategically (not aggressively)

**Rate Limit Guidelines:**
- ~12,000 reads/hour per subscription
- Cache reduces calls by 80-95% typically

---

## Troubleshooting

### Cache Not Working

**Symptom:** Every query hits Azure (no cache hits)

**Solutions:**
1. Check if `state-manager.sh` exists:
   ```bash
   ls -l core/state-manager.sh
   ```
2. Check SQLite database:
   ```bash
   sqlite3 state.db "SELECT COUNT(*) FROM resources;"
   ```
3. Enable debug logging:
   ```bash
   export DEBUG=1
   source core/query.sh
   ```

### JQ Filter Errors

**Symptom:** JQ errors when querying resources

**Solutions:**
1. Test filter manually:
   ```bash
   az vm list -o json | jq -f queries/compute.jq
   ```
2. Check filter syntax:
   ```bash
   jq --help
   ```
3. Regenerate filter:
   ```bash
   rm queries/compute.jq
   source core/query.sh
   ensure_jq_filter_exists "compute"
   ```

### Azure CLI Errors

**Symptom:** "Command failed" errors

**Solutions:**
1. Verify Azure login:
   ```bash
   az account show
   ```
2. Check resource group exists:
   ```bash
   az group show --name RG-Azure-VDI-01
   ```
3. Verify permissions:
