# Step 03: Entra ID & Groups Setup for AVD

Modular task-based approach for configuring Entra ID (Azure AD) security groups and service principals.

## Quick Start

```bash
./tasks/01-create-groups.sh
./tasks/02-create-service-principal.sh
./tasks/03-assign-roles.sh
```

## Configuration

Edit `config.env` with:
- `AVD_USERS_GROUP_NAME` - User group for AVD access
- `AVD_ADMINS_GROUP_NAME` - Admin group
- `AUTOMATION_SP_NAME` - Service principal for automation

## Tasks

| Task | Purpose | Duration |
|------|---------|----------|
| 01-create-groups.sh | Create security groups | 1-2 min |
| 02-create-service-principal.sh | Create automation SP | 1-2 min |
| 03-assign-roles.sh | Assign RBAC roles | 2-3 min |

## Next Step

After Entra is complete, proceed to **04-host-pool-workspace**.
