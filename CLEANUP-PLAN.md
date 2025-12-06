# Project Cleanup Plan

**Date:** 2025-12-06
**Objective:** Clean up legacy files, organize documentation, and streamline project structure

---

## Cleanup Tasks

### Task 1: Archive Legacy Module System (HIGH PRIORITY)
**Agent:** Haiku
**Estimated Time:** 30 minutes

**Actions:**
1. Move `modules/` directory to `legacy/modules/`
2. Update all references in documentation
3. Update .gitignore if needed
4. Create legacy/README.md explaining the archive

**Files to Move:**
- modules/00-resource-group/ → legacy/modules/
- modules/01-networking/ → legacy/modules/
- modules/02-storage/ → legacy/modules/
- modules/03-entra-group/ → legacy/modules/
- modules/04-host-pool-workspace/ → legacy/modules/
- modules/05-golden-image/ → legacy/modules/
- modules/06-session-host-deployment/ → legacy/modules/
- modules/07-rbac/ → legacy/modules/
- modules/08-sso/ → legacy/modules/
- modules/09-autoscaling/ → legacy/modules/

**Documentation Updates:**
- ARCHITECTURE.md (references to modules/)
- README.md (references to modules/)
- .claude/CLAUDE.md (update module references)
- Any other docs referencing modules/

---

### Task 2: Consolidate Migration Documentation (MEDIUM PRIORITY)
**Agent:** Haiku
**Estimated Time:** 20 minutes

**Actions:**
1. Move all MIGRATION-* files to `docs/migration/`
2. Keep only MIGRATION-INDEX.md in root (as primary reference)
3. Create docs/migration/README.md with navigation
4. Delete obsolete migration files

**Files to Organize:**
- MIGRATION-COMPLETE-REPORT.md → docs/migration/
- MIGRATION-PROGRESS.md → DELETE (obsolete, work complete)
- MIGRATION-SUMMARY.md → docs/migration/archive/
- MIGRATION-DETAILED-COMPARISON.md → docs/migration/archive/
- MIGRATION-VALIDATION-REPORT.md → docs/migration/archive/
- MIGRATION-QUICK-START.md → docs/migration/archive/
- Keep: MIGRATION-INDEX.md (root, primary reference)

---

### Task 3: Break Down Large Documentation Files (HIGH PRIORITY)
**Agent:** Sonnet
**Estimated Time:** 45 minutes

**Target:** docs/capability-system-design.md (2,015 lines)

**Break into modular files:**
```
docs/capability-system/
├── 01-architecture-overview.md          (~200 lines)
├── 02-capability-domains.md             (~300 lines)
├── 03-operation-schema.md               (~250 lines)
├── 04-operation-lifecycle.md            (~200 lines)
├── 05-parameter-system.md               (~150 lines)
├── 06-idempotency.md                    (~150 lines)
├── 07-validation-framework.md           (~150 lines)
├── 08-rollback-procedures.md            (~150 lines)
├── 09-self-healing.md                   (~100 lines)
├── 10-operation-examples.md             (~300 lines)
├── 11-migration-guide.md                (~200 lines)
├── 12-best-practices.md                 (~150 lines)
├── 13-dependency-management.md          (~150 lines)
├── 14-advanced-topics.md                (~100 lines)
└── README.md                            (navigation hub, ~50 lines)
```

**Create master index:** docs/capability-system/README.md linking to all sections

**Update:** docs/capability-system-design.md → Keep as legacy in docs/archive/

---

### Task 4: Archive Obsolete Documentation (LOW PRIORITY)
**Agent:** Haiku
**Estimated Time:** 15 minutes

**Actions:**
1. Review docs/ directory for legacy/obsolete content
2. Move outdated docs to docs/archive/legacy/
3. Update references

**Candidates for archival:**
- docs/config-migration.md (if no longer relevant)
- Any Phase-X-COMPLETE.md files in docs/archive/
- Outdated workflow guides

---

### Task 5: Update Root Documentation (MEDIUM PRIORITY)
**Agent:** Haiku
**Estimated Time:** 30 minutes

**Actions:**
1. Update ARCHITECTURE.md to reflect capability system
2. Update README.md with current project state
3. Ensure both reference new locations
4. Remove module-based references

**Files:**
- ARCHITECTURE.md (565 lines) - Update for capability system
- README.md (93 lines) - Update quick start and references

---

### Task 6: Organize Temporary/Workflow Files (LOW PRIORITY)
**Agent:** Haiku
**Estimated Time:** 15 minutes

**Actions:**
1. Review root directory for temporary files
2. Move to appropriate locations or delete
3. Clean up any test files

**Files to Review:**
- NEXT-PHASE-PLAN.md → Keep (current planning doc)
- PHASE1-DEPLOYMENT-STATUS.md → DELETE after Phase 1 complete
- CLEANUP-PLAN.md → DELETE after cleanup complete

---

## Agent Assignments Summary

| Task | Agent | Priority | Time | Files |
|------|-------|----------|------|-------|
| 1. Archive Legacy Modules | Haiku | HIGH | 30min | 10 dirs + docs |
| 2. Consolidate Migration Docs | Haiku | MEDIUM | 20min | 7 files |
| 3. Break Down Large Docs | Sonnet | HIGH | 45min | 1 → 15 files |
| 4. Archive Obsolete Docs | Haiku | LOW | 15min | ~5 files |
| 5. Update Root Docs | Haiku | MEDIUM | 30min | 2 files |
| 6. Organize Temp Files | Haiku | LOW | 15min | ~3 files |

**Total Estimated Time:** ~2.5 hours (parallel execution ~1 hour)

---

## Execution Order

### Phase 1: High Priority (Run in Parallel)
- Task 1: Archive Legacy Modules (Haiku)
- Task 3: Break Down Large Docs (Sonnet)

### Phase 2: Medium Priority (Run in Parallel)
- Task 2: Consolidate Migration Docs (Haiku)
- Task 5: Update Root Docs (Haiku)

### Phase 3: Low Priority (Run in Parallel)
- Task 4: Archive Obsolete Docs (Haiku)
- Task 6: Organize Temp Files (Haiku)

---

## Success Criteria

- ✓ All legacy modules in legacy/ directory
- ✓ No files > 1000 lines in docs/
- ✓ Migration docs organized in docs/migration/
- ✓ Clear directory structure
- ✓ All references updated
- ✓ Documentation navigable and modular

---

**Created:** 2025-12-06
