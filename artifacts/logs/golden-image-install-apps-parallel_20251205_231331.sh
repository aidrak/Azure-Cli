az vm run-command invoke \
  --resource-group "RG-Azure-VDI-01" \
  --name "gm-temp-vm" \
  --command-id RunPowerShellScript \
  --scripts "@/mnt/cache_pool/development/azure-cli/artifacts/scripts/golden-image-install-apps-parallel.ps1" \
  --output json > artifacts/outputs/golden-image-install-apps-parallel.json
