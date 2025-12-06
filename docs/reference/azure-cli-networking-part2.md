
```bash
# Create VNet peering
az network vnet peering create \
  --resource-group <rg-name> \
  --name <peering-name> \
  --vnet-name <vnet-name> \
  --remote-vnet <remote-vnet-id> \
  --allow-vnet-access \
  --allow-forwarded-traffic

# Create VNet peering with gateway transit
az network vnet peering create \
  --resource-group <rg-name> \
  --name <peering-name> \
  --vnet-name <vnet-name> \
  --remote-vnet <remote-vnet-id> \
  --allow-vnet-access \
  --allow-forwarded-traffic \
  --allow-gateway-transit

# Create VNet peering using remote gateways
az network vnet peering create \
  --resource-group <rg-name> \
  --name <peering-name> \
  --vnet-name <vnet-name> \
  --remote-vnet <remote-vnet-id> \
  --allow-vnet-access \
  --allow-forwarded-traffic \
  --use-remote-gateways

# List VNet peerings
az network vnet peering list \
  --resource-group <rg-name> \
  --vnet-name <vnet-name> \
  --output table

# Show VNet peering
az network vnet peering show \
  --resource-group <rg-name> \
  --vnet-name <vnet-name> \
  --name <peering-name>

# Delete VNet peering
az network vnet peering delete \
  --resource-group <rg-name> \
  --vnet-name <vnet-name> \
  --name <peering-name>
```

---

## Networking - Public IPs

```bash
# Create public IP
az network public-ip create \
  --resource-group <rg-name> \
  --name <pip-name> \
  --location <location> \
  --sku Standard \
  --allocation-method Static

# Show public IP
az network public-ip show \
  --resource-group <rg-name> \
  --name <pip-name>

# List public IPs
az network public-ip list \
  --resource-group <rg-name> \
  --output table

# Delete public IP
az network public-ip delete \
  --resource-group <rg-name> \
  --name <pip-name>

# Get public IP address
az network public-ip show \
  --resource-group <rg-name> \
  --name <pip-name> \
  --query ipAddress -o tsv
```

---

## Networking - Network Interfaces (NICs)

```bash
# Create NIC
az network nic create \
  --resource-group <rg-name> \
  --name <nic-name> \
  --vnet-name <vnet-name> \
  --subnet <subnet-name> \
  --location <location>

# Create NIC with static private IP
az network nic create \
  --resource-group <rg-name> \
  --name <nic-name> \
  --vnet-name <vnet-name> \
  --subnet <subnet-name> \
  --private-ip-address <ip-address>

# Create NIC with public IP
az network nic create \
  --resource-group <rg-name> \
  --name <nic-name> \
  --vnet-name <vnet-name> \
  --subnet <subnet-name> \
  --public-ip-address <pip-name>

# Show NIC
az network nic show \
  --resource-group <rg-name> \
  --name <nic-name>

# List NICs
az network nic list \
  --resource-group <rg-name> \
  --output table

# Delete NIC
az network nic delete \
  --resource-group <rg-name> \
  --name <nic-name>
```

---

## Networking - Private Endpoints

```bash
# Create private endpoint
az network private-endpoint create \
  --resource-group <rg-name> \
  --name <pe-name> \
  --vnet-name <vnet-name> \
  --subnet <subnet-name> \
  --private-connection-resource-id <resource-id> \
  --group-id <sub-resource> \
  --connection-name <connection-name>

# List private endpoints
az network private-endpoint list \
  --resource-group <rg-name> \
  --output table

# Delete private endpoint
az network private-endpoint delete \
  --resource-group <rg-name> \
  --name <pe-name>
```

---

## Networking - Private DNS Zones

```bash
# Create private DNS zone
az network private-dns zone create \
  --resource-group <rg-name> \
  --name <zone-name>

# Link private DNS zone to VNet
az network private-dns link vnet create \
  --resource-group <rg-name> \
  --zone-name <zone-name> \
  --name <link-name> \
  --virtual-network <vnet-name> \
  --registration-enabled false

# List private DNS zones
az network private-dns zone list \
  --resource-group <rg-name> \
  --output table

# Delete private DNS zone
az network private-dns zone delete \
  --resource-group <rg-name> \
  --name <zone-name>
```

---

