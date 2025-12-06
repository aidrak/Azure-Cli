# Azure Virtual Desktop (AVD) Capability

## Overview

The AVD capability provides declarative management of Azure Virtual Desktop infrastructure including host pools, application groups, workspaces, session hosts, and scaling plans. This capability orchestrates the complex dependencies between compute, networking, storage, and identity resources required for a complete AVD deployment.

## Supported Resource Types

- **Host Pools** (`Microsoft.DesktopVirtualization/hostpools`)
  - Pooled (multi-session) host pools
  - Personal (dedicated) host pools
  - Load balancing configuration
  - RDP properties

- **Application Groups** (`Microsoft.DesktopVirtualization/applicationgroups`)
  - Desktop application groups
  - RemoteApp application groups
  - Application assignments

- **Workspaces** (`Microsoft.DesktopVirtualization/workspaces`)
  - User-facing workspace portals
  - Application group associations
  - Friendly names

- **Session Hosts** (`Microsoft.DesktopVirtualization/hostpools/sessionhosts`)
  - VM-based session hosts
  - Agent registration
  - Drain mode configuration

- **Scaling Plans** (`Microsoft.DesktopVirtualization/scalingplans`)
  - Autoscale schedules
  - Peak/off-peak hours
  - Cost optimization

## Common Operations

The following operations are typically provided by this capability:

1. **hostpool-create** - Create AVD host pool
2. **hostpool-delete** - Remove host pool
3. **appgroup-create** - Create application group
4. **workspace-create** - Create workspace
5. **sessionhost-add** - Add VMs as session hosts
6. **sessionhost-remove** - Remove session hosts
7. **app-publish** - Publish RemoteApp applications
8. **scaling-plan-create** - Configure autoscale
9. **registration-token-refresh** - Renew host pool registration token

## Prerequisites

### Required Capabilities

All four foundational capabilities are required for AVD:

- **compute** - Session host VMs
- **networking** - Virtual networks and connectivity
- **storage** - FSLogix profile storage
- **identity** - User groups and RBAC

### Required Permissions

- `Microsoft.DesktopVirtualization/*`
- `Microsoft.Compute/virtualMachines/*`
- `Microsoft.Network/*`
- `Microsoft.Storage/storageAccounts/*`
- `Microsoft.Authorization/roleAssignments/write`

### Required Providers

```bash
az provider register --namespace Microsoft.DesktopVirtualization
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Storage
```

### Active Directory Requirements

- **AD DS Domain** or **Entra Domain Services** available
- Session hosts must be domain-joined
- FSLogix storage must have AD integration (for Kerberos)

## Quick Start Examples

### Create Pooled Host Pool

```yaml
operation:
  id: "create-pooled-hostpool"
  capability: "avd"
  action: "hostpool-create"

  inputs:
    hostpool_name: "{{ config.hostpool_name }}"
    resource_group: "{{ config.resource_group }}"
    location: "{{ config.location }}"

    # Host pool configuration
    host_pool_type: "Pooled"
    load_balancer_type: "BreadthFirst"
    max_session_limit: 10

    # Registration
    registration_token_expiration_hours: 24

    # RDP Properties
    rdp_properties:
      audiocapturemode: "1"
      audiomode: "0"
      camerastoredirect: "*"
      redirectclipboard: "1"
      redirectprinters: "1"
      drivestoredirect: "*"

    # Validation
    validation_environment: false

  outputs:
    hostpool_id: "{{ outputs.hostpool_id }}"
    registration_token: "{{ outputs.registration_token }}"
```

### Create Desktop Application Group

```yaml
operation:
  id: "create-desktop-appgroup"
  capability: "avd"
  action: "appgroup-create"

  inputs:
    appgroup_name: "{{ config.appgroup_name }}"
    resource_group: "{{ config.resource_group }}"
    location: "{{ config.location }}"

    hostpool_id: "{{ outputs.hostpool.hostpool_id }}"
    application_group_type: "Desktop"
    friendly_name: "Production Desktop"
    description: "Full desktop access for production users"

  outputs:
    appgroup_id: "{{ outputs.appgroup_id }}"
```

### Create Workspace

