# Azure Virtual Desktop Deployment Configuration
#
# Purpose: Central configuration file for all AVD deployment scripts
#
# Usage:
#   1. Copy this file to avd-config.ps1
#   2. Edit avd-config.ps1 with your values
#   3. Scripts will automatically dot-source this file when present
#   4. Script parameters override these values
#
# Security:
#   - avd-config.ps1 is in .gitignore and should NEVER be committed
#   - This file (avd-config.example.ps1) is safe to commit
#   - Always use placeholder UUIDs in this example file
#
# Access Pattern:
#   Scripts access values like: $AVD_CONFIG.ResourceGroup or $AVD_CONFIG.Network.VNetName
#   All values stored in the global $AVD_CONFIG hashtable

# ============================================================================
# Global Settings
# ============================================================================
# These settings apply to all deployment steps

$Global:AVD_CONFIG = @{
    SubscriptionId = "00000000-0000-0000-0000-000000000000"
    TenantId = "00000000-0000-0000-0000-000000000000"
    Location = "centralus"
    ResourceGroup = "RG-Azure-VDI-01"
    Environment = "prod"  # Options: prod, dev, test
}

# ============================================================================
# Networking Configuration (Step 01)
# ============================================================================
# Configure virtual network, subnets, and network security groups

$Global:AVD_CONFIG.Network = @{
    VNetName = "vnet-avd-$($Global:AVD_CONFIG.Environment)"
    VNetPrefix = "10.1.0.0/16"

    Subnets = @{
        SessionHosts = @{
            Name = "subnet-session-hosts"
            Prefix = "10.1.0.0/22"
        }
        PrivateEndpoints = @{
            Name = "subnet-private-endpoints"
            Prefix = "10.1.4.0/24"
        }
        FileServer = @{
            Name = "subnet-file-server"
            Prefix = "10.1.5.0/24"
        }
    }

    # Hub VNet Peering (optional - leave empty to skip)
    HubVNetName = ""
    HubVNetResourceGroup = ""
}

# ============================================================================
# Storage Configuration (Step 02)
# ============================================================================
# Configure Azure Files Premium storage for FSLogix profiles

$Global:AVD_CONFIG.Storage = @{
    # Storage account name (auto-generated if empty with format: fslogix<random5digits>)
    AccountName = ""
    FileShareName = "fslogix-profiles"
    FileShareQuotaGB = 1024
}

# ============================================================================
# Entra ID Groups Configuration (Step 03)
# ============================================================================
# Configure user and device groups for AVD access and targeting

$Global:AVD_CONFIG.Groups = @{
    # User groups
    UsersStandard = "AVD-Users-Standard"
    UsersAdmins = "AVD-Users-Admins"

    # Device groups (auto-populated by device naming pattern)
    DevicesSSO = "AVD-Devices-Pooled-SSO"
    DevicesFSLogix = "AVD-Devices-Pooled-FSLogix"
    DevicesNetwork = "AVD-Devices-Pooled-Network"
    DevicesSecurity = "AVD-Devices-Pooled-Security"
}

# ============================================================================
# Host Pool Configuration (Step 04)
# ============================================================================
# Configure AVD workspace, host pool, and application groups

$Global:AVD_CONFIG.HostPool = @{
    WorkspaceName = "AVD-Workspace-$($Global:AVD_CONFIG.Environment)"
    HostPoolName = "Pool-Pooled-$($Global:AVD_CONFIG.Environment)"
    Type = "Pooled"
    MaxSessions = 10
    LoadBalancer = "BreadthFirst"  # BreadthFirst or DepthFirst
    AppGroupName = "Desktop-$($Global:AVD_CONFIG.Environment)"
}

# ============================================================================
# Golden Image Configuration (Step 05)
# ============================================================================
# Configure image gallery for storing and deploying custom images

$Global:AVD_CONFIG.Image = @{
    GalleryName = "gallery_avd_images"
    DefinitionName = "Win11-AVD-Pooled"
    VMName = "avd-gold-$($Global:AVD_CONFIG.Environment)"
    VMSize = "Standard_D4s_v5"
}

# ============================================================================
# Session Host Configuration (Step 06)
# ============================================================================
# Configure session host virtual machines

$Global:AVD_CONFIG.SessionHosts = @{
    VMPrefix = "avd-pool"
    VMSize = "Standard_D4s_v5"
    VMCount = 10
    DiskType = "Premium_LRS"
}

# ============================================================================
# Autoscaling Configuration (Step 10)
# ============================================================================
# Configure scaling plans for cost optimization

$Global:AVD_CONFIG.Scaling = @{
    PlanName = "ScalingPlan-$($Global:AVD_CONFIG.Environment)"
    Timezone = "Central Standard Time"

    # Ramp-up schedule (weekdays 7:00 AM)
    RampUp = @{
        Start = "07:00"
        MinPercent = 20
    }

    # Peak schedule (weekdays 9:00 AM - 5:00 PM)
    Peak = @{
        Start = "09:00"
        MinPercent = 100
    }

    # Ramp-down schedule (weekdays 5:00 PM)
    RampDown = @{
        Start = "17:00"
        MinPercent = 10
    }

    # Off-peak schedule (weekdays 7:00 PM, weekends)
    OffPeak = @{
        Start = "19:00"
        MinPercent = 5
    }
}

# ============================================================================
# Tags (Applied to all resources)
# ============================================================================
# Standard tags for resource organization and cost tracking

$Global:AVD_CONFIG.Tags = @{
    Environment = $Global:AVD_CONFIG.Environment
    Project = "AzureVirtualDesktop"
    ManagedBy = "Automation"
}
