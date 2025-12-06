# Networking Capability

## Overview

The Networking capability provides declarative management of Azure network resources including virtual networks, subnets, network security groups, network interfaces, and public IP addresses. This capability is foundational for most Azure deployments.

## Supported Resource Types

- **Virtual Networks (VNets)** (`Microsoft.Network/virtualNetworks`)
  - Address space configuration
  - DNS settings
  - VNET peering

- **Subnets** (`Microsoft.Network/virtualNetworks/subnets`)
  - Address prefixes
  - Service endpoints
  - Delegations
  - Route table associations

- **Network Security Groups (NSGs)** (`Microsoft.Network/networkSecurityGroups`)
  - Inbound and outbound security rules
  - Application security groups
  - Flow logs

- **Network Interfaces (NICs)** (`Microsoft.Network/networkInterfaces`)
  - IP configurations
  - NSG associations
  - Accelerated networking

- **Public IP Addresses** (`Microsoft.Network/publicIPAddresses`)
  - Static and dynamic allocation
  - Standard and Basic SKUs
  - IPv4 and IPv6

- **Route Tables** (`Microsoft.Network/routeTables`)
  - Custom routes
  - Next hop configuration

- **NAT Gateways** (`Microsoft.Network/natGateways`)
  - Outbound connectivity
  - Public IP associations

- **Bastion Hosts** (`Microsoft.Network/bastionHosts`)
  - Secure RDP/SSH access
  - No public IPs required

## Common Operations

The following operations are typically provided by this capability:

1. **vnet-create** - Create virtual networks
2. **vnet-delete** - Remove virtual networks
3. **subnet-create** - Create subnets within VNets
4. **subnet-update** - Modify subnet configuration
5. **nsg-create** - Create network security groups
6. **nsg-rule-add** - Add security rules to NSGs
7. **nic-create** - Create network interfaces
8. **nic-update** - Modify NIC configuration
9. **public-ip-create** - Create public IP addresses
10. **route-table-create** - Create route tables
11. **bastion-create** - Deploy Azure Bastion

## Prerequisites

### Required Permissions

- `Microsoft.Network/virtualNetworks/*`
- `Microsoft.Network/networkSecurityGroups/*`
- `Microsoft.Network/networkInterfaces/*`
- `Microsoft.Network/publicIPAddresses/*`

### Required Providers

```bash
az provider register --namespace Microsoft.Network
```

## Quick Start Examples

### Create a Virtual Network with Subnet

```yaml
operation:
  id: "create-vnet"
  capability: "networking"
  action: "vnet-create"

  inputs:
    vnet_name: "{{ config.vnet_name }}"
    resource_group: "{{ config.resource_group }}"
    location: "{{ config.location }}"
    address_space: "10.0.0.0/16"

    subnets:
      - name: "default"
        address_prefix: "10.0.1.0/24"
      - name: "avd-subnet"
        address_prefix: "10.0.2.0/24"
      - name: "AzureBastionSubnet"
        address_prefix: "10.0.255.0/27"
```

### Create Network Security Group with Rules

```yaml
operation:
  id: "create-nsg"
  capability: "networking"
  action: "nsg-create"

  inputs:
    nsg_name: "{{ config.nsg_name }}"
    resource_group: "{{ config.resource_group }}"
    location: "{{ config.location }}"

    security_rules:
      - name: "AllowRDP"
        priority: 1000
        direction: "Inbound"
        access: "Allow"
        protocol: "Tcp"
        source_address_prefix: "10.0.0.0/16"
        source_port_range: "*"
        destination_address_prefix: "*"
        destination_port_range: "3389"

      - name: "AllowHTTPS"
        priority: 1100
        direction: "Inbound"
        access: "Allow"
        protocol: "Tcp"
        source_address_prefix: "Internet"
        source_port_range: "*"
        destination_address_prefix: "*"
        destination_port_range: "443"
```

### Create Network Interface

```yaml
operation:
  id: "create-nic"
  capability: "networking"
  action: "nic-create"

  inputs:
    nic_name: "{{ config.vm_name }}-nic"
    resource_group: "{{ config.resource_group }}"
    location: "{{ config.location }}"
    vnet_name: "{{ config.vnet_name }}"
    subnet_name: "{{ config.subnet_name }}"
    nsg_id: "{{ outputs.networking.nsg_id }}"

    # Optional: Public IP
    create_public_ip: true
    public_ip_name: "{{ config.vm_name }}-pip"
    public_ip_sku: "Standard"
    public_ip_allocation: "Static"

  outputs:
    nic_id: "{{ outputs.nic_id }}"
    private_ip: "{{ outputs.private_ip }}"
    public_ip: "{{ outputs.public_ip }}"
```