```yaml
operation:
  id: "create-workspace"
  capability: "avd"
  action: "workspace-create"

  inputs:
    workspace_name: "{{ config.workspace_name }}"
    resource_group: "{{ config.resource_group }}"
    location: "{{ config.location }}"

    friendly_name: "Production Workspace"
    description: "Production AVD environment"

    # Associate application groups
    application_group_references:
      - "{{ outputs.desktop_appgroup.appgroup_id }}"
      - "{{ outputs.remoteapp_appgroup.appgroup_id }}"

  outputs:
    workspace_id: "{{ outputs.workspace_id }}"
```

### Add Session Hosts

```yaml
operation:
  id: "add-session-hosts"
  capability: "avd"
  action: "sessionhost-add"

  inputs:
    hostpool_name: "{{ config.hostpool_name }}"
    resource_group: "{{ config.resource_group }}"

    # VM configuration
    vm_count: 3
    vm_name_prefix: "avd-sh"
    vm_size: "Standard_D4s_v5"
    vm_image: "win11-23h2-avd"

    # Networking
    vnet_name: "{{ config.vnet_name }}"
    subnet_name: "{{ config.subnet_name }}"

    # Domain join
    domain_join: true
    domain_name: "{{ config.domain_name }}"
    domain_admin_username: "{{ config.domain_admin }}"
    domain_admin_password: "{{ config.domain_password }}"
    ou_path: "{{ config.ou_path }}"

    # AVD registration
    registration_token: "{{ outputs.hostpool.registration_token }}"

    # FSLogix configuration
    fslogix_storage_account: "{{ config.storage_account }}"
    fslogix_file_share: "profiles"

  outputs:
    session_host_names: "{{ outputs.session_host_names }}"
    session_host_ids: "{{ outputs.session_host_ids }}"
```

### Create Scaling Plan

```yaml
operation:
  id: "create-scaling-plan"
  capability: "avd"
  action: "scaling-plan-create"

  inputs:
    scaling_plan_name: "{{ config.scaling_plan_name }}"
    resource_group: "{{ config.resource_group }}"
    location: "{{ config.location }}"

    time_zone: "Eastern Standard Time"
    hostpool_id: "{{ outputs.hostpool.hostpool_id }}"

    schedules:
      # Monday-Friday
      - days_of_week: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]

        ramp_up_start_time: "07:00"
        ramp_up_load_balancing_algorithm: "BreadthFirst"
        ramp_up_minimum_hosts_percent: 20
        ramp_up_capacity_threshold_percent: 60

        peak_start_time: "09:00"
        peak_load_balancing_algorithm: "DepthFirst"

        ramp_down_start_time: "18:00"
        ramp_down_load_balancing_algorithm: "DepthFirst"
        ramp_down_minimum_hosts_percent: 10
        ramp_down_capacity_threshold_percent: 90
        ramp_down_force_logoff_users: false
        ramp_down_wait_time_minutes: 30
        ramp_down_notification_message: "Please save your work. Session will end in 30 minutes."

        off_peak_start_time: "20:00"
        off_peak_load_balancing_algorithm: "DepthFirst"

      # Weekend
      - days_of_week: ["Saturday", "Sunday"]
        ramp_up_start_time: "09:00"
        peak_start_time: "10:00"
        ramp_down_start_time: "16:00"
        off_peak_start_time: "18:00"
```

### Publish RemoteApp

```yaml
operation:
  id: "publish-excel"
  capability: "avd"
  action: "app-publish"

  inputs:
    appgroup_id: "{{ outputs.remoteapp_appgroup.appgroup_id }}"
    resource_group: "{{ config.resource_group }}"

    application_name: "Microsoft Excel"
    application_type: "InBuilt"
    file_path: "C:\\Program Files\\Microsoft Office\\root\\Office16\\EXCEL.EXE"
    command_line_arguments: ""
    show_in_portal: true
    icon_path: "C:\\Program Files\\Microsoft Office\\root\\Office16\\EXCEL.EXE"
    icon_index: 0
```

## Configuration Variables

Comprehensive AVD configuration example:

