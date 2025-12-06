# Schemas Directory

## Overview

The schemas directory contains JSON Schema definitions for validating YAML configuration files used throughout the capability-based deployment system. These schemas ensure consistency, catch errors early, and provide IDE autocomplete support.

## Schema Files

### Core Schemas

- **`capability.schema.json`** - Schema for capability.yaml files
- **`operation.schema.json`** - Schema for operation YAML files
- **`workflow.schema.json`** - Schema for workflow definitions
- **`config.schema.json`** - Schema for user configuration files

### Supporting Schemas

- **`common.schema.json`** - Common definitions shared across schemas
- **`azure-resources.schema.json`** - Azure resource type definitions
- **`dependency.schema.json`** - Dependency specification schema
- **`state.schema.json`** - State file format schema

## Schema Usage

### Validation with yq/jq

```bash
# Validate capability file
yq eval -o=json capabilities/compute/capability.yaml | \
  jq --schema schemas/capability.schema.json '.'

# Validate operation file
yq eval -o=json capabilities/compute/operations/vm-create.yaml | \
  jq --schema schemas/operation.schema.json '.'
```

### Validation in Tools

```bash
# Use validation tool
./tools/validate-capability.sh capabilities/compute/capability.yaml

# Validate workflow
./tools/validate-workflow.sh workflows/deploy-avd-complete.yaml
```

### IDE Integration

Most modern IDEs support JSON Schema validation for YAML files:

#### VS Code

Add to `.vscode/settings.json`:

```json
{
  "yaml.schemas": {
    "./schemas/capability.schema.json": "/capabilities/*/capability.yaml",
    "./schemas/operation.schema.json": "/capabilities/*/operations/*.yaml",
    "./schemas/workflow.schema.json": "/workflows/*.yaml",
    "./schemas/config.schema.json": "/config.yaml"
  }
}
```

#### JetBrains IDEs (IntelliJ, PyCharm, etc.)

1. Go to Settings → Languages & Frameworks → Schemas and DTDs → JSON Schema Mappings
2. Add schema file and associated file patterns

## Schema Definitions

### capability.schema.json

Validates capability metadata files:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Capability Schema",
  "type": "object",
  "required": ["capability"],
  "properties": {
    "capability": {
      "type": "object",
      "required": ["id", "name", "description", "version", "resource_types"],
      "properties": {
        "id": {
          "type": "string",
          "pattern": "^[a-z][a-z0-9-]*$",
          "description": "Unique capability identifier"
        },
        "name": {
          "type": "string",
          "description": "Human-readable capability name"
        },
        "description": {
          "type": "string",
          "description": "Detailed capability description"
        },
        "version": {
          "type": "string",
          "pattern": "^\\d+\\.\\d+\\.\\d+$",
          "description": "Semantic version"
        },
        "resource_types": {
          "type": "array",
          "items": {
            "type": "string",
            "pattern": "^Microsoft\\.[A-Za-z]+/.+$"
          },
          "description": "Azure resource types managed by this capability"
        },
        "operations": {
          "type": "array",
          "items": {
            "type": "string"
          },
          "description": "Available operations"
        },
        "common_dependencies": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/dependency"
          }
        },
        "required_providers": {
          "type": "array",
          "items": {
            "type": "string",
            "pattern": "^Microsoft\\.[A-Za-z]+$"
          }
        }
      }
    }
  },
  "definitions": {
    "dependency": {
      "type": "object",
      "required": ["capability", "reason"],
      "properties": {
        "capability": {
          "type": "string",
          "description": "Dependent capability ID"
        },
        "reason": {
          "type": "string",
          "description": "Why this dependency exists"
        },
        "required": {
          "type": "boolean",
          "description": "Whether dependency is mandatory"
        }
      }
    }
  }
}
```

### operation.schema.json

Validates operation definitions:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Operation Schema",
  "type": "object",
  "required": ["operation"],
  "properties": {
    "operation": {
      "type": "object",
      "required": ["id", "capability", "action", "description"],
      "properties": {
        "id": {
          "type": "string",
          "pattern": "^[a-z][a-z0-9-]*$"
        },
        "capability": {
          "type": "string",
          "description": "Parent capability ID"
        },
        "action": {
          "type": "string",
          "description": "Action to perform"
        },
        "description": {
          "type": "string"
        },
        "inputs": {
          "type": "object",
          "description": "Input parameters"
        },
        "outputs": {
          "type": "object",
          "description": "Output values"
        },
        "dependencies": {
          "type": "array",
          "items": {
            "type": "string"
          }
        },
        "implementation": {
          "type": "object",
          "required": ["type"],
          "properties": {
            "type": {
              "enum": ["azure-cli", "powershell", "rest-api", "terraform"]
            },
            "command": {
              "type": "string"
            },
            "script": {
              "type": "string"
            }
          }
        }
      }
    }
  }
}
```