## Configuration Variables

Common configuration variables used by networking operations:

```yaml
networking:
  # Virtual Network
  vnet_name: "vnet-prod-eastus"
  vnet_address_space: "10.0.0.0/16"

  # Subnets
  subnets:
    - name: "default"
      address_prefix: "10.0.1.0/24"
      service_endpoints:
        - "Microsoft.Storage"
        - "Microsoft.KeyVault"

    - name: "avd-subnet"
      address_prefix: "10.0.2.0/24"
      nsg_name: "nsg-avd"

    - name: "AzureBastionSubnet"
      address_prefix: "10.0.255.0/27"

  # Network Security Groups
  default_nsg_rules:
    - name: "DenyAllInbound"
      priority: 4096
      direction: "Inbound"
      access: "Deny"
      protocol: "*"
      source: "*"
      destination: "*"

  # DNS
  dns_servers:
    - "10.0.0.4"
    - "10.0.0.5"

  # Options
  enable_ddos_protection: false
  enable_vm_protection: false
```

## Network Design Best Practices

### Address Space Planning

- **Use RFC 1918 private address spaces**:
  - 10.0.0.0/8
  - 172.16.0.0/12
  - 192.168.0.0/16

- **Plan for growth**: Allocate larger VNET address spaces than immediately needed
- **Avoid overlapping**: Ensure VNETs don't overlap if peering is planned
- **Subnet sizing**: Calculate required IPs (Azure reserves 5 IPs per subnet)

### Security Rules

1. **Default-deny approach**: Deny all by default, allow specific traffic
2. **Use service tags**: Leverage Azure service tags instead of IP ranges
3. **Application Security Groups**: Group resources logically for simplified rules
4. **Rule prioritization**: Lower numbers = higher priority (100-4096)

### High Availability

- **Availability zones**: Deploy resources across zones when possible
- **Redundant connectivity**: Plan for multiple network paths
- **Standard SKU**: Use Standard SKU for production workloads

## Cost Optimization

- **Basic SKU public IPs**: Use Basic SKU for dev/test (free)
- **Minimize cross-region traffic**: Keep resources in same region
- **Remove unused resources**: Delete unused NICs and public IPs
- **NAT Gateway vs Public IPs**: NAT Gateway more cost-effective for many VMs

## Security Best Practices

1. **Network Segmentation**
   - Separate subnets by workload/tier
   - Apply NSGs at subnet level
   - Use service endpoints for Azure services

2. **Just-in-Time Access**
   - Use Azure Bastion for management
   - Implement JIT VM access
   - Avoid persistent public IPs on VMs

3. **Monitoring and Logging**
   - Enable NSG flow logs
   - Configure Traffic Analytics
   - Set up alerts for suspicious activity

4. **DDoS Protection**
   - Enable DDoS Standard for production
   - Configure DDoS response plans

## Troubleshooting

### Common Issues

**Cannot create subnet - address space conflict**
- Verify subnet prefix is within VNET address space
- Check for overlapping subnets
- Ensure proper CIDR notation

**NSG rules not working as expected**
- Check rule priorities (lower = higher priority)
- Verify direction (Inbound vs Outbound)
- Ensure NSG is associated with subnet or NIC
- Review effective security rules in portal

**Public IP not accessible**
- Verify NSG allows inbound traffic
- Check public IP allocation method (Static vs Dynamic)
- Ensure resource is started/running
- Validate SKU compatibility

**NIC creation fails**
- Verify subnet exists and has available IPs
- Check NSG exists if specified
- Ensure VNET and NIC in same region

## Related Documentation

- [Azure Virtual Network Documentation](https://docs.microsoft.com/azure/virtual-network/)
- [Network Security Groups](https://docs.microsoft.com/azure/virtual-network/network-security-groups-overview)
- [Azure Bastion](https://docs.microsoft.com/azure/bastion/bastion-overview)
- [Service Endpoints](https://docs.microsoft.com/azure/virtual-network/virtual-network-service-endpoints-overview)