```yaml
avd:
  # Host Pool Configuration
  hostpool:
    name: "hp-prod-eastus"
    type: "Pooled"                    # Pooled or Personal
    load_balancer_type: "BreadthFirst" # BreadthFirst or DepthFirst
    max_session_limit: 10
    validation_environment: false
    start_vm_on_connect: true
    registration_token_hours: 24

  # Application Groups
  application_groups:
    - name: "ag-desktop-prod"
      type: "Desktop"
      friendly_name: "Production Desktop"

    - name: "ag-remoteapp-prod"
      type: "RemoteApp"
      friendly_name: "Production Applications"
      applications:
        - name: "Microsoft Excel"
          path: "C:\\Program Files\\Microsoft Office\\root\\Office16\\EXCEL.EXE"
        - name: "Microsoft Word"
          path: "C:\\Program Files\\Microsoft Office\\root\\Office16\\WINWORD.EXE"

  # Workspace
  workspace:
    name: "ws-prod-eastus"
    friendly_name: "Production Workspace"
    description: "Production environment for all users"

  # Session Hosts
  session_hosts:
    vm_name_prefix: "avd-sh"
    vm_count: 5
    vm_size: "Standard_D4s_v5"
    vm_image:
      publisher: "MicrosoftWindowsDesktop"
      offer: "office-365"
      sku: "win11-23h2-avd-m365"
      version: "latest"

    os_disk:
      size_gb: 127
      storage_account_type: "Premium_LRS"

  # Domain Configuration
  domain:
    domain_name: "contoso.local"
    ou_path: "OU=AVD,OU=Computers,DC=contoso,DC=local"
    domain_admin_username: "domainadmin"

  # FSLogix Configuration
  fslogix:
    storage_account: "stavdprod001"
    file_share: "profiles"
    vhd_location: "\\\\stavdprod001.file.core.windows.net\\profiles"
    vhd_size_gb: 30
    enable_cloud_cache: false

  # RDP Properties
  rdp_properties:
    audiocapturemode: "1"              # Enable audio capture
    audiomode: "0"                     # Play audio on client
    camerastoredirect: "*"             # Redirect all cameras
    redirectclipboard: "1"             # Enable clipboard
    redirectprinters: "1"              # Redirect printers
    drivestoredirect: "*"              # Redirect drives
    redirectsmartcards: "1"            # Redirect smart cards
    usbdevicestoredirect: "*"          # Redirect USB devices
    enablecredsspsupport: "1"          # Enable CredSSP
    use_multimon: "1"                  # Multiple monitors
    videoplaybackmode: "1"             # Enable hardware acceleration

  # Scaling Configuration
  scaling:
    enabled: true
    time_zone: "Eastern Standard Time"

    weekday_schedule:
      ramp_up_start: "07:00"
      ramp_up_min_hosts_pct: 20
      ramp_up_capacity_threshold_pct: 60

      peak_start: "09:00"
      peak_load_balancing: "DepthFirst"

      ramp_down_start: "18:00"
      ramp_down_min_hosts_pct: 10
      ramp_down_wait_time_min: 30
      ramp_down_force_logoff: false

      off_peak_start: "20:00"

  # Monitoring
  diagnostics:
    enabled: true
    log_analytics_workspace_id: "{{ config.log_analytics_workspace_id }}"
    categories:
      - "Checkpoint"
      - "Error"
      - "Management"
      - "Connection"
      - "HostRegistration"
```

## Architecture Patterns

### Pattern 1: Pooled Multi-Session (Most Common)

**Use Case:** General office workers, task workers
**Configuration:**
- Windows 10/11 Multi-session
- BreadthFirst load balancing
- 5-15 users per session host
- Autoscaling enabled

**Benefits:**
- Most cost-effective
- Efficient resource utilization
- Easy to scale

### Pattern 2: Personal Desktops

**Use Case:** Developers, power users, regulatory requirements
**Configuration:**
- Windows 10/11 Enterprise
- One user per VM
- Persistent desktops
- Larger VM sizes

**Benefits:**
- Full personalization
- Admin rights possible
- Application compatibility

### Pattern 3: Hybrid Deployment

**Use Case:** Mixed user workload profiles
**Configuration:**
- Multiple host pools
- Pooled for task workers
- Personal for power users
- Single workspace

