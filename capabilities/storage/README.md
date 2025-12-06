# Storage Capability

## Overview

The Storage capability provides declarative management of Azure storage resources including storage accounts, file shares, blob containers, queues, and tables. This capability is essential for data storage, application state, and Azure Virtual Desktop profile management.

## Supported Resource Types

- **Storage Accounts** (`Microsoft.Storage/storageAccounts`)
  - General-purpose v2 (GPv2)
  - Premium block blobs
  - Premium file shares
  - Premium page blobs

- **File Shares** (`Microsoft.Storage/storageAccounts/fileServices/shares`)
  - SMB and NFS protocols
  - Standard and premium tiers
  - Large file share support
  - Access tiers (Transaction optimized, Hot, Cool)

- **Blob Containers** (`Microsoft.Storage/storageAccounts/blobServices/containers`)
  - Block blobs
  - Page blobs
  - Append blobs
  - Access tiers (Hot, Cool, Archive)

- **Queues** (`Microsoft.Storage/storageAccounts/queueServices/queues`)
  - Message storage
  - Asynchronous processing

- **Tables** (`Microsoft.Storage/storageAccounts/tableServices/tables`)
  - NoSQL key-value storage
  - Structured data storage

## Common Operations

The following operations are typically provided by this capability:

1. **storage-account-create** - Create storage accounts
2. **storage-account-delete** - Remove storage accounts
3. **file-share-create** - Create Azure file shares
4. **file-share-update** - Modify file share quota/settings
5. **blob-container-create** - Create blob containers
6. **queue-create** - Create storage queues
7. **table-create** - Create storage tables
8. **set-network-rules** - Configure firewall and network access
9. **enable-soft-delete** - Enable soft delete protection

## Prerequisites

### Required Permissions

- `Microsoft.Storage/storageAccounts/*`
- `Microsoft.Storage/storageAccounts/fileServices/*`
- `Microsoft.Storage/storageAccounts/blobServices/*`

### Required Providers

```bash
az provider register --namespace Microsoft.Storage
```

## Quick Start Examples

### Create Storage Account for AVD Profiles

```yaml
operation:
  id: "create-avd-storage"
  capability: "storage"
  action: "storage-account-create"

  inputs:
    storage_account_name: "{{ config.storage_account_name }}"
    resource_group: "{{ config.resource_group }}"
    location: "{{ config.location }}"
    sku: "Premium_LRS"
    kind: "FileStorage"
    access_tier: "Premium"

    # Network security
    allow_public_access: false
    default_action: "Deny"
    bypass: "AzureServices"

    # Enable features
    enable_https_traffic_only: true
    minimum_tls_version: "TLS1_2"
    enable_large_file_share: true

  outputs:
    storage_account_id: "{{ outputs.storage_account_id }}"
    primary_endpoint: "{{ outputs.primary_endpoint }}"
```

### Create File Share for FSLogix Profiles

```yaml
operation:
  id: "create-profile-share"
  capability: "storage"
  action: "file-share-create"

  inputs:
    storage_account_name: "{{ config.storage_account_name }}"
    resource_group: "{{ config.resource_group }}"
    share_name: "profiles"
    quota_gb: 1024
    access_tier: "Premium"

    # Enable backup
    enable_backup: true
    backup_policy: "DailyBackup"

  outputs:
    share_name: "{{ outputs.share_name }}"
    share_url: "{{ outputs.share_url }}"
```

### Create General Purpose Storage Account

```yaml
operation:
  id: "create-general-storage"
  capability: "storage"
  action: "storage-account-create"

  inputs:
    storage_account_name: "{{ config.storage_account_name }}"
    resource_group: "{{ config.resource_group }}"
    location: "{{ config.location }}"
    sku: "Standard_GRS"
    kind: "StorageV2"
    access_tier: "Hot"

    # Redundancy
    enable_geo_redundancy: true

    # Soft delete
    enable_blob_soft_delete: true
    blob_soft_delete_retention_days: 7
    enable_container_soft_delete: true
    container_soft_delete_retention_days: 7

    # Versioning
    enable_blob_versioning: true
```

### Configure Network Rules

```yaml
operation:
  id: "configure-storage-network"
  capability: "storage"
  action: "set-network-rules"

  inputs:
    storage_account_name: "{{ config.storage_account_name }}"
    resource_group: "{{ config.resource_group }}"

    default_action: "Deny"
    bypass: "AzureServices"

    # Allow specific VNETs
    virtual_network_rules:
      - vnet_name: "{{ config.vnet_name }}"
        subnet_name: "avd-subnet"

    # Allow specific IPs
    ip_rules:
      - "203.0.113.0/24"
```

## Configuration Variables

Common configuration variables used by storage operations:

