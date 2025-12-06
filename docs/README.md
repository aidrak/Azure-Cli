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
| [Capability Executor Part 1](guides/capability-executor-part1.md) | Executing capability operations (basics) |
| [Capability Executor Part 2a](guides/capability-executor-part2a.md) | Advanced execution patterns |
| [Capability Executor Part 2b](guides/capability-executor-part2b.md) | Execution reference |
| [Dependency Resolver Part 1](guides/dependency-resolver-part1.md) | Understanding operation dependencies |
| [Dependency Resolver Part 2](guides/dependency-resolver-part2.md) | Advanced dependency patterns |
| [Executor Overview](guides/executor-overview.md) | Core execution engine overview |
| [Executor Advanced](guides/executor-advanced.md) | Advanced execution techniques |
| [Executor Reference](guides/executor-reference.md) | Execution engine reference |
| [State Manager Overview](guides/state-manager-overview.md) | Managing deployment state (basics) |
| [State Manager API](guides/state-manager-api.md) | State management API reference |
| [State Manager Patterns](guides/state-manager-patterns.md) | Common state patterns |
| [Parallel Execution Part 1](guides/parallel-execution-part1.md) | Running operations in parallel |
| [Parallel Execution Part 2](guides/parallel-execution-part2.md) | Advanced parallel patterns |

### 📖 Reference (Technical)

Detailed technical references:

| Reference | Description |
|-----------|-------------|
| **Azure CLI Commands** | Complete Azure CLI command catalog |
| [Azure CLI - Core](reference/azure-cli-core.md) | Authentication, Resource Groups |
| [Azure CLI - Networking Part 1](reference/azure-cli-networking-part1.md) | VNets, Subnets, NSGs (basics) |
| [Azure CLI - Networking Part 2](reference/azure-cli-networking-part2.md) | VPN, DNS, Private Endpoints |
| [Azure CLI - Storage](reference/azure-cli-storage.md) | Storage Accounts, File Shares |
| [Azure CLI - Compute](reference/azure-cli-compute.md) | VMs, Disks, Images |
| [Azure CLI - AVD](reference/azure-cli-avd.md) | Host Pools, Workspaces |
| [Azure CLI - Identity](reference/azure-cli-identity.md) | RBAC, Entra ID |
| [Azure CLI - Management](reference/azure-cli-management.md) | Monitoring, Tags, Locks |
| **Discovery & Query** | Resource discovery and query systems |
| [Discovery Engine Part 1a](reference/discovery-engine-part1a.md) | Resource discovery basics |
| [Discovery Engine Part 1b](reference/discovery-engine-part1b.md) | Discovery patterns |
| [Discovery Engine Part 2a](reference/discovery-engine-part2a.md) | Advanced discovery |
| [Discovery Engine Part 2b](reference/discovery-engine-part2b.md) | Discovery reference |
| [Discovery Quick Reference](reference/discovery-quick-reference.md) | Quick discovery patterns |
| [Query Engine Part 1a](reference/query-engine-part1a.md) | Query system basics |
| [Query Engine Part 1b](reference/query-engine-part1b.md) | Query patterns |
| [Query Engine Part 2a](reference/query-engine-part2a.md) | Advanced queries |
| [Query Engine Part 2b](reference/query-engine-part2b.md) | Query reference |

### 🏗️ Capability System

Complete capability system documentation (organized by numbered sections):

