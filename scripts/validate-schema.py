#!/usr/bin/env python3
"""
Schema validation for capability operations
Usage: python3 scripts/validate-schema.py [path]

Validates that all operation YAML files comply with the capability schema.
"""

import yaml
import sys
from pathlib import Path
from typing import Dict, List, Any, Tuple

# Required fields (dot-notation for nested access)
REQUIRED_FIELDS = [
    'operation.id',
    'operation.name',
    'operation.description',
    'operation.capability',
    'operation.operation_mode',
    'operation.resource_type',
    'operation.duration.expected',
    'operation.duration.timeout',
    'operation.duration.type',
    'operation.template.type',
    'operation.template.command'
]

# Valid enum values
VALID_OPERATION_MODES = [
    'create', 'configure', 'validate', 'update', 'delete', 'read',
    'modify', 'adopt', 'assign', 'verify', 'add', 'remove', 'drain'
]

VALID_DURATION_TYPES = ['FAST', 'NORMAL', 'WAIT', 'LONG']

VALID_CAPABILITIES = [
    'networking', 'storage', 'identity', 'compute', 'avd', 'management', 'test-capability'
]

VALID_TEMPLATE_TYPES = [
    'powershell-local', 'powershell-remote', 'powershell-vm-command',
    'azure-cli', 'bash', 'bash-script'
]

# Optional fields that should be validated if present
OPTIONAL_BOOLEAN_FIELDS = [
    'validation.enabled',
    'idempotency.enabled',
    'rollback.enabled'
]


def get_nested_value(data: Dict, path: str) -> Tuple[Any, bool]:
    """
    Navigate nested dictionary using dot notation.
    Returns (value, exists) tuple.
    """
    parts = path.split('.')
    current = data

    for part in parts:
        if not isinstance(current, dict) or part not in current:
            return None, False
        current = current[part]

    return current, True


