# Documentation Hub

Central navigation for all Azure VDI Deployment Engine documentation.

## Quick Links

- **[QUICKSTART](../QUICKSTART.md)** - Get started in 5 minutes
- **[ARCHITECTURE](../ARCHITECTURE.md)** - Complete system architecture
- **[README](../README.md)** - Project overview

---

## Documentation Organization

### 📘 Guides (How-To)

Task-oriented documentation for common workflows:

| Guide | Description |
|-------|-------------|
| [Capability Executor](guides/capability-executor-guide.md) | Executing capability operations |
| [Dependency Resolver](guides/dependency-resolver-guide.md) | Understanding operation dependencies |
| [Executor](guides/executor-guide.md) | Core execution engine guide |
| [State Manager](guides/state-manager-guide.md) | Managing deployment state |
| [Parallel Execution](guides/parallel-execution.md) | Running operations in parallel |

### 📖 Reference (Technical)

Detailed technical references:

| Reference | Description |
|-----------|-------------|
| [Azure CLI Reference](reference/azure-cli-reference.md) | Complete Azure CLI command catalog (1200+ lines) |
| [Discovery Engine](reference/discovery-engine.md) | Resource discovery system |
| [Discovery Quick Reference](reference/discovery-quick-reference.md) | Quick discovery patterns |
| [Query Engine](reference/query-engine.md) | Query system reference |

### 🏗️ Capability System

Complete capability system documentation (17 files):

| Document | Description |
|----------|-------------|
| [00. Design Overview](capability-system/00-design-overview.md) | High-level system design |
| [01. Architecture Overview](capability-system/01-architecture-overview.md) | Detailed architecture |
| [02. Capability Domains](capability-system/02-capability-domains.md) | All 7 capability domains |
| [03. Operation Schema](capability-system/03-operation-schema.md) | YAML operation format |
| [04. Operation Lifecycle](capability-system/04-operation-lifecycle.md) | Execution lifecycle |
| [05. Parameter System](capability-system/05-parameter-system.md) | Parameter handling |
| [06. Idempotency](capability-system/06-idempotency.md) | Idempotent operations |
| [07. Validation Framework](capability-system/07-validation-framework.md) | Validation system |
| [08. Rollback Procedures](capability-system/08-rollback-procedures.md) | Rollback handling |
| [09. Self-Healing](capability-system/09-self-healing.md) | Automatic recovery |
| [10. Operation Examples](capability-system/10-operation-examples.md) | Real-world examples |
| [11. Migration Guide](capability-system/11-migration-guide.md) | Module → Capability migration |
| [12. Best Practices](capability-system/12-best-practices.md) | Development patterns |
| [13. Dependency Management](capability-system/13-dependency-management.md) | Managing dependencies |
| [14. Advanced Topics](capability-system/14-advanced-topics.md) | Advanced patterns |
| [Migration Summary](capability-system/MIGRATION-SUMMARY.md) | Migration completion report |
| [README](capability-system/README.md) | Capability system index |

### ⚙️ Features

Deep-dive feature documentation:

| Feature | Description |
|---------|-------------|
| [Remote Execution](features/remote-execution.md) | Azure VM remote command patterns |

### 📚 Migration History

Historical documentation about the module → capability migration:

| Document | Description |
|----------|-------------|
| [Migration](migration/) | Migration process documentation |

### 🗄️ Archive

Historical and deprecated documentation:

| Archive | Description |
|---------|-------------|
| [Archive](archive/) | Legacy status reports and implementation docs |

---

## Documentation Structure

```
docs/
├── README.md                    # This file - Documentation hub
│
├── guides/                      # How-to guides (5 files)
│   ├── capability-executor-guide.md
│   ├── dependency-resolver-guide.md
│   ├── executor-guide.md
│   ├── parallel-execution.md
│   └── state-manager-guide.md
│
├── reference/                   # Technical references (4 files)
│   ├── azure-cli-reference.md   # 1200+ line CLI reference
│   ├── discovery-engine.md
│   ├── discovery-quick-reference.md
│   └── query-engine.md
│
├── capability-system/           # Capability system docs (17 files)
│   ├── 00-design-overview.md
│   ├── 01-architecture-overview.md
│   ├── 02-capability-domains.md
│   └── ... (14 more files)
│
├── features/                    # Feature deep-dives (1 file)
│   └── remote-execution.md
│
├── migration/                   # Migration history
│   └── archive/
│
└── archive/                     # Historical documentation
    └── ... (legacy status reports)
```

---

## For AI Agents

**Navigation Pattern:**
1. Start with **capability-system/** for system understanding
2. Use **guides/** for task execution
3. Reference **reference/** for technical details
4. Check **features/** for specific feature patterns

**Quick Lookups:**
- Creating operations: [capability-system/12-best-practices.md](capability-system/12-best-practices.md)
- Running operations: [guides/executor-guide.md](guides/executor-guide.md)
- Azure CLI commands: [reference/azure-cli-reference.md](reference/azure-cli-reference.md)
- Troubleshooting: [../QUICKSTART.md#troubleshooting](../QUICKSTART.md#troubleshooting)

---

**Last Updated:** 2025-12-06
**Total Documentation Files:** 30+ active files across 5 categories
**System:** Capability-based (83 operations across 7 domains)
