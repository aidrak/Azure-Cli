# Step 04: Host Pool & Workspace Setup for AVD

Modular task-based approach for creating Azure Virtual Desktop host pools and workspaces.

## Quick Start

```bash
./tasks/01-create-host-pool.sh
./tasks/02-create-app-group.sh
./tasks/03-create-workspace.sh
./tasks/04-assign-users.sh
```

## Configuration

Edit `config.env` with:
- `HOST_POOL_NAME` - Host pool name
- `HOST_POOL_TYPE` - Pooled or Personal
- `WORKSPACE_NAME` - Workspace name
- `GOLDEN_IMAGE_VERSION` - Image to use for hosts

## Tasks

| Task | Purpose | Duration |
|------|---------|----------|
| 01-create-host-pool.sh | Create host pool | 2-3 min |
| 02-create-app-group.sh | Create app group | 1-2 min |
| 03-create-workspace.sh | Create workspace | 1-2 min |
| 04-assign-users.sh | Assign users to app group | 1-2 min |

## Next Step

After host pool setup is complete, proceed to **05-golden-image** and then **06-session-host-deployment**.
