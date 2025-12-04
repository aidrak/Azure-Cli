# Common Utilities for Azure Virtual Desktop Deployment

This directory contains reusable utilities, helper functions, templates, and documentation shared across all AVD deployment steps (01-12).

## Directory Structure

```
common/
├── README.md                          # This file
├── .gitignore                         # Ignore generated artifacts
│
├── scripts/                           # Executable utility scripts
│   ├── verify_prerequisites.ps1      # Check pre-flight requirements
│   ├── validate-config.ps1           # Validate configuration file
│   ├── debug_apps.ps1                # Debug installed applications
│   ├── recover_vm.sh                 # Recovery procedures for VMs
│   ├── export_deployment_config.ps1  # Export deployment configuration
│   └── README.md                     # Script usage guide
│
├── functions/                         # Reusable PowerShell/Bash functions
│   ├── [To be created]
│   └── README.md                     # Function library documentation
│
├── templates/                         # Templates for new deployment steps
│   ├── task-template.sh              # Template for bash task scripts
│   ├── task-template.ps1             # Template for PowerShell tasks
│   ├── config-template.env           # Template for configuration files
│   └── README.md                     # Template usage guide
│
└── docs/                              # Reference documentation
    ├── azure-cli-reference.md        # Azure CLI command reference
    ├── TROUBLESHOOTING.md            # Common issues and solutions
    ├── ARCHITECTURE.md               # Design decisions and patterns
    └── FUNCTIONS.md                  # Function library reference
```

## Scripts

Executable utility scripts for various deployment tasks:

### verify_prerequisites.ps1
**Purpose**: Validates that all prerequisites are met before deployment

**Usage**:
```powershell
.\scripts\verify_prerequisites.ps1
```

**Checks**:
- PowerShell version (7.0+ recommended, 5.1+ required)
- Azure modules installed (Az.Accounts, Az.Compute, Az.Network, etc.)
- Microsoft Graph modules (optional but recommended)
- Azure authentication
- Azure permissions

### validate-config.ps1
**Purpose**: Validates AVD configuration file before deployment

**Usage**:
```powershell
.\scripts\validate-config.ps1 -ConfigFile "path/to/config.ps1"
```

**Validates**:
- Configuration file structure
- Required properties present
- Configuration values valid
- Network CIDR blocks
- VM sizes
- Load balancer type

### debug_apps.ps1
**Purpose**: Debug installed applications on Windows VM

**Usage** (run inside VM):
```powershell
.\scripts\debug_apps.ps1
```

**Checks**:
- Chocolatey installation
- Chrome installation
- Adobe Reader installation

### recover_vm.sh
**Purpose**: Recover from a failed VM creation using existing disk

**Usage**:
```bash
./scripts/recover_vm.sh
```

**Functionality**:
- Retrieves OS disk from failed VM
- Creates new VM from disk
- Preserves configuration and data

**Note**: Requires `config.env` with resource group and location

### export_deployment_config.ps1
**Purpose**: Export complete deployment configuration to JSON for documentation and backup

**Usage**:
```powershell
.\scripts\export_deployment_config.ps1 \
    -ResourceGroupName "RG-Azure-VDI-01" \
    -OutputFile "avd-config.json"
```

**Exports**:
- Resource group information
- VNets and subnets
- Storage accounts
- Host pools
- Application groups
- Workspaces
- Virtual machines

## Functions

**Status**: To be implemented in Phase 2B

Planned function libraries:
- `logging-functions.ps1` - Common logging functions
- `config-functions.ps1` - Configuration loading and validation
- `azure-functions.ps1` - Azure CLI/PowerShell wrappers
- `string-functions.ps1` - String manipulation utilities

## Templates

**Status**: To be implemented in Phase 2B

Template scripts to help create new deployment steps:
- `task-template.sh` - Bash task script template with common patterns
- `task-template.ps1` - PowerShell task template with common patterns
- `config-template.env` - Configuration file template
- `README.md` - How to use templates

## Documentation

### azure-cli-reference.md
Comprehensive reference of Azure CLI commands relevant to AVD deployments:
- Authentication and account management
- Resource groups
- Networking (VNets, subnets, NSGs)
- Storage accounts and file shares
- Virtual machines
- Azure Virtual Desktop (host pools, app groups, workspaces)
- Image galleries
- And more...

