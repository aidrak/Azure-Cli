# Compute Capability

## Overview

The Compute capability provides declarative management of Azure compute resources including virtual machines, disks, availability sets, and images. This capability handles the full lifecycle of compute resources from provisioning to decommissioning.

## Supported Resource Types

- **Virtual Machines** (`Microsoft.Compute/virtualMachines`)
  - Windows and Linux VMs
  - Multiple VM sizes and series
  - Custom and marketplace images
  - Availability zone support

- **Disks** (`Microsoft.Compute/disks`)
  - OS disks
  - Data disks
  - Premium SSD, Standard SSD, Standard HDD
  - Disk encryption

- **Availability Sets** (`Microsoft.Compute/availabilitySets`)
  - Fault domain and update domain configuration
  - High availability for VM groups

- **Images** (`Microsoft.Compute/images`)
  - Custom VM images
  - Generalized and specialized images

- **Snapshots** (`Microsoft.Compute/snapshots`)
  - Disk backup and recovery
  - Point-in-time disk copies

- **Galleries** (`Microsoft.Compute/galleries`)
  - Shared image galleries
  - Image versioning and replication

## Common Operations

The following operations are typically provided by this capability:

1. **vm-create** - Create and configure virtual machines
2. **vm-delete** - Remove virtual machines
3. **vm-resize** - Change VM size/SKU
4. **vm-start** - Start stopped VMs
5. **vm-stop** - Stop running VMs
6. **disk-attach** - Attach data disks to VMs
7. **disk-detach** - Detach data disks from VMs
8. **snapshot-create** - Create disk snapshots
9. **image-capture** - Capture VM as custom image

## Prerequisites

### Required Capabilities

- **networking** - VMs require network interfaces, subnets, and virtual networks
- **identity** (optional) - For managed identity assignment
- **storage** (optional) - For boot diagnostics and custom images

### Required Permissions

- `Microsoft.Compute/virtualMachines/*`
- `Microsoft.Compute/disks/*`
- `Microsoft.Compute/availabilitySets/*`
- `Microsoft.Network/networkInterfaces/read`
- `Microsoft.Network/networkInterfaces/write`

### Required Providers

```bash
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Network
```

## Quick Start Examples

### Create a Windows VM

```yaml
operation:
  id: "create-win-vm"
  capability: "compute"
  action: "vm-create"

  inputs:
    vm_name: "{{ config.vm_name }}"
    resource_group: "{{ config.resource_group }}"
    location: "{{ config.location }}"
    vm_size: "Standard_D4s_v3"
    image: "Win2022Datacenter"
    admin_username: "{{ config.admin_username }}"
    admin_password: "{{ config.admin_password }}"
    network_interface_id: "{{ outputs.networking.nic_id }}"
```

### Create a Linux VM with Managed Identity

```yaml
operation:
  id: "create-linux-vm"
  capability: "compute"
  action: "vm-create"

  inputs:
    vm_name: "{{ config.vm_name }}"
    resource_group: "{{ config.resource_group }}"
    location: "{{ config.location }}"
    vm_size: "Standard_B2s"
    image: "UbuntuLTS"
    admin_username: "{{ config.admin_username }}"
    ssh_key_value: "{{ config.ssh_public_key }}"
    network_interface_id: "{{ outputs.networking.nic_id }}"
    assign_identity: true
    identity_type: "SystemAssigned"
```

### Attach a Data Disk

```yaml
operation:
  id: "attach-data-disk"
  capability: "compute"
  action: "disk-attach"

  inputs:
    vm_name: "{{ config.vm_name }}"
    resource_group: "{{ config.resource_group }}"
    disk_name: "{{ config.vm_name }}-data-disk-01"
    disk_size_gb: 128
    disk_sku: "Premium_LRS"
    lun: 0
```

## Configuration Variables

Common configuration variables used by compute operations:

```yaml
compute:
  vm_size: "Standard_D4s_v3"
  image_publisher: "MicrosoftWindowsServer"
  image_offer: "WindowsServer"
  image_sku: "2022-datacenter"
  os_disk_size_gb: 127
  os_disk_sku: "Premium_LRS"
  admin_username: "azureuser"

  # Optional: Data disks
  data_disks:
    - name: "data-disk-01"
      size_gb: 256
      sku: "Premium_LRS"
      lun: 0
    - name: "data-disk-02"
      size_gb: 512
      sku: "Premium_LRS"
      lun: 1

  # Optional: Availability
  availability_set: "avset-prod"
  availability_zone: "1"

  # Optional: Managed Identity
  enable_managed_identity: true
  identity_type: "SystemAssigned"
```

## Cost Optimization

- **Right-size VMs** - Use appropriate VM sizes for workload requirements
- **Stop deallocated VMs** - Shutdown VMs when not in use to avoid compute charges
- **Use Standard disks** - Where performance allows, use Standard SSD/HDD instead of Premium
- **Reserved instances** - For long-term workloads, consider reserved VM instances
- **Spot instances** - For fault-tolerant workloads, use Azure Spot VMs

## Troubleshooting

### Common Issues

**VM creation fails with "QuotaExceeded"**
- Check subscription quota limits for the region
- Request quota increase through Azure Portal

**VM cannot access network resources**
- Verify NSG rules allow required traffic
- Check route table configuration
- Validate subnet configuration

**Disk attachment fails**
- Verify VM is stopped (deallocated)
- Check that LUN number is not already in use
- Ensure disk is in same region as VM

## Related Documentation

- [Azure Virtual Machines Documentation](https://docs.microsoft.com/azure/virtual-machines/)
- [VM Sizes and Pricing](https://azure.microsoft.com/pricing/details/virtual-machines/)
- [Managed Disks Overview](https://docs.microsoft.com/azure/virtual-machines/managed-disks-overview)
