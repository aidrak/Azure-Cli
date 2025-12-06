# At execution
command: |
  az network vnet create --name "avd-vnet-prod"
```

**Rule 2: Derived from config.yaml**
```yaml
# config.yaml
networking:
  vnet:
    name: "avd-vnet-prod"

# Maps to placeholder
{{NETWORKING_VNET_NAME}} → "avd-vnet-prod"
```

**Rule 3: Case-sensitive**
```yaml
{{VNET_NAME}}  ≠  {{vnet_name}}  # Different placeholders
```

**Rule 4: Nested path support**
```yaml
# config.yaml
azure:
  networking:
    vnet:
      name: "avd-vnet"

# Placeholder (flattened)
{{AZURE_NETWORKING_VNET_NAME}} → "avd-vnet"
```

---

### Mapping from config.yaml

**Example config.yaml:**
```yaml
azure:
  resource_group: "RG-AVD-PROD"
  location: "eastus"

networking:
  vnet:
    name: "avd-vnet-prod"
    address_space: ["10.0.0.0/16"]
    dns_servers: ["8.8.8.8", "8.8.4.4"]

storage:
  account:
    name: "avdstorprod"
    sku: "Premium_LRS"
```

**Placeholder mappings:**
```
{{AZURE_RESOURCE_GROUP}}           → azure.resource_group
{{AZURE_LOCATION}}                 → azure.location
{{NETWORKING_VNET_NAME}}           → networking.vnet.name
{{NETWORKING_VNET_ADDRESS_SPACE}}  → networking.vnet.address_space
{{NETWORKING_DNS_SERVERS}}         → networking.vnet.dns_servers
{{STORAGE_ACCOUNT_NAME}}           → storage.account.name
{{STORAGE_ACCOUNT_SKU}}            → storage.account.sku
```

---

## Variable Substitution

### String Substitution

**Single placeholder:**
```powershell
$vnetName = "{{NETWORKING_VNET_NAME}}"
# Result: $vnetName = "avd-vnet-prod"
```

**Multiple placeholders in command:**
```bash
az network vnet create \
  --resource-group "{{AZURE_RESOURCE_GROUP}}" \
  --name "{{NETWORKING_VNET_NAME}}" \
  --location "{{AZURE_LOCATION}}"

# After substitution:
az network vnet create \
  --resource-group "RG-AVD-PROD" \
  --name "avd-vnet-prod" \
  --location "eastus"
```

---

### Conditional Substitution

**Check if placeholder has value:**
```powershell
if (-not [string]::IsNullOrEmpty("{{CUSTOM_DNS_SERVERS}}")) {
    $dnsServers = "{{CUSTOM_DNS_SERVERS}}"
    az network vnet create ... --dns-servers $dnsServers
}
```

**Bash conditional:**
```bash
if [ -n "{{CUSTOM_DNS_SERVERS}}" ]; then
  DNS_SERVERS="{{CUSTOM_DNS_SERVERS}}"
  az network vnet create ... --dns-servers "$DNS_SERVERS"
fi
```

---

### Array Expansion

**PowerShell array from space-separated string:**
```powershell
# config.yaml: address_space: ["10.0.0.0/16", "10.1.0.0/16"]
$addresses = "{{NETWORKING_VNET_ADDRESS_SPACE}}"
$addressArray = $addresses -split ' '
az network vnet create --address-prefixes @addressArray
```

**Bash array expansion:**
```bash
ADDRESS_SPACE="10.0.0.0/16 10.1.0.0/16"
IFS=' ' read -r -a ADDRESSES <<< "$ADDRESS_SPACE"
az network vnet create --address-prefixes "${ADDRESSES[@]}"
```

**Using yq for complex arrays:**
```bash
# Extract array from config.yaml
ADDRESSES=$(yq e '.networking.vnet.address_space | join(" ")' config.yaml)
IFS=' ' read -r -a ADDRESS_ARRAY <<< "$ADDRESSES"
```

---

### Nested Object Access

**config.yaml:**
```yaml
avd:
  hostpool:
    settings:
      max_sessions: 10
      load_balancer: "BreadthFirst"
```

**Placeholder access:**
```yaml
{{AVD_HOSTPOOL_SETTINGS_MAX_SESSIONS}}    → 10
{{AVD_HOSTPOOL_SETTINGS_LOAD_BALANCER}}   → "BreadthFirst"
```

---

## Best Practices

### Naming Conventions

**Placeholder names should:**
1. Use UPPERCASE
2. Use underscores for word separation
3. Match config.yaml structure (flattened path)
4. Be descriptive and unambiguous

**Examples:**
```yaml
✓ {{NETWORKING_VNET_NAME}}
✓ {{AZURE_RESOURCE_GROUP}}
✓ {{STORAGE_ACCOUNT_SKU}}
✗ {{VNET}} (too short, ambiguous)
✗ {{name}} (lowercase)
✗ {{NetworkingVnetName}} (PascalCase)
```

---

### Default Values

**Always provide defaults:**
```yaml
# GOOD: Has default
- name: "vnet_name"
  type: "string"
  description: "VNet name"
  default: "{{NETWORKING_VNET_NAME}}"

# BAD: No default
- name: "vnet_name"
  type: "string"
  description: "VNet name"
  # Missing default
```

---

### Sensitive Parameters

**Mark secrets as sensitive:**
```yaml
- name: "admin_password"
  type: "string"
  description: "Administrator password"
  default: "{{VM_ADMIN_PASSWORD}}"
  sensitive: true  # Masked in logs
```

**When to use sensitive:**
- Passwords
- API keys
- Connection strings with credentials
- Certificates
- Tokens

---

### Validation

**Use validation_regex for constraints:**
```yaml
# Storage account name (3-24 lowercase alphanumeric)
- name: "storage_account_name"
  type: "string"
  description: "Storage account name"
  default: "{{STORAGE_ACCOUNT_NAME}}"
  validation_regex: "^[a-z0-9]{3,24}$"

# Port number (1-65535)
- name: "port"
  type: "integer"
  description: "Port number"
  default: 443
  validation_regex: "^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$"
```

**Use validation_enum for fixed choices:**
```yaml
- name: "sku"
  type: "string"
  description: "Storage account SKU"
  default: "Premium_LRS"
  validation_enum:
    - "Standard_LRS"
    - "Standard_GRS"
    - "Premium_LRS"
```

---

## Related Documentation

- [Operation Schema](03-operation-schema.md) - Complete schema reference
- [Best Practices](12-best-practices.md) - Parameter design guidelines
- [Operation Examples](10-operation-examples.md) - Real parameter usage

---

**Last Updated:** 2025-12-06