### workflow.schema.json

Validates workflow definitions:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Workflow Schema",
  "type": "object",
  "required": ["workflow"],
  "properties": {
    "workflow": {
      "type": "object",
      "required": ["id", "name", "description", "steps"],
      "properties": {
        "id": {
          "type": "string",
          "pattern": "^[a-z][a-z0-9-]*$"
        },
        "name": {
          "type": "string"
        },
        "description": {
          "type": "string"
        },
        "version": {
          "type": "string",
          "pattern": "^\\d+\\.\\d+\\.\\d+$"
        },
        "required_capabilities": {
          "type": "array",
          "items": {
            "type": "string"
          }
        },
        "parameters": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/parameter"
          }
        },
        "steps": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/step"
          },
          "minItems": 1
        },
        "outputs": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/output"
          }
        }
      }
    }
  },
  "definitions": {
    "parameter": {
      "type": "object",
      "required": ["name", "type"],
      "properties": {
        "name": {
          "type": "string"
        },
        "type": {
          "enum": ["string", "number", "boolean", "array", "object"]
        },
        "description": {
          "type": "string"
        },
        "required": {
          "type": "boolean"
        },
        "default": {}
      }
    },
    "step": {
      "type": "object",
      "required": ["id", "capability", "operation"],
      "properties": {
        "id": {
          "type": "string"
        },
        "capability": {
          "type": "string"
        },
        "operation": {
          "type": "string"
        },
        "inputs": {
          "type": "object"
        },
        "depends_on": {
          "type": "array",
          "items": {
            "type": "string"
          }
        },
        "condition": {
          "type": "string"
        }
      }
    },
    "output": {
      "type": "object",
      "required": ["name", "value"],
      "properties": {
        "name": {
          "type": "string"
        },
        "value": {
          "type": "string"
        },
        "description": {
          "type": "string"
        }
      }
    }
  }
}
```

### config.schema.json

Validates user configuration files:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Configuration Schema",
  "type": "object",
  "required": ["global"],
  "properties": {
    "global": {
      "type": "object",
      "required": ["subscription_id", "resource_group", "location"],
      "properties": {
        "subscription_id": {
          "type": "string",
          "pattern": "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
        },
        "tenant_id": {
          "type": "string",
          "pattern": "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
        },
        "resource_group": {
          "type": "string",
          "pattern": "^[a-zA-Z0-9-_().]+$"
        },
        "location": {
          "type": "string"
        },
        "environment": {
          "enum": ["dev", "test", "staging", "prod"]
        },
        "tags": {
          "type": "object",
          "additionalProperties": {
            "type": "string"
          }
        }
      }
    },
    "compute": {
      "type": "object"
    },
    "networking": {
      "type": "object"
    },
    "storage": {
      "type": "object"
    },
    "identity": {
      "type": "object"
    },
    "avd": {
      "type": "object"
    }
  }
}
```

## Schema Versioning

Schemas follow semantic versioning:

- **Major**: Breaking changes to schema structure
- **Minor**: New optional fields added
- **Patch**: Documentation or clarification updates

