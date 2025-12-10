# Archived Components

This directory contains archived components that are no longer actively used but preserved for reference.

## Archived: 2024-12-07

### Application Installation Capabilities

**Reason:** Moving to Intune-based application deployment with Managed Images instead of direct VM installation during golden image creation.

**New Approach:** Applications will be deployed via Microsoft Intune using `.intunewin` packages after the base golden image is created and deployed.

#### Archived Files

**`capabilities/applications/`** - Standalone application installation capability
- `capability.yaml` - Capability definition
- `operations/app-adobereader.yaml` - Adobe Reader installation
- `operations/app-chrome.yaml` - Google Chrome installation
- `operations/app-office365.yaml` - Office 365 installation
- `operations/app-teams.yaml` - Microsoft Teams installation
- `operations/app-vscode.yaml` - VS Code installation

**`capabilities/compute/operations/`** - Golden image operations
- `golden-image-install-apps.yaml` - Generic app installation operation
- `golden-image-install-office.yaml` - Office 365 ODT installation
- `golden-image-registry-avd.yaml` - AVD registry optimizations
- `golden-image-run-vdot.yaml` - Virtual Desktop Optimization Tool
- `golden-image-enable-ssh.yaml` - SSH enablement for remote access

### Documentation References

The following documentation files contain references to these archived operations. These references are now outdated but kept for historical context:
- `README.md`
- `QUICKSTART.md`
- `docs/guides/parallel-execution.md`
- `docs/capability-system/02-capability-domains.md`
- `docs/capability-system/14-advanced-topics.md`
- `.claude/skills/azure-operations/SKILL.md`