def validate_operation(file_path: Path) -> List[str]:
    """
    Validate a single operation file against the schema.
    Returns list of error messages (empty if valid).
    """
    errors = []

    try:
        # Load YAML
        with open(file_path, 'r', encoding='utf-8') as f:
            data = yaml.safe_load(f)

        if not data:
            errors.append("Empty or invalid YAML file")
            return errors

        # Check required fields
        for field_path in REQUIRED_FIELDS:
            value, exists = get_nested_value(data, field_path)
            if not exists:
                errors.append(f"Missing required field: {field_path}")
            elif value is None or (isinstance(value, str) and value.strip() == ''):
                errors.append(f"Empty value for required field: {field_path}")

        # Validate enums if fields exist
        operation = data.get('operation', {})

        if 'operation_mode' in operation:
            mode = operation['operation_mode']
            if mode not in VALID_OPERATION_MODES:
                errors.append(
                    f"Invalid operation_mode: '{mode}' "
                    f"(must be one of: {', '.join(VALID_OPERATION_MODES)})"
                )

        if 'capability' in operation:
            cap = operation['capability']
            if cap not in VALID_CAPABILITIES:
                errors.append(
                    f"Invalid capability: '{cap}' "
                    f"(must be one of: {', '.join(VALID_CAPABILITIES)})"
                )

        # Validate duration
        if 'duration' in operation:
            duration = operation['duration']

            # Check duration.type enum
            if 'type' in duration:
                dtype = duration['type']
                if dtype not in VALID_DURATION_TYPES:
                    errors.append(
                        f"Invalid duration.type: '{dtype}' "
                        f"(must be one of: {', '.join(VALID_DURATION_TYPES)})"
                    )

            # Check duration values are integers
            if 'expected' in duration:
                if not isinstance(duration['expected'], int):
                    errors.append(
                        f"duration.expected must be integer, got: {type(duration['expected']).__name__}"
                    )
                elif duration['expected'] <= 0:
                    errors.append(f"duration.expected must be positive, got: {duration['expected']}")

            if 'timeout' in duration:
                if not isinstance(duration['timeout'], int):
                    errors.append(
                        f"duration.timeout must be integer, got: {type(duration['timeout']).__name__}"
                    )
                elif duration['timeout'] <= 0:
                    errors.append(f"duration.timeout must be positive, got: {duration['timeout']}")

            # Timeout should be >= expected
            if 'expected' in duration and 'timeout' in duration:
                if isinstance(duration['expected'], int) and isinstance(duration['timeout'], int):
                    if duration['timeout'] < duration['expected']:
                        errors.append(
                            f"duration.timeout ({duration['timeout']}) should be >= "
                            f"duration.expected ({duration['expected']})"
                        )

        # Validate template type
        if 'template' in operation and 'type' in operation['template']:
            ttype = operation['template']['type']
            if ttype not in VALID_TEMPLATE_TYPES:
                errors.append(
                    f"Invalid template.type: '{ttype}' "
                    f"(must be one of: {', '.join(VALID_TEMPLATE_TYPES)})"
                )

        # Validate optional boolean fields
        for field_path in OPTIONAL_BOOLEAN_FIELDS:
            value, exists = get_nested_value(data, field_path)
            if exists and value is not None:
                if not isinstance(value, bool):
                    errors.append(
                        f"{field_path} must be boolean, got: {type(value).__name__}"
                    )

        # Validate parameters structure if present
        if 'parameters' in operation:
            params = operation['parameters']

            # Should have required and/or optional
            if not isinstance(params, dict):
                errors.append("operation.parameters must be a dictionary")
            else:
                if 'required' not in params and 'optional' not in params:
                    errors.append(
                        "operation.parameters should have 'required' and/or 'optional' keys"
                    )

                # Validate parameter structure
                for param_type in ['required', 'optional']:
                    if param_type in params:
                        if not isinstance(params[param_type], list):
                            errors.append(f"operation.parameters.{param_type} must be a list")
                        else:
                            for i, param in enumerate(params[param_type]):
                                if not isinstance(param, dict):
                                    errors.append(
                                        f"operation.parameters.{param_type}[{i}] must be a dictionary"
                                    )
                                else:
                                    # Check required parameter fields
                                    if 'name' not in param:
                                        errors.append(
                                            f"operation.parameters.{param_type}[{i}] missing 'name'"
                                        )
                                    if 'type' not in param:
                                        errors.append(
                                            f"operation.parameters.{param_type}[{i}] missing 'type'"
                                        )
                                    if 'description' not in param:
                                        errors.append(
                                            f"operation.parameters.{param_type}[{i}] missing 'description'"
                                        )

        # Validate rollback structure if present
        if 'rollback' in operation:
            rollback = operation['rollback']
            if not isinstance(rollback, dict):
                errors.append("operation.rollback must be a dictionary")
            else:
                if 'enabled' in rollback and rollback['enabled']:
                    if 'steps' not in rollback:
                        errors.append("operation.rollback.steps required when enabled=true")
                    elif not isinstance(rollback['steps'], list):
                        errors.append("operation.rollback.steps must be a list")
                    else:
                        for i, step in enumerate(rollback['steps']):
                            if not isinstance(step, dict):
                                errors.append(f"operation.rollback.steps[{i}] must be a dictionary")
                            else:
                                if 'name' not in step:
                                    errors.append(f"operation.rollback.steps[{i}] missing 'name'")
                                if 'command' not in step:
                                    errors.append(f"operation.rollback.steps[{i}] missing 'command'")

        # Validate validation structure if present
        if 'validation' in operation:
            validation = operation['validation']
            if not isinstance(validation, dict):
                errors.append("operation.validation must be a dictionary")
            else:
                # Check for checks/pre_checks/post_checks
                if 'checks' in validation:
                    if not isinstance(validation['checks'], list):
                        errors.append("operation.validation.checks must be a list")
                if 'pre_checks' in validation:
                    if not isinstance(validation['pre_checks'], list):
                        errors.append("operation.validation.pre_checks must be a list")
                if 'post_checks' in validation:
                    if not isinstance(validation['post_checks'], list):
                        errors.append("operation.validation.post_checks must be a list")

    except yaml.YAMLError as e:
        errors.append(f"YAML parsing error: {str(e)}")
    except Exception as e:
        errors.append(f"Unexpected error: {str(e)}")

    return errors


def main():
    """Validate all operations in the capabilities directory."""

    # Determine search path
    if len(sys.argv) > 1:
        search_path = Path(sys.argv[1])
    else:
        search_path = Path('capabilities')

    if not search_path.exists():
        print(f"Error: Path '{search_path}' does not exist")
        sys.exit(1)

    # Find all operation YAML files
    if search_path.is_file():
        all_files = [search_path]
    else:
        all_files = sorted(search_path.glob('*/operations/*.yaml'))

    if not all_files:
        print(f"No operation files found in {search_path}")
        sys.exit(1)

    total = 0
    passed = 0
    failed = 0

    failed_files = []

    print("=" * 70)
    print("Schema Validation Report")
    print("=" * 70)
    print()

    for file_path in all_files:
        total += 1
        errors = validate_operation(file_path)

        # Calculate relative path for cleaner output
        try:
            rel_path = file_path.relative_to(Path.cwd())
        except ValueError:
            rel_path = file_path

        if errors:
            print(f"\u2717 {rel_path}")
            for error in errors:
                print(f"  - {error}")
            print()
            failed += 1
            failed_files.append((rel_path, errors))
        else:
            print(f"\u2713 {rel_path}")
            passed += 1

    print()
    print("=" * 70)
    print("Schema Validation Summary")
    print("=" * 70)
    print(f"  Total:  {total}")
    print(f"  Passed: {passed}")
    print(f"  Failed: {failed}")
    print()

    if failed > 0:
        print("Failed files:")
        for file_path, errors in failed_files:
            print(f"  - {file_path} ({len(errors)} error(s))")
        print()
        sys.exit(1)
    else:
        print("\u2713 All operations comply with schema")
        sys.exit(0)


if __name__ == '__main__':
    main()
