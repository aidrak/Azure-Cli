# Common utility filters for Azure resource queries
# These filters are used across multiple query files to reduce redundancy

# Generic resource filter - extracts common properties from any Azure resource
def generic_resource:
  {
    id: .id,
    name: .name,
    type: .type,
    location: .location,
    tags: .tags
  };

# Provisioning state extractor - handles various Azure resource state representations
def provisioning_state:
  .provisioningState // .properties.provisioningState // "Unknown";

# Power state formatter - converts Azure VM power state codes to human readable format
def power_state:
  if (.instanceView.statuses[]? | select(.code | startswith("PowerState/"))) then
    (.instanceView.statuses[] | select(.code | startswith("PowerState/")) | .displayStatus)
  else
    "Unknown"
  end;

# Tag formatter - ensures tags are present and properly formatted
def safe_tags:
  .tags // {};

# Network interface extractor - safely extracts primary network interface info
def primary_network_interface:
  if (.networkProfile.networkInterfaces | length) > 0 then
    .networkProfile.networkInterfaces[0]
  else
    null
  end;

# Primary IP address extractor - safely gets the private IP from primary NIC
def primary_ip_address:
  if primary_network_interface != null then
    (primary_network_interface.ipConfigurations[0]?.privateIPAddress // null)
  else
    null
  end;

# Resource group extractor - safely retrieves resource group from id
def resource_group_name:
  if .id then
    if (.id | type) == "string" then
      (.id | split("/")[4] // null)
    else
      null
    end
  else
    (.resourceGroup // null)
  end;

# SKU info extractor - safely extracts SKU information
def sku_info:
  if .sku then
    {
      name: .sku.name,
      tier: .sku.tier,
      size: .sku.size
    }
  else
    null
  end;

# Compact output - removes null values to reduce token usage
def compact:
  with_entries(select(.value != null and .value != {} and .value != []));

# Format array of resources with optional filtering
def format_resources:
  map(. + {_resourceGroup: resource_group_name});
