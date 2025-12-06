# Capability Domains

**Complete breakdown of all 7 capability domains and their 85 operations**

## Table of Contents

1. [Overview](#overview)
2. [Networking (23 operations)](#networking-23-operations)
3. [Storage (9 operations)](#storage-9-operations)
4. [Identity (18 operations)](#identity-18-operations)
5. [Compute (17 operations)](#compute-17-operations)
6. [AVD (15 operations)](#avd-15-operations)
7. [Management (2 operations)](#management-2-operations)
8. [Test Capability (1 operation)](#test-capability-1-operation)

---

## Overview

Seven capability domains organize all Azure operations:

| Capability | Operations | Description | Key Operations |
|-----------|------------|-------------|-----------------|
| **networking** | 23 | Virtual networks, subnets, NSGs, DNS, VPN, peering | vnet-create, nsg-create, vpn-gateway-create |
| **storage** | 9 | Storage accounts, file shares, blobs, private endpoints | account-create, fileshare-create, private-endpoint-create |
| **identity** | 18 | Entra ID groups, RBAC, service principals, SSO | group-create, rbac-assign, service-principal-create |
| **compute** | 17 | VMs, disks, images, golden image preparation | vm-create, image-create, golden-image-install-* |
| **avd** | 15 | Host pools, workspaces, app groups, autoscaling | hostpool-create, appgroup-create, scaling-plan-create |
| **management** | 2 | Resource groups, validation | resource-group-create, resource-group-validate |
| **test-capability** | 1 | Testing framework | test-operation |

**Total: 85 operations**

---

## Networking (23 operations)

Core network infrastructure for Azure deployments.

### Core Resources

**Virtual Networks and Subnets:**
- `vnet-create` - Create virtual network with address space
- `vnet-adopt` - Adopt existing virtual network
- `vnet-peering-create` - Create VNet peering connections
- `subnet-create` - Create subnet within VNet
- `gateway-subnet-create` - Create gateway subnet for VPN

**Network Security:**
- `nsg-create` - Create network security group
- `nsg-attach` - Attach NSG to subnet
- `nsg-rule-add` - Add security rules to NSG

**Public Connectivity:**
- `public-ip-create` - Create public IP address
- `load-balancer-create` - Create load balancer

**DNS and Routing:**
- `dns-zone-create` - Create DNS zone
- `dns-zone-link` - Link DNS zone to VNet
- `route-table-create` - Create route table
- `route-table-configure` - Configure routing rules

**VPN and Gateways:**
- `vpn-gateway-create` - Create VPN gateway
- `vpn-connection-create` - Create VPN connection
- `local-network-gateway-create` - Create local network gateway

**Advanced Features:**
- `service-endpoint-configure` - Configure service endpoints
- `networking-validate` - Validate network configuration

### Resource Relationships

```
VNet
  ├─ Subnets
  │   ├─ NSG (attached)
  │   └─ Route Table (attached)
  ├─ DNS Zones (linked)
  ├─ VNet Peering
  └─ VPN Gateway
      └─ VPN Connections
          └─ Local Network Gateway
```

### Typical Usage Patterns

**Basic Network Setup:**
1. `vnet-create` - Create virtual network
2. `subnet-create` - Create application subnet
3. `nsg-create` - Create network security group
4. `nsg-attach` - Attach NSG to subnet

**Advanced Network Setup:**
1. `vnet-create` - Create hub VNet
2. `vpn-gateway-create` - Create VPN gateway
3. `vnet-peering-create` - Peer with spoke VNets
4. `dns-zone-create` - Create private DNS zone
5. `dns-zone-link` - Link DNS to VNets

---

## Storage (9 operations)

Persistent storage and file sharing infrastructure.

### Core Resources

**Storage Accounts:**
- `account-create` - Create storage account (Premium FileStorage)
- `account-configure` - Configure storage account settings
- `account-delete` - Delete storage account

**File and Blob Storage:**
- `fileshare-create` - Create Azure file share
- `blob-container-create` - Create blob container

**Security and Networking:**
- `private-endpoint-create` - Create private endpoint for storage
- `public-access-disable` - Disable public blob access
- `private-dns-zone-create` - Create private DNS zone for storage
- `private-links-validate` - Validate private link configuration

### Resource Relationships

```
Storage Account
  ├─ File Shares (FSLogix profiles)
  ├─ Blob Containers
  ├─ Private Endpoint
  │   └─ Private DNS Zone
  └─ RBAC Assignments
```

### Typical Usage Patterns

**FSLogix Storage Setup:**
1. `account-create` - Create Premium_LRS FileStorage account
2. `fileshare-create` - Create profile share
3. `private-endpoint-create` - Create private endpoint
4. `private-dns-zone-create` - Create DNS zone for privatelink
5. `public-access-disable` - Ensure no public access

**Secure Storage:**
1. `account-create` - Create storage account
2. `private-endpoint-create` - Connect to VNet
3. `public-access-disable` - Block public access
4. `private-links-validate` - Verify configuration

---

## Identity (18 operations)

Azure Entra ID (formerly Azure AD) and access control.

### Core Resources

**Group Management:**
- `group-create` - Create Entra ID security group
- `group-delete` - Delete Entra ID group
- `group-member-add` - Add members to group
- `fslogix-group-create` - Create FSLogix-specific group
- `network-group-create` - Create network admin group
- `security-group-create` - Create security group

**Service Principals and Identities:**
- `service-principal-create` - Create service principal
- `managed-identity-create` - Create managed identity
- `sso-service-principal-configure` - Configure SSO service principal

**RBAC Assignments:**
- `rbac-assign` - General RBAC role assignment
- `storage-rbac-assign` - Assign storage-specific roles
- `vm-login-rbac-assign` - Assign VM login roles
- `appgroup-rbac-assign` - Assign AVD app group roles

**Validation:**
- `groups-validate` - Validate group configuration
- `rbac-assignments-verify` - Verify RBAC assignments

### Resource Relationships

```
Entra ID Groups
  ├─ Group Members (users)
  └─ RBAC Assignments
      ├─ Storage Account Roles
      ├─ VM Login Roles
      └─ AVD App Group Assignments

Service Principals
  └─ RBAC Assignments
```

### Typical Usage Patterns

**User Access Setup:**
1. `group-create` - Create AVD Users group
2. `group-member-add` - Add users to group
3. `appgroup-rbac-assign` - Assign group to AVD app group
4. `vm-login-rbac-assign` - Grant VM login permissions

**Service Identity Setup:**
1. `managed-identity-create` - Create managed identity
2. `rbac-assign` - Assign necessary permissions
3. `rbac-assignments-verify` - Validate configuration

---

## Compute (17 operations)

Virtual machines and image management.

### Core Resources

**Virtual Machines:**
- `vm-create` - Create virtual machine
- `vm-configure` - Configure VM settings
- `vm-validate` - Validate VM configuration
- `vm-start` - Start virtual machine
- `vm-extension-add` - Add VM extension

**Disks and Storage:**
- `disk-create` - Create managed disk
