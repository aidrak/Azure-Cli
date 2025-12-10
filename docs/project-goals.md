# Azure AVD POC Project Scope

## Project Overview
Setting up a production-like Azure Virtual Desktop (AVD) proof of concept to support 400 simultaneous users across 14 branch offices accessing 150 Access databases. This POC is designed to mimic production deployment for client evaluation before full rollout.

**Environment:** Azure-only deployment with $200 free credit  
**My Experience Level:** New to Azure and AVD  
**Client Migration Goal:** Eventually migrate from Access databases to Azure SQL

**1 Golden Image (Shared Pool). 1 File Server with Premium Storage**
---

## Network Architecture

**vnet-avd** (Single VNet Architecture)
- **Purpose:** Consolidated network for all AVD infrastructure
- **Address Space:** TBD
- **Subnets:**
  - snet-sessionhosts: AVD session host VMs
  - snet-fileserver: File Server VM for Access databases
  - snet-privateendpoints: Private endpoints for Azure Files (FSLogix)
  - snet-azurebackup: Azure Backup infrastructure (if required - TBD)

**Network Security:**
- NSGs applied to each subnet
- Inbound access restricted to branch office public IPs only
- Branch office public IP allowlist: TBD (14 locations)
- Service tags and application security groups: TBD

**Recommended NSG Strategy:**
- Create IP Group resource containing all 14 branch public IPs (162.120.185.201 for testing but use group and add that to group)
- Reference IP Group in NSG rules for centralized management
- Allow RDP/HTTPS from IP Group to snet-sessionhosts
- Allow SMB from snet-sessionhosts to snet-fileserver and snet-privateendpoints
- Deny all other inbound traffic from internet
- Subnet-to-subnet rules as needed for service communication

---

## Identity & Access Management

**Identity Strategy:** Cloud-Only (No Hybrid AD)
- Full Entra ID (Azure AD) environment
- No dependency on client's existing AD infrastructure
- Client currently has AD and M365 but not synced

**Device Management:**
- AVD session hosts: Entra Joined + Intune Managed
- File Server VM: Entra Joined
- All devices managed exclusively through Intune

**Authentication:**
- Single Sign-On (SSO) configured
- Entra Kerberos for Azure Files authentication
- Conditional Access policies: TBD (location-based restrictions recommended)

---

## AVD Configuration

**Host Pool Design:**
- Type: Pooled (shared)
- Load balancing: TBD (Breadth-first or Depth-first)
- Max sessions per host: 8-12 users
- Total capacity required: ~35-50 hosts for 400 users

**Golden Image Components:**
- Windows 11 Multi-session (or Windows 10 EVD)
- Microsoft 365 Apps
- Microsoft Access
- FSLogix agent
- Additional applications: TBD
- Optimization settings via Intune

**Session Host Specifications:**
- VM SKU: TBD (likely D-series or E-series based on performance testing)
- OS Disk: TBD
- Ephemeral OS disk: TBD (cost/performance consideration)

**FSLogix Configuration:**
- Profile storage: Azure Premium Files
- Authentication: Entra Kerberos
- Connectivity: Private endpoint in snet-privateendpoints
- Profile container optimization via golden image and Intune policies
- Exclusions/redirections: TBD
- Cloud Cache: TBD

---

## Storage Infrastructure

### Azure Files (FSLogix Profiles)
- **Type:** Azure Premium Files
- **Authentication:** Entra Kerberos
- **Connectivity:** Private Link/Private Endpoint
- **Location:** Private endpoint in snet-privateendpoints
- **Private DNS:** privatelink.file.core.windows.net linked to vnet-avd
- **Capacity:** TBD based on user profile sizing
- **Performance tier:** TBD
- **Backup:** Azure Files native backup

### File Server VM (Access Databases)
- **Purpose:** Host 150 Access database files
- **Location:** snet-fileserver
- **Join Type:** Entra Joined
- **VM SKU:** TBD
- **Storage:** Premium SSD managed disks
- **Capacity:** TBD based on database sizes
- **Backup:** Azure VM Backup
- **High Availability:** TBD (single VM vs availability set/zone)

---

## Security & Compliance

**Network Security:**
- Network Security Groups (NSGs) on all subnets
- IP Group with 14 branch office public IPs for allowlist
- Private endpoints for Azure Files (no public access)
- Azure Firewall: TBD (optional for POC)

**Access Control:**
- RBAC roles for administration: TBD
- Entra ID security groups for user access
- Conditional Access policies: TBD (IP-based restrictions recommended)
- MFA requirements: TBD

**Data Protection:**
- Encryption at rest (default for Azure)
- Encryption in transit (SMB 3.0+)
- Private endpoints for Azure Files
- Backup retention policies: TBD

---

## Backup & Disaster Recovery

**Azure Backup Services:**
- AVD session hosts: TBD (typically not backed up, rely on golden image)
- File Server VM: Azure VM Backup
- Azure Files (FSLogix): Azure Files Backup
- Backup vault location: TBD
- Retention policies: TBD
- Recovery testing plan: TBD
- Dedicated backup subnet requirement: TBD

---

## Monitoring & Management

**Monitoring Solutions:**
- Azure Monitor for AVD
- Log Analytics workspace: TBD
- Diagnostic settings: TBD
- Alerts and notifications: TBD

**Management Tools:**
- Microsoft Intune for device/app management
- Azure Portal for infrastructure
- AVD Insights: TBD

---

## Cost Considerations (Free Credit Optimization)

**Key Cost Drivers:**
- AVD session hosts: Pay-as-you-go (stop when not testing)
- Azure Files Premium: Based on provisioned capacity
- Private endpoints: ~$7-8/month each
- File Server VM: Stop when not in use
- Backup storage and retention

**Cost Management Strategy:**
- Deallocate VMs when not testing
- Right-size resources during POC
- Monitor credit burn rate
- Document minimum viable infrastructure

---

## Open Questions & Decisions Needed

- [ ] VNet address space and subnet sizing
- [ ] Public IP addresses for 14 branch offices
- [ ] Dedicated subnet required for Azure Backup infrastructure
- [ ] AVD session host VM SKU
- [ ] Golden image base OS (Win 10 vs Win 11)
- [ ] Load balancing algorithm
- [ ] FSLogix exclusions and optimizations
- [ ] File Server HA requirements
- [ ] Azure Files capacity and performance tier
- [ ] Backup retention requirements
- [ ] NSG rule specifics and service tag usage
- [ ] Conditional Access policies (IP-based restrictions)
- [ ] MFA requirements
- [ ] Monitoring and alerting requirements
- [ ] Application dependencies beyond Access
- [ ] User profile size estimates
- [ ] Access database sizes and concurrent usage patterns
- [ ] Testing schedule and success criteria

---

## Success Criteria

- [ ] 400 users can connect simultaneously from branch offices
- [ ] Access to 150 databases functions properly
- [ ] Network access restricted to 14 branch office IPs
- [ ] SSO working correctly
- [ ] FSLogix profiles loading in <10 seconds
- [ ] Session host performance acceptable (8-12 users per host)
- [ ] All resources Entra Joined and Intune managed
- [ ] Backup and recovery tested
- [ ] Security requirements met
- [ ] Within free credit budget for POC duration

---

## Notes
- This environment is intentionally designed with no dependency on client's existing AD infrastructure
- Azure-only deployment with no on-premises connectivity
- Network access controlled via branch office public IP allowlist
- Client plans to migrate to Azure SQL in the future (Access is temporary)
- POC must mimic production to validate approach before full deployment