### Additional Documentation (To Be Created)

- **TROUBLESHOOTING.md** - Common issues and their solutions
- **ARCHITECTURE.md** - Design decisions and architectural patterns
- **FUNCTIONS.md** - Reference for function library usage

## Usage Patterns

### For Deployment Scripts
Each deployment step (01-12) should:

1. **Source common configuration**:
   ```bash
   source ../config/avd-config.sh
   ```

2. **Load functions as needed**:
   ```bash
   source ../common/functions/logging-functions.sh
   source ../common/functions/azure-functions.sh
   ```

3. **Use utility scripts for validation**:
   ```bash
   ../common/scripts/verify_prerequisites.ps1
   ```

4. **Reference documentation**:
   - For Azure CLI commands: See `common/docs/azure-cli-reference.md`
   - For troubleshooting: See `common/docs/TROUBLESHOOTING.md`
   - For functions: See `common/docs/FUNCTIONS.md`

### For AI Assistants
When creating new deployment steps:

1. Use script templates from `templates/` directory
2. Follow patterns established in `05-golden-image/` (Phase 1)
3. Reference functions in `functions/` directory
4. Check existing scripts in `scripts/` before creating new ones
5. Log all operations consistently

## Directory Organization Philosophy

### Scripts (`scripts/`)
- Standalone, executable utilities
- Focused on specific tasks (validate, debug, recover, export)
- Can be called individually or from deployment steps
- Well-documented with help text

### Functions (`functions/`)
- Reusable function libraries
- Shared across multiple deployment steps
- Sourced by scripts, not executed directly
- Consistent logging and error handling

### Templates (`templates/`)
- Starting point for new deployment steps
- Embedded documentation and comments
- Common patterns and best practices
- Reduce inconsistency across deployment steps

### Docs (`docs/`)
- Reference documentation
- Azure CLI command reference
- Troubleshooting procedures
- Architecture and design decisions

## Integration with Deployment Steps

Each deployment step (01-12) has similar structure:

```
01-networking/
├── README.md                  # Quick start for this step
├── config.env                 # Step-specific configuration
├── tasks/                     # Modular task scripts
├── commands/                  # Command references
├── docs/                      # Step-specific documentation
└── [Uses common/ for utilities]
```

The `common/` directory provides shared services:
- Validation utilities
- Configuration loading
- Error handling functions
- Reference documentation

## Next Steps (Phase 2B & Beyond)

### Immediate (Phase 2B)
- [ ] Create function libraries in `functions/`
  - Logging functions
  - Configuration functions
  - Azure CLI wrappers
  - String utilities

- [ ] Create templates in `templates/`
  - Bash task template
  - PowerShell task template
  - Configuration file template
  - README with examples

- [ ] Create additional documentation
  - TROUBLESHOOTING.md
  - ARCHITECTURE.md
  - FUNCTIONS.md

### Future
- [ ] Add integration tests
- [ ] Create shared configuration schema
- [ ] Add Terraform/Bicep integration
- [ ] Create CI/CD pipeline templates

## Key Principles

1. **Reusability**: Functions and utilities should be reusable across multiple steps
2. **Consistency**: All deployment steps follow the same patterns
3. **AI-Friendly**: Clear structure helps AI understand available tools
4. **Self-Documenting**: Code is easy to understand without extensive comments
5. **Non-Breaking**: Existing deployment steps continue to work unchanged

## Support

For questions or issues:

1. Check the relevant documentation in `docs/`
2. Review the script in `scripts/` for detailed comments
3. Check existing deployment steps (01-12) for usage examples
4. Refer to `common/docs/TROUBLESHOOTING.md` for common problems

## File Statistics

| Directory | Files | Purpose |
|-----------|-------|---------|
| `scripts/` | 5 | Executable utility scripts |
| `functions/` | 0* | Function libraries (planned) |
| `templates/` | 0* | Deployment templates (planned) |
| `docs/` | 1 | Reference documentation |

*To be implemented in Phase 2B

---

**Status**: Phase 2A Complete (Reorganization)
**Next**: Phase 2B - Function libraries and templates
**Then**: Phase 3 - Enhance steps 1-4 with task-centric architecture
