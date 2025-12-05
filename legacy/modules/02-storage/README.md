# Step 02: Storage Setup for AVD

Modular task-based approach for creating Azure storage infrastructure (Premium Files with Entra authentication).

## Quick Start

```bash
./tasks/01-create-storage-account.sh
./tasks/02-create-file-share.sh
./tasks/03-configure-entra-auth.sh
./tasks/04-create-private-endpoint.sh
```

## Configuration

Edit `config.env` with:
- `STORAGE_ACCOUNT_NAME` - Must be globally unique
- `FILE_SHARE_QUOTA_GB` - File share size
- `VNET_NAME` / `PRIVATE_ENDPOINT_SUBNET_NAME` - For private endpoint

## Tasks

| Task | Purpose | Duration |
|------|---------|----------|
| 01-create-storage-account.sh | Create storage account | 1-2 min |
| 02-create-file-share.sh | Create FSLogix file share | 1-2 min |
| 03-configure-entra-auth.sh | Enable Entra Kerberos auth | 2-3 min |
| 04-create-private-endpoint.sh | Create private endpoint | 2-3 min |

## Next Step

After storage is complete, proceed to **03-entra-group**.
