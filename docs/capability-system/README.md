# Capability System Documentation

Complete reference for the Azure VDI capability-based operation system.

## Documentation Index

### Core Concepts
1. [Architecture Overview](01-architecture-overview.md) - System design and organization
2. [Capability Domains](02-capability-domains.md) - All 7 capability areas (85 operations)
3. [Operation Schema](03-operation-schema.md) - Complete YAML schema reference

### Operation Design
4. [Operation Lifecycle](04-operation-lifecycle.md) - Execution flow (8 steps)
5. [Parameter System](05-parameter-system.md) - Required/optional parameters, types, defaults
6. [Idempotency](06-idempotency.md) - Preventing duplicate executions
7. [Validation Framework](07-validation-framework.md) - Post-execution verification
8. [Rollback Procedures](08-rollback-procedures.md) - Cleanup and reversal
9. [Self-Healing](09-self-healing.md) - Automated error correction

### Practical Guides
10. [Operation Examples](10-operation-examples.md) - Real operations from all capabilities
11. [Migration Guide](11-migration-guide.md) - Converting legacy to capability format
12. [Best Practices](12-best-practices.md) - Design guidelines and standards

### Advanced Topics
13. [Dependency Management](13-dependency-management.md) - Prerequisites and execution order
14. [Advanced Topics](14-advanced-topics.md) - Remote execution, custom validation

## Quick Links

- **Getting Started:** Start with [Architecture Overview](01-architecture-overview.md)
- **Creating Operations:** See [Operation Schema](03-operation-schema.md) and [Best Practices](12-best-practices.md)
- **Migrating Operations:** See [Migration Guide](11-migration-guide.md)
- **Examples:** See [Operation Examples](10-operation-examples.md)

## Related Documentation

- [MIGRATION-INDEX.md](../../MIGRATION-INDEX.md) - Complete operation catalog
- [ARCHITECTURE.md](../../ARCHITECTURE.md) - System architecture
- [.claude/CLAUDE.md](../../.claude/CLAUDE.md) - Main operational guide

---

**Last Updated:** 2025-12-06
**Total Operations:** 85 across 7 capabilities
**Document Version:** 1.0