**Benefits:**
- Optimized cost per user type
- Flexibility
- Single user experience

## Performance Sizing Guide

### VM Size Recommendations

| User Profile | vCPU | RAM | VM Size | Max Users |
|-------------|------|-----|---------|-----------|
| Light (Office) | 4 | 16 GB | D4s_v5 | 10-12 |
| Medium (Office + Browser) | 8 | 32 GB | D8s_v5 | 8-10 |
| Heavy (Graphics, Engineering) | 16 | 64 GB | D16s_v5 | 4-6 |
| GPU (CAD, 3D) | 6 | 56 GB | NV6 | 1-2 |

### Storage Performance

**FSLogix Profiles:**
- **Premium Files** required for production
- Minimum 100 GB share size
- Plan for 30 GB per user average
- IOPS scales with share size

## Cost Optimization

### Compute Costs

1. **Autoscaling**
   - Configure ramp-up/ramp-down schedules
   - Deallocate VMs during off-hours
   - 50-70% cost savings possible

2. **Right-Sizing**
   - Start with smaller VM sizes
   - Monitor utilization metrics
   - Scale up only if needed

3. **Reserved Instances**
   - 1-year or 3-year commitments
   - Up to 72% savings vs pay-as-you-go
   - Recommended for baseline capacity

4. **Azure Hybrid Benefit**
   - Use existing Windows licenses
   - Significant license cost savings
   - Requires Software Assurance

### Storage Costs

- Premium storage required but expensive
- Plan capacity carefully (can't shrink shares)
- Use lifecycle management for old data
- Monitor quota utilization

## Security Best Practices

### Network Security

1. **Network Isolation**
   - Dedicated subnet for session hosts
   - NSG rules restricting traffic
   - No public IPs on session hosts
   - Azure Bastion for admin access

2. **Conditional Access**
   - MFA enforcement
   - Device compliance checks
   - Location-based access
   - Risk-based policies

### Data Protection

1. **FSLogix Security**
   - Encryption in transit (SMB 3.1.1)
   - Encryption at rest (Azure Storage)
   - RBAC for storage access
   - Private endpoints

2. **Session Host Security**
   - Antimalware enabled
   - Disk encryption
   - Patch management
   - Security baselines

### Monitoring and Compliance

- Azure Monitor for AVD insights
- Log Analytics integration
- Security Center recommendations
- Compliance auditing

## Troubleshooting

### Common Issues

**Session hosts not registering**
- Verify registration token not expired
- Check network connectivity to AVD control plane
- Ensure AVD agent installed correctly
- Verify domain join successful

**Users cannot connect**
- Check RBAC assignment on application group
- Verify workspace contains application group
- Ensure session hosts are available and healthy
- Review NSG rules and firewall

**Poor performance**
- Check CPU/memory utilization on session hosts
- Verify storage performance (Premium vs Standard)
- Review RDP properties (disable features if needed)
- Check network latency between user and session host

**FSLogix profile issues**
- Verify storage account accessible from session hosts
- Check RBAC permissions on file share
- Ensure FSLogix services running
- Review FSLogix logs in session host

**Autoscaling not working**
- Verify scaling plan associated with host pool
- Check time zone configuration
- Ensure sufficient permissions for scaling plan
- Review scaling plan execution logs

## Monitoring Metrics

### Host Pool Metrics

- Available sessions
- Active sessions
- Connection success rate
- User input delay

### Session Host Metrics

- CPU percentage
- Available memory
- Disk queue length
- Network in/out

### Storage Metrics

- File share capacity
- IOPS consumption
- Transactions
- Latency

## Related Documentation

- [Azure Virtual Desktop Documentation](https://docs.microsoft.com/azure/virtual-desktop/)
- [FSLogix Documentation](https://docs.microsoft.com/fslogix/)
- [AVD Sizing Guidance](https://docs.microsoft.com/azure/virtual-desktop/remote-app-streaming/sizing-guidance)
- [AVD Network Connectivity](https://docs.microsoft.com/azure/virtual-desktop/network-connectivity)
- [Autoscale Documentation](https://docs.microsoft.com/azure/virtual-desktop/autoscale-scaling-plan)
