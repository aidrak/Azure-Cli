# Step 01: Networking Setup for AVD

Modular task-based approach for creating Azure Virtual Desktop networking infrastructure.

## Quick Start

```bash
# 1. Configure your environment
export ADMIN_PASSWORD="YourSecurePassword123!"

# 2. Run all tasks sequentially
./tasks/01-create-vnet.sh
./tasks/02-create-nsgs.sh
```

## Tasks

| Task | Purpose | Duration |
|------|---------|----------|
| 01-create-vnet.sh | Create VNet and subnets | 2-3 min |
| 02-create-nsgs.sh | Create Network Security Groups | 1-2 min |

## Configuration

Edit `config.env` with your values:
- `RESOURCE_GROUP_NAME` - Target resource group
- `LOCATION` - Azure region
- `VNET_NAME` - Virtual network name
- `VNET_CIDR` - VNet address space (e.g., 10.0.0.0/16)
- Subnet names and CIDR blocks

## Output

Each task generates:
- `artifacts/[task-name]_TIMESTAMP.log` - Detailed log
- `artifacts/[task-name]-details.txt` - Summary of created resources

## Directory Structure

```
01-networking/
├── README.md              # This file
├── config.env             # Configuration
│
├── tasks/                 # Executable task scripts
│   ├── 01-create-vnet.sh
│   └── 02-create-nsgs.sh
│
├── commands/              # Azure CLI command reference
│   ├── vnet-commands.sh
│   └── nsg-commands.sh
│
├── docs/                  # Documentation
│   └── NETWORKING-REFERENCE.md
│
└── artifacts/             # Generated logs (gitignored)
```

## Troubleshooting

If a task fails:

```bash
# Check logs
cat artifacts/01-create-vnet_*.log

# See detailed output
cat artifacts/01-create-vnet-details.txt

# Re-run task (idempotent)
./tasks/01-create-vnet.sh
```

## Next Step

After networking is complete, proceed to **02-storage**.
