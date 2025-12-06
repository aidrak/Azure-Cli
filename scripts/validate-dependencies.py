#!/usr/bin/env python3
"""
Dependency validation for capability operations
Usage: python3 scripts/validate-dependencies.py [path]

Validates that all operation prerequisites reference real operations
and detects circular dependencies.
"""

import yaml
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple


def load_operations(files: List[Path]) -> Dict[str, Dict]:
    """Load all operations and build ID to file mapping."""
    operations = {}

    for file_path in files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = yaml.safe_load(f)

            if not data or 'operation' not in data:
                continue

            operation = data['operation']
            op_id = operation.get('id')

            if not op_id:
                print(f"Warning: {file_path} has no operation ID", file=sys.stderr)
                continue

            operations[op_id] = {
                'file': str(file_path),
                'name': operation.get('name', 'Unknown'),
                'requires': operation.get('requires', []),
                'capability': operation.get('capability', 'unknown')
            }

        except Exception as e:
            print(f"Error loading {file_path}: {e}", file=sys.stderr)

    return operations


def find_missing_dependencies(operations: Dict[str, Dict]) -> List[Tuple[str, str, str]]:
    """Find dependencies that reference non-existent operations."""
    missing = []
    all_ids = set(operations.keys())

    for op_id, op_data in operations.items():
        requires = op_data.get('requires', [])

        if isinstance(requires, list):
            for dep_id in requires:
                if isinstance(dep_id, dict):
                    # Handle dictionary format: {operation: "id", ...}
                    dep_id = dep_id.get('operation', '')

                if dep_id and dep_id not in all_ids:
                    missing.append((op_id, dep_id, op_data['file']))

    return missing


def detect_circular_dependencies(operations: Dict[str, Dict]) -> List[List[str]]:
    """Detect circular dependencies using DFS."""
    cycles = []
    visited_global = set()

    def dfs(node: str, visited: Set[str], rec_stack: List[str]) -> None:
        visited.add(node)
        visited_global.add(node)
        rec_stack.append(node)

        requires = operations.get(node, {}).get('requires', [])
        if isinstance(requires, list):
            for dep in requires:
                if isinstance(dep, dict):
                    dep = dep.get('operation', '')

                if not dep or dep not in operations:
                    continue

                if dep not in visited:
                    dfs(dep, visited, rec_stack)
                elif dep in rec_stack:
                    # Found a cycle
                    cycle_start = rec_stack.index(dep)
                    cycle = rec_stack[cycle_start:] + [dep]
                    if cycle not in cycles:
                        cycles.append(cycle)

        rec_stack.pop()

    for op_id in operations.keys():
        if op_id not in visited_global:
            dfs(op_id, set(), [])

    return cycles


def build_dependency_stats(operations: Dict[str, Dict]) -> Dict:
    """Build statistics about dependencies."""
    stats = {
        'total_operations': len(operations),
        'operations_with_deps': 0,
        'total_dependencies': 0,
        'max_dependencies': 0,
        'most_dependent_op': None
    }

    for op_id, op_data in operations.items():
        requires = op_data.get('requires', [])
        if requires and len(requires) > 0:
            stats['operations_with_deps'] += 1
            dep_count = len(requires)
            stats['total_dependencies'] += dep_count

            if dep_count > stats['max_dependencies']:
                stats['max_dependencies'] = dep_count
                stats['most_dependent_op'] = op_id

    return stats


def main():
    """Validate all operations."""
    # Determine search path
    if len(sys.argv) > 1:
        search_path = Path(sys.argv[1])
    else:
        search_path = Path('capabilities')

    if not search_path.exists():
        print(f"Error: Path '{search_path}' does not exist")
        sys.exit(1)

    print("=" * 70)
    print("Dependency Validation")
    print("=" * 70)
    print()

    # Find all operation YAML files
    if search_path.is_file():
        all_files = [search_path]
    else:
        all_files = sorted(search_path.glob('*/operations/*.yaml'))

    if not all_files:
        print(f"No operation files found in {search_path}")
        sys.exit(1)

    print("Analyzing operation dependencies...")
    print()

    # Load operations
    operations = load_operations(all_files)
    print(f"Loaded {len(operations)} operations")
    print()

    has_errors = False

    # Check for missing dependencies
    missing_deps = find_missing_dependencies(operations)

    if missing_deps:
        print("\033[0;31m\u2717 Missing Dependencies Found:\033[0m")
        print()
        for op_id, missing_id, file_path in missing_deps:
            try:
                rel_path = Path(file_path).relative_to(Path.cwd())
            except ValueError:
                rel_path = file_path
            print(f"  Operation: {op_id}")
            print(f"  File: {rel_path}")
            print(f"  Missing dependency: {missing_id}")
            print()
        has_errors = True
    else:
        print("\033[0;32m\u2713 All dependencies reference existing operations\033[0m")
        print()

    # Check for circular dependencies
    circular_deps = detect_circular_dependencies(operations)

    if circular_deps:
        print("\033[0;31m\u2717 Circular Dependencies Found:\033[0m")
        print()
        for i, cycle in enumerate(circular_deps, 1):
            print(f"  Cycle {i}: {' -> '.join(cycle)}")
        print()
        has_errors = True
    else:
        print("\033[0;32m\u2713 No circular dependencies detected\033[0m")
        print()

    # Print statistics
    stats = build_dependency_stats(operations)

    print("=" * 70)
    print("Dependency Statistics")
    print("=" * 70)
    print(f"  Total operations:           {stats['total_operations']}")
    print(f"  Operations with deps:       {stats['operations_with_deps']}")
    print(f"  Total dependencies:         {stats['total_dependencies']}")
    print(f"  Max dependencies per op:    {stats['max_dependencies']}")
    if stats['most_dependent_op']:
        print(f"  Most dependent operation:   {stats['most_dependent_op']}")
    print()

    sys.exit(1 if has_errors else 0)


if __name__ == '__main__':
    main()
