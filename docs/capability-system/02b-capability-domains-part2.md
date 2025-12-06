- `availability-set-create` - Create availability set

**Images:**
- `image-create` - Create VM image

**Golden Image Pipeline (9 operations):**
- `golden-image-validate-vm-ready` - Verify VM is ready
- `golden-image-configure-defaults` - Configure Windows defaults
- `golden-image-configure-profile` - Configure user profile settings
- `golden-image-install-apps` - Install applications
- `golden-image-install-office` - Install Microsoft Office
- `golden-image-registry-avd` - Configure AVD registry settings
- `golden-image-run-vdot` - Run Virtual Desktop Optimization Tool
- `golden-image-cleanup-temp` - Clean temporary files
- `golden-image-validate` - Final validation

### Resource Relationships

```
VM
  ├─ Managed Disk (OS disk)
  ├─ Network Interface
  │   └─ Subnet
  ├─ Availability Set (optional)
  └─ VM Extensions

Golden Image VM → Sysprep → VM Image → AVD Session Hosts
```

### Golden Image Pipeline Flow

```
1. vm-create (Windows 11 base)
   ↓
2. golden-image-validate-vm-ready
   ↓
3. golden-image-configure-defaults
   ↓
4. golden-image-configure-profile
   ↓
5. golden-image-install-apps
   ↓
6. golden-image-install-office
   ↓
7. golden-image-registry-avd
   ↓
8. golden-image-run-vdot
   ↓
9. golden-image-cleanup-temp
   ↓
10. golden-image-validate
   ↓
11. Sysprep + Generalize
   ↓
12. image-create
```

---

## AVD (15 operations)

Azure Virtual Desktop deployment and management.

### Core Resources

**Host Pools:**
- `hostpool-create` - Create AVD host pool
- `hostpool-update` - Update host pool settings

**Workspaces:**
- `workspace-create` - Create AVD workspace
- `workspace-associate` - Associate workspace with app groups

**Application Groups:**
- `appgroup-create` - Create application group
- `application-add` - Add application to app group

**Session Hosts:**
- `sessionhost-add` - Add session host to pool
- `sessionhost-drain` - Drain session host
- `sessionhost-remove` - Remove session host

**Autoscaling:**
- `autoscaling-assign-rbac` - Assign autoscaling permissions
- `autoscaling-create-plan` - Create scaling plan
- `autoscaling-verify-configuration` - Verify scaling configuration
- `scaling-plan-create` - Create scaling plan (alternative)

**SSO Configuration:**
- `sso-hostpool-configure` - Configure host pool for SSO
- `sso-configuration-verify` - Verify SSO configuration

### Resource Relationships

```
Host Pool
  ├─ Session Hosts (VMs)
  ├─ Application Groups
  │   ├─ Applications
  │   └─ RBAC Assignments (user groups)
  └─ Scaling Plan

Workspace
  └─ Application Groups (associated)
```

### Typical Usage Patterns

**Complete AVD Deployment:**
1. `hostpool-create` - Create pooled host pool
2. `workspace-create` - Create workspace
3. `appgroup-create` - Create desktop app group
4. `workspace-associate` - Link app group to workspace
5. `sessionhost-add` - Add session hosts
6. `autoscaling-create-plan` - Create scaling plan
7. `sso-hostpool-configure` - Enable SSO

**Application Publishing:**
1. `appgroup-create` - Create RemoteApp group
2. `application-add` - Add applications
3. `workspace-associate` - Associate with workspace
4. `appgroup-rbac-assign` - Assign user groups

---

## Management (2 operations)

Azure resource governance and validation.

### Core Resources

**Resource Groups:**
- `resource-group-create` - Create resource group
- `resource-group-validate` - Validate resource group

### Resource Relationships

```
Resource Group
  ├─ Virtual Networks
  ├─ Storage Accounts
  ├─ Virtual Machines
  ├─ Host Pools
  └─ All other Azure resources
```

### Typical Usage

Resource groups are typically the first operation in any deployment:

```yaml
# First operation in deployment
1. resource-group-create
   ↓
2. All other resources created within this group
```

---

## Test Capability (1 operation)

Testing framework for validation.

### Core Resources

**Testing:**
- `test-operation` - Test operation for engine validation

### Usage

Used for:
- Engine testing
- Schema validation
- Template testing
- Debugging

---

## Capability Usage Matrix

### Operation Count by Mode

| Capability | Create | Configure | Validate | Update | Delete | Total |
|-----------|--------|-----------|----------|--------|--------|-------|
| Networking | 15 | 3 | 1 | 0 | 0 | 23 |
| Storage | 4 | 1 | 1 | 0 | 1 | 9 |
| Identity | 8 | 1 | 2 | 0 | 1 | 18 |
| Compute | 10 | 2 | 2 | 0 | 0 | 17 |
| AVD | 8 | 2 | 2 | 1 | 0 | 15 |
| Management | 1 | 0 | 1 | 0 | 0 | 2 |
| Test | 1 | 0 | 0 | 0 | 0 | 1 |
| **Total** | **47** | **9** | **9** | **1** | **2** | **85** |

### Most Common Operations

**By Capability:**
1. Networking: 23 operations (27%)
2. Identity: 18 operations (21%)
3. Compute: 17 operations (20%)
4. AVD: 15 operations (18%)
5. Storage: 9 operations (11%)

**By Mode:**
1. Create: 47 operations (55%)
2. Configure: 9 operations (11%)
3. Validate: 9 operations (11%)
4. Update: 1 operation (1%)
5. Delete: 2 operations (2%)

---

## Related Documentation

- [Architecture Overview](01-architecture-overview.md) - System design principles
- [Operation Schema](03-operation-schema.md) - YAML schema for operations
- [Operation Examples](10-operation-examples.md) - Real operation examples

---

**Last Updated:** 2025-12-06