| Document | Description |
|----------|-------------|
| [00. Design Overview](capability-system/00-design-overview.md) | High-level system design |
| [01. Architecture Overview](capability-system/01-architecture-overview.md) | Detailed architecture |
| **02. Capability Domains** | All 7 capability domains |
| [02a. Capability Domains Part 1](capability-system/02a-capability-domains-part1.md) | Domain overview (networking, storage, identity) |
| [02b. Capability Domains Part 2](capability-system/02b-capability-domains-part2.md) | Domain details (compute, AVD, management) |
| **03. Operation Schema** | YAML operation format |
| [03a1. Operation Schema Core Part 1](capability-system/03a1-operation-schema-core-part1.md) | Core schema basics |
| [03a2. Operation Schema Core Part 2](capability-system/03a2-operation-schema-core-part2.md) | Core schema advanced |
| [03b1. Operation Schema Execution Part 1](capability-system/03b1-operation-schema-execution-part1.md) | Execution schema basics |
| [03b2. Operation Schema Execution Part 2](capability-system/03b2-operation-schema-execution-part2.md) | Execution schema advanced |
| **04. Operation Lifecycle** | Execution lifecycle phases |
| [04a1. Operation Lifecycle Phases 1-2](capability-system/04a1-operation-lifecycle-phases1-2.md) | Initialization & Validation |
| [04a2. Operation Lifecycle Phases 3-4](capability-system/04a2-operation-lifecycle-phases3-4.md) | Template Processing & Execution |
| [04b1. Operation Lifecycle Phases 5-6](capability-system/04b1-operation-lifecycle-phases5-6.md) | Monitoring & Error Handling |
| [04b2. Operation Lifecycle Phases 7-8](capability-system/04b2-operation-lifecycle-phases7-8.md) | State Management & Completion |
| **05. Parameter System** | Parameter handling |
| [05a. Parameter System Part 1](capability-system/05a-parameter-system-part1.md) | Parameter basics |
| [05b. Parameter System Part 2](capability-system/05b-parameter-system-part2.md) | Advanced parameters |
| **06. Idempotency** | Idempotent operations |
| [06a. Idempotency Part 1](capability-system/06a-idempotency-part1.md) | Idempotency basics |
| [06b. Idempotency Part 2](capability-system/06b-idempotency-part2.md) | Idempotency patterns |
| **07. Validation Framework** | Validation system |
| [07a. Validation Framework Part 1](capability-system/07a-validation-framework-part1.md) | Validation basics |
| [07b. Validation Framework Part 2](capability-system/07b-validation-framework-part2.md) | Advanced validation |
| **08. Rollback Procedures** | Rollback handling |
| [08a. Rollback Procedures Part 1](capability-system/08a-rollback-procedures-part1.md) | Rollback basics |
| [08b. Rollback Procedures Part 2](capability-system/08b-rollback-procedures-part2.md) | Advanced rollback |
| **09. Self-Healing** | Automatic recovery |
| [09a. Self-Healing Part 1](capability-system/09a-self-healing-part1.md) | Self-healing basics |
| [09b. Self-Healing Part 2](capability-system/09b-self-healing-part2.md) | Advanced self-healing |
| **10. Operation Examples** | Real-world examples |
| [10a1. Operation Examples Part 1a](capability-system/10a1-operation-examples-part1a.md) | Basic examples |
| [10a2. Operation Examples Part 1b](capability-system/10a2-operation-examples-part1b.md) | Intermediate examples |
| [10b1. Operation Examples Part 2a](capability-system/10b1-operation-examples-part2a.md) | Advanced examples |
| [10b2. Operation Examples Part 2b](capability-system/10b2-operation-examples-part2b.md) | Expert examples |
| **11. Migration Guide** | Module → Capability migration |
| [11a. Migration Guide Part 1](capability-system/11a-migration-guide-part1.md) | Migration overview |
| [11b. Migration Guide Part 2](capability-system/11b-migration-guide-part2.md) | Migration details |
| **12. Best Practices** | Development patterns |
| [12a. Best Practices Part 1](capability-system/12a-best-practices-part1.md) | Core best practices |
| [12b. Best Practices Part 2](capability-system/12b-best-practices-part2.md) | Advanced patterns |
| **13. Dependency Management** | Managing dependencies |
| [13a. Dependency Management Part 1](capability-system/13a-dependency-management-part1.md) | Dependency basics |
| [13b. Dependency Management Part 2](capability-system/13b-dependency-management-part2.md) | Advanced dependencies |
| **14. Advanced Topics** | Advanced patterns |
| [14a. Advanced Topics Part 1](capability-system/14a-advanced-topics-part1.md) | Advanced concepts |
| [14b. Advanced Topics Part 2](capability-system/14b-advanced-topics-part2.md) | Expert topics |
| **Migration Summary** | Migration completion report |
| [Migration Summary Part 1](capability-system/MIGRATION-SUMMARY-part1.md) | Summary overview |
| [Migration Summary Part 2](capability-system/MIGRATION-SUMMARY-part2.md) | Summary details |
| [README](capability-system/README.md) | Capability system index |

### ⚙️ Features

Deep-dive feature documentation:

| Feature | Description |
|---------|-------------|
| [Remote Execution Part 1](features/remote-execution-part1.md) | Azure VM remote command patterns (basics) |
| [Remote Execution Part 2](features/remote-execution-part2.md) | Advanced remote execution |

### 📚 Migration History

Historical documentation about the module → capability migration:

| Document | Description |
|----------|-------------|
| [Migration Report Part 1](migration/migration-report-part1.md) | Migration process overview |
| [Migration Report Part 2](migration/migration-report-part2.md) | Migration completion details |
| [Migration](migration/) | Additional migration documentation |

### 🗄️ Archive

Historical and deprecated documentation:

| Archive | Description |
|---------|-------------|
| [Archive](archive/) | Legacy status reports and implementation docs |

---

## Documentation Structure

All documentation files are now under 300 lines for improved AI navigation.

```
docs/
├── README.md                    # This file - Documentation hub
│
├── guides/                      # How-to guides (13 files, all <300 lines)
│   ├── capability-executor-part1.md
│   ├── capability-executor-part2a.md
│   ├── capability-executor-part2b.md
│   ├── dependency-resolver-part1.md
│   ├── dependency-resolver-part2.md
│   ├── executor-overview.md
│   ├── executor-advanced.md
│   ├── executor-reference.md
│   ├── parallel-execution-part1.md
│   ├── parallel-execution-part2.md
│   ├── state-manager-overview.md
│   ├── state-manager-api.md
│   └── state-manager-patterns.md
│
├── reference/                   # Technical references (18 files, all <300 lines)
│   ├── azure-cli-core.md
│   ├── azure-cli-networking-part1.md
│   ├── azure-cli-networking-part2.md
│   ├── azure-cli-storage.md
│   ├── azure-cli-compute.md
│   ├── azure-cli-avd.md
│   ├── azure-cli-identity.md
│   ├── azure-cli-management.md
│   ├── discovery-engine-part1a.md
│   ├── discovery-engine-part1b.md
│   ├── discovery-engine-part2a.md
│   ├── discovery-engine-part2b.md
│   ├── discovery-quick-reference.md
│   ├── query-engine-part1a.md
│   ├── query-engine-part1b.md
│   ├── query-engine-part2a.md
│   └── query-engine-part2b.md
│
├── capability-system/           # Capability system docs (39 files, all <300 lines)
│   ├── 00-design-overview.md
│   ├── 01-architecture-overview.md
│   ├── 02a-capability-domains-part1.md
│   ├── 02b-capability-domains-part2.md
│   ├── 03a1-operation-schema-core-part1.md
│   ├── 03a2-operation-schema-core-part2.md
│   ├── 03b1-operation-schema-execution-part1.md
│   ├── 03b2-operation-schema-execution-part2.md
│   ├── 04a1-operation-lifecycle-phases1-2.md
│   ├── 04a2-operation-lifecycle-phases3-4.md
│   ├── 04b1-operation-lifecycle-phases5-6.md
│   ├── 04b2-operation-lifecycle-phases7-8.md
│   └── ... (27 more files)
│
├── features/                    # Feature deep-dives (2 files, all <300 lines)
│   ├── remote-execution-part1.md
│   └── remote-execution-part2.md
│
├── migration/                   # Migration history (2 files, all <300 lines)
│   ├── migration-report-part1.md
│   └── migration-report-part2.md
│
└── archive/                     # Historical documentation
    └── ... (legacy status reports)
```

---

## For AI Agents

**Navigation Pattern:**
1. Start with **capability-system/** for system understanding (read 00-design-overview.md first)
2. Use **guides/** for task execution (start with executor-overview.md or state-manager-overview.md)
3. Reference **reference/** for technical details (Azure CLI commands, query/discovery patterns)
4. Check **features/** for specific feature patterns (remote-execution-part1.md)

**Quick Lookups:**
- Creating operations: [capability-system/12a-best-practices-part1.md](capability-system/12a-best-practices-part1.md)
- Running operations: [guides/executor-overview.md](guides/executor-overview.md)
- Azure CLI commands: [reference/azure-cli-core.md](reference/azure-cli-core.md) (start here, then navigate to specific services)
- Troubleshooting: [../QUICKSTART.md#troubleshooting](../QUICKSTART.md#troubleshooting)

**File Organization:**
- All files are now **under 300 lines** for efficient AI navigation
- Multi-part files follow naming convention: `{base-name}-part{N}.md` or `{number}{letter}-{name}-part{N}.md`
- Start with "part1" or "part1a" files for topic overview, then proceed to subsequent parts

---

**Last Updated:** 2025-12-06
**Total Documentation Files:** 74 active files across 5 categories (all under 300 lines)
**System:** Capability-based (79 operations across 7 domains)