Version is embedded in schema file:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Capability Schema",
  "version": "1.0.0",
  ...
}
```

## Common Definitions

The `common.schema.json` file contains reusable definitions:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "definitions": {
    "azure_resource_id": {
      "type": "string",
      "pattern": "^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/[^/]+/.+$"
    },
    "azure_location": {
      "type": "string",
      "enum": [
        "eastus", "eastus2", "westus", "westus2", "centralus",
        "northcentralus", "southcentralus", "westcentralus",
        "canadacentral", "canadaeast",
        "brazilsouth",
        "northeurope", "westeurope",
        "uksouth", "ukwest",
        "francecentral", "francesouth",
        "germanywestcentral",
        "norwayeast", "switzerlandnorth",
        "swedencentral",
        "southeastasia", "eastasia",
        "australiaeast", "australiasoutheast",
        "japaneast", "japanwest",
        "koreacentral", "koreasouth",
        "southafricanorth", "uaenorth",
        "southindia", "centralindia"
      ]
    },
    "semantic_version": {
      "type": "string",
      "pattern": "^\\d+\\.\\d+\\.\\d+$"
    },
    "resource_name": {
      "type": "string",
      "pattern": "^[a-zA-Z0-9][a-zA-Z0-9-_]*[a-zA-Z0-9]$",
      "minLength": 2,
      "maxLength": 63
    },
    "tags": {
      "type": "object",
      "additionalProperties": {
        "type": "string",
        "maxLength": 256
      },
      "maxProperties": 50
    }
  }
}
```

## Validation Best Practices

### 1. Fail Fast

Validate configuration early before execution:

```bash
# Validate before running
./tools/validate-config.sh config.yaml && \
./core/engine.sh workflow deploy-avd-complete
```

### 2. Provide Context

Include helpful error messages in schemas:

```json
{
  "vm_size": {
    "type": "string",
    "pattern": "^Standard_[A-Z][0-9]+.*$",
    "description": "Azure VM size (e.g., Standard_D4s_v5)",
    "errorMessage": "VM size must be a valid Azure VM SKU starting with 'Standard_'"
  }
}
```

### 3. Use Defaults

Provide sensible defaults where possible:

```json
{
  "vm_size": {
    "type": "string",
    "default": "Standard_D4s_v5"
  }
}
```

### 4. Validate Constraints

Enforce business rules in schemas:

```json
{
  "max_session_limit": {
    "type": "integer",
    "minimum": 1,
    "maximum": 999999,
    "description": "Maximum users per session host"
  }
}
```

## Testing Schemas

Create test fixtures for each schema:

```
schemas/
  ├── capability.schema.json
  └── tests/
      ├── valid/
      │   ├── compute-capability.yaml
      │   └── networking-capability.yaml
      └── invalid/
          ├── missing-required-field.yaml
          └── invalid-format.yaml
```

Run schema tests:

```bash
# Test all schemas
./schemas/tests/run-schema-tests.sh

# Test specific schema
./schemas/tests/test-capability-schema.sh
```

## Extending Schemas

When adding new fields:

1. **Update schema file** with new field definition
2. **Add documentation** in description field
3. **Create test fixtures** with new field
4. **Update related docs** (README, capability docs)
5. **Increment schema version** if needed

Example:

```json
{
  "properties": {
    "new_field": {
      "type": "string",
      "description": "Description of new field",
      "examples": ["example-value"]
    }
  }
}
```

## Related Documentation

- [Configuration](../docs/01-configuration.md)
- [Module Structure](../docs/04-module-structure.md)
- [Development Rules](../docs/03-development-rules.md)
- [JSON Schema Documentation](https://json-schema.org/)

## Schema Reference

For detailed information about each schema field, refer to:

- Capability schema: See example capability.yaml files in `/capabilities/*/capability.yaml`
- Operation schema: See example operations in `/capabilities/*/operations/*.yaml`
- Workflow schema: See example workflows in `/workflows/*.yaml`
- Config schema: See `config.yaml` in project root
