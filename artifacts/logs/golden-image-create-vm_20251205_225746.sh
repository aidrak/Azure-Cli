# Check if VM already exists (idempotent)
if az vm show \
  --resource-group "RG-Azure-VDI-01" \
  --name "gm-temp-vm" \
  --output none 2>/dev/null; then
  echo "[INFO] VM 'gm-temp-vm' already exists. Skipping creation."
  exit 0
fi

# Create VM with TrustedLaunch security
az vm create \
  --resource-group "RG-Azure-VDI-01" \
  --name "gm-temp-vm" \
  --image "MicrosoftWindowsDesktop:windows-11:win11-25h2-avd:latest" \
  --size "Standard_D4s_v6" \
  --admin-username "entra-admin" \
  --admin-password "AzureVDI2024\!@Secure" \
  --vnet-name "avd-vnet" \
  --subnet "subnet-session-hosts" \
  --public-ip-sku Standard \
  --security-type TrustedLaunch \
  --enable-secure-boot true \
  --enable-vtpm true \
  --location "centralus" \
  --output json > artifacts/outputs/golden-image-create-vm.json

# Get VM details
VM_PUBLIC_IP=$(az vm show \
  --resource-group "RG-Azure-VDI-01" \
  --name "gm-temp-vm" \
  --show-details \
  --query "publicIps" \
  --output tsv)

VM_PRIVATE_IP=$(az vm show \
  --resource-group "RG-Azure-VDI-01" \
  --name "gm-temp-vm" \
  --show-details \
  --query "privateIps" \
  --output tsv)

echo "[SUCCESS] VM created successfully"
echo "[INFO] Public IP: $VM_PUBLIC_IP"
echo "[INFO] Private IP: $VM_PRIVATE_IP"
