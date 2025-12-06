# Parameter System

**Complete guide to parameters, types, placeholders, and variable substitution**

## Table of Contents

1. [Required vs Optional Parameters](#required-vs-optional-parameters)
2. [Parameter Types](#parameter-types)
3. [Placeholder Syntax](#placeholder-syntax)
4. [Variable Substitution](#variable-substitution)
5. [Best Practices](#best-practices)

---

## Required vs Optional Parameters

### Required Parameters

**Definition:** Must be provided for operation to run.

**Characteristics:**
- Typically include: resource names, resource groups, locations
- Can have defaults from `config.yaml` via `{{PLACEHOLDER}}` syntax
- Engine validates presence before execution
- Missing required parameters cause operation to fail

**Example:**
```yaml
parameters:
  required:
    - name: "vnet_name"
      type: "string"
      description: "Name of the virtual network"
      default: "{{NETWORKING_VNET_NAME}}"

    - name: "resource_group"
      type: "string"
      description: "Azure resource group name"
      default: "{{AZURE_RESOURCE_GROUP}}"

    - name: "location"
      type: "string"
      description: "Azure region"
      default: "{{AZURE_LOCATION}}"
```

### Optional Parameters

**Definition:** May be omitted (uses default value).

**Characteristics:**
- Provide customization or advanced configuration
- Examples: custom tags, security settings, performance tuning
- Always have sensible defaults
- Can be overridden by user

**Example:**
```yaml
parameters:
  optional:
    - name: "dns_servers"
      type: "string"
      description: "Custom DNS servers (space-separated)"
      default: "{{NETWORKING_DNS_SERVERS}}"
      sensitive: false

    - name: "enable_ddos_protection"
      type: "boolean"
      description: "Enable DDoS protection"
      default: false

    - name: "tags"
      type: "string"
      description: "Resource tags (JSON format)"
      default: '{"Environment":"Production"}'
```

### When to Use Each

**Required:**
- Resource identifiers (names, IDs)
- Resource group and location
- Critical configuration (SKU for storage account)
- Security settings that must be explicit

**Optional:**
- Advanced features (DDoS protection, encryption)
- Performance tuning (session limits, timeouts)
- Metadata (tags, descriptions)
- Environment-specific settings

---

## Parameter Types

### String Parameters

**Most common parameter type for text values.**

**Definition:**
```yaml
- name: "vnet_name"
  type: "string"
  description: "Name of the virtual network"
  default: "{{NETWORKING_VNET_NAME}}"
  validation_regex: "^[a-zA-Z0-9-]{3,64}$"  # Optional
```

**Usage in PowerShell:**
```powershell
$vnetName = "{{NETWORKING_VNET_NAME}}"
az network vnet create --name $vnetName ...
```

**Usage in Bash:**
```bash
VNET_NAME="{{NETWORKING_VNET_NAME}}"
az network vnet create --name "$VNET_NAME" ...
```

**Common Use Cases:**
- Resource names
- Resource IDs
- File paths
- URLs
- Connection strings

---

### Integer Parameters

**Numeric values without decimals.**

**Definition:**
```yaml
- name: "max_sessions"
  type: "integer"
  description: "Maximum sessions per host"
  default: 10
  validation_regex: "^[1-9][0-9]{0,2}$"  # 1-999
```

**Usage in PowerShell:**
```powershell
$maxSessions = 10
az desktopvirtualization hostpool create --max-session-limit $maxSessions ...
```

**Usage in Bash:**
```bash
MAX_SESSIONS=10
az desktopvirtualization hostpool create --max-session-limit $MAX_SESSIONS ...
```

**Common Use Cases:**
- Port numbers
- Session limits
- Retry counts
- Timeouts
- Quotas

---

### Boolean Parameters

**True/false values.**

**Definition:**
```yaml
- name: "enable_secure_boot"
  type: "boolean"
  description: "Enable Secure Boot"
  default: true
```

**Usage in PowerShell:**
```powershell
if ($enableSecureBoot) {
    $securityType = "TrustedLaunch"
} else {
    $securityType = "Standard"
}
```

**Usage in Bash:**
```bash
if [ "{{ENABLE_SECURE_BOOT}}" = "true" ]; then
  SECURITY_TYPE="TrustedLaunch"
else
  SECURITY_TYPE="Standard"
fi
```

**Common Use Cases:**
- Feature toggles (enable_encryption, enable_logging)
- Security settings (require_secure_boot, enforce_tls)
- Conditional behavior (skip_validation, dry_run)

---

### Array Parameters

**Multiple values stored as space-separated string.**

**Definition:**
```yaml
- name: "address_space"
  type: "string"
  description: "Address space (space-separated)"
  default: "10.0.0.0/16 10.1.0.0/16"
```

**Usage in PowerShell:**
```powershell
$addressPrefixArray = "{{NETWORKING_VNET_ADDRESS_SPACE}}".Split(' ')
az network vnet create --address-prefixes @addressPrefixArray ...
```

**Usage in Bash:**
```bash
ADDRESS_SPACE="10.0.0.0/16 10.1.0.0/16"
IFS=' ' read -r -a ADDRESSES <<< "$ADDRESS_SPACE"
az network vnet create --address-prefixes "${ADDRESSES[@]}" ...
```

**Common Use Cases:**
- IP address ranges
- Multiple DNS servers
- List of allowed IPs
- Multiple resource IDs

---

## Placeholder Syntax

### Format

**Pattern:** `{{VARIABLE_NAME}}`

**Rules:**
1. Enclosed in double curly braces
2. Variable name in UPPERCASE
3. Underscores for word separation
4. No spaces inside braces

**Examples:**
```yaml
✓ {{VNET_NAME}}
✓ {{AZURE_RESOURCE_GROUP}}
✓ {{STORAGE_ACCOUNT_NAME}}
✗ {{ VNET_NAME }}  (spaces)
✗ {{vnet_name}}    (lowercase)
✗ {{VNet-Name}}    (hyphen)
```

---

### Substitution Rules

**Rule 1: Placeholders replaced at execution time**
```yaml
# In operation YAML
command: |
  az network vnet create --name "{{NETWORKING_VNET_NAME}}"

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