```yaml
storage:
  # Storage Account
  storage_account_name: "stavdprod001"  # Must be globally unique
  sku: "Premium_LRS"                     # Standard_LRS, Standard_GRS, Premium_LRS
  kind: "FileStorage"                    # StorageV2, FileStorage, BlockBlobStorage
  access_tier: "Premium"                 # Hot, Cool, Premium

  # File Shares
  file_shares:
    - name: "profiles"
      quota_gb: 1024
      access_tier: "Premium"
      enabled_protocols: "SMB"

    - name: "msix"
      quota_gb: 512
      access_tier: "Premium"
      enabled_protocols: "SMB"

  # Security
  allow_public_access: false
  enable_https_traffic_only: true
  minimum_tls_version: "TLS1_2"

  # Network Rules
  network_rules:
    default_action: "Deny"
    bypass: "AzureServices"
    allowed_subnets:
      - "avd-subnet"
      - "management-subnet"

  # Data Protection
  enable_soft_delete: true
  soft_delete_retention_days: 7
  enable_versioning: true

  # Backup
  enable_backup: true
  backup_vault: "vault-prod"
  backup_policy: "DailyBackup"
```

## SKU Selection Guide

### Standard Storage Accounts

| SKU | Redundancy | Use Case | Cost |
|-----|-----------|----------|------|
| Standard_LRS | Local | Dev/test, non-critical data | Lowest |
| Standard_ZRS | Zone | Production, HA within region | Low |
| Standard_GRS | Geo | Business continuity, DR | Medium |
| Standard_GZRS | Geo-Zone | Mission-critical, highest availability | High |

### Premium Storage Accounts

| Kind | Performance | Use Case | Protocol |
|------|------------|----------|----------|
| FileStorage | High IOPS/throughput | FSLogix profiles, shared data | SMB, NFS |
| BlockBlobStorage | Low latency | Analytics, fast data access | Blob |
| PageBlobStorage | Consistent low latency | VHDs, databases | Page blob |

## AVD Storage Best Practices

### FSLogix Profile Containers

1. **Use Premium File Shares**
   - Required for production AVD deployments
   - Low latency for user profile access
   - Consistent IOPS and throughput

2. **Size Appropriately**
   - Calculate: (Number of users × Average profile size) × 1.2
   - Minimum 100 GB per share
   - Monitor usage and adjust quota

3. **Enable Backup**
   - Configure Azure Backup for file shares
   - Daily backups with 30-day retention minimum
   - Test restore procedures

4. **Security Configuration**
   - Disable public access
   - Configure VNET service endpoints or private endpoints
   - Use AD DS or Entra DS integration

### MSIX App Attach

- **Separate share** from profile containers
- **Premium tier** recommended
- **Appropriate quota** based on number of MSIX packages
- **Read-only** access for session hosts

## Cost Optimization

1. **Right-size Storage**
   - Start with minimum required capacity
   - Monitor usage and scale up as needed
   - Use Standard tier for dev/test

2. **Choose Appropriate Redundancy**
   - LRS for non-critical data
   - GRS only when geo-redundancy required
   - Consider cost vs. availability requirements

3. **Lifecycle Management**
   - Move cool data to Cool tier
   - Archive infrequently accessed data
   - Delete old snapshots and versions

4. **Reserved Capacity**
   - Purchase reserved capacity for production
   - 1 or 3-year commitments save 15-38%

## Security Best Practices

1. **Network Isolation**
   - Disable public blob access
   - Use private endpoints for production
   - Configure VNET service endpoints
   - Implement firewall rules

2. **Authentication**
   - Use Entra ID (AAD) authentication when possible
   - Implement managed identities
   - Rotate storage account keys regularly
   - Use SAS tokens with minimal permissions and expiry

3. **Encryption**
   - Storage encryption enabled by default
   - Consider customer-managed keys for compliance
   - Enable infrastructure encryption for sensitive data

4. **Data Protection**
   - Enable soft delete (7-30 days retention)
   - Enable blob versioning
   - Configure immutable storage policies for compliance
   - Regular backup testing

5. **Monitoring**
   - Enable Storage Analytics logging
   - Configure alerts for suspicious activity
   - Monitor capacity and performance metrics
   - Regular access reviews

## Troubleshooting

### Common Issues

**Storage account name already exists**
- Storage account names are globally unique
- Use combination of company/project/environment/region
- Check for deleted accounts (may take time to fully delete)

**Cannot access file share from VM**
- Verify network connectivity (port 445 for SMB)
- Check NSG rules allow outbound 445
- Verify firewall/network rules on storage account
- Ensure VM is in allowed VNET/subnet

**Poor performance with Standard tier**
- Premium tier required for AVD profiles
- Consider IOPS/throughput limits of Standard
- Check for throttling in metrics
- Upgrade to Premium FileStorage

**Authentication failures**
- Verify AD DS or Entra DS domain join
- Check storage account key rotation
- Validate SAS token expiry and permissions
- Review RBAC role assignments

## Monitoring Metrics

Key metrics to monitor:

- **Capacity**: Total storage used vs. quota
- **Transactions**: Request count and types
- **Availability**: Service uptime percentage
- **Latency**: E2E latency and server latency
- **Throughput**: Ingress and egress bytes

## Related Documentation

- [Azure Storage Documentation](https://docs.microsoft.com/azure/storage/)
- [Azure Files Planning](https://docs.microsoft.com/azure/storage/files/storage-files-planning)
- [FSLogix with Azure Files](https://docs.microsoft.com/fslogix/configure-cloud-cache-tutorial)
- [Storage Security Guide](https://docs.microsoft.com/azure/storage/common/storage-security-guide)
