# CI/CD Pipeline Guide

This document explains the GitHub Actions CI/CD pipeline for the Azure VDI Deployment Engine.

## Overview

The CI/CD pipeline automatically validates and tests code on every push to `dev` and `main` branches, as well as on pull requests. It ensures code quality, correctness, and consistency.

## Pipeline Triggers

The pipeline runs on:

- **Push to `dev` branch** - Development branch commits
- **Push to `main` branch** - Main production branch commits
- **Pull requests to `dev` or `main`** - Feature branch PRs

## Pipeline Jobs

### 1. ShellCheck Linting

**Name:** `shellcheck`
**Status:** Required to pass
**Duration:** ~30 seconds

Lints all bash scripts in the project using [ShellCheck](https://www.shellcheck.net/).

**What it checks:**
- All scripts in `core/*.sh`
- All scripts in `tests/*.sh`
- Common bash errors and style issues
- Security issues in shell scripts

**Output:**
- Lists all linting issues with file, line, and description
- Provides fixes for many common issues

**Example issues caught:**
- Unquoted variables that should be quoted
- Unused variables
- Missing error handling
- Complex regex that needs escaping

### 2. YAML Validation

**Name:** `yaml-validation`
**Status:** Required to pass
**Duration:** ~20 seconds

Validates all YAML files in the capabilities directory.

**What it checks:**
- **YAML Syntax:** All files are valid YAML
- **Operation Structure:** Required fields in operation files:
  - `operation` key exists
  - `operation.id` field exists
  - Proper YAML structure

**Tools used:**
- `yq` - YAML query and validation
- `yamllint` - YAML style checker

**Output:**
- Lists any syntax errors
- Identifies missing required fields
- Points to files and line numbers with issues

### 3. Unit and Integration Tests

**Name:** `tests`
**Status:** Required to pass
**Duration:** ~3-5 minutes

Runs all test scripts in the `tests/` directory. Tests run in parallel using GitHub Actions matrix strategy.

**Test Scripts:**
- `tests/test-query-simple.sh` - Simple query engine tests
- `tests/test-query.sh` - Comprehensive query engine tests
- `tests/test-discovery.sh` - Discovery engine tests
- `tests/test-executor.sh` - Executor engine tests
- `tests/test-dependency-resolver.sh` - Dependency resolver tests

**What they test:**
- Core engine functionality
- Module loading and exports
- Function behavior with mocked Azure CLI
- Error handling and edge cases
- State management and databases

**Output:**
- Test name and status for each test
- Pass/fail counts
- Detailed error messages for failures
- Uploaded as artifacts for review

### 4. Capability Validation Tests

**Name:** `capability-tests`
**Status:** Optional (continue-on-error)
**Duration:** ~2-3 minutes

Runs integration tests for capability system validation.

**What it checks:**
- Capability system can execute operations
- Operations load and parse correctly
- Error handling in operations

**Output:**
- Test results (may include Azure errors if authenticated)
- Uploaded as artifacts for review

### 5. Test Report

**Name:** `test-report`
**Status:** Always runs
**Duration:** ~10 seconds

Generates a summary report of all pipeline results and collects artifacts.

**Output:**
- Summary table in GitHub Actions workflow summary
- Links to test logs and artifacts
- Overall pass/fail status

## Artifact Handling

All test logs and reports are uploaded as artifacts with a 7-day retention period.

**Artifacts collected:**
- `test-logs-tests/test-query-simple.sh` - Query simple test output
- `test-logs-tests/test-query.sh` - Query test output
- `test-logs-tests/test-discovery.sh` - Discovery test output
- `test-logs-tests/test-executor.sh` - Executor test output
- `test-logs-tests/test-dependency-resolver.sh` - Dependency resolver test output
- `capability-test-logs` - Capability validation output

View artifacts in GitHub Actions workflow run:
1. Navigate to the workflow run
2. Click "Artifacts" at the bottom
3. Download individual logs for analysis

## Exit Codes and Failures

### Hard Failures

These cause the entire pipeline to fail:

1. **YAML Validation fails** - Operation files have syntax errors or missing required fields
2. **Unit tests fail** - Core engine tests fail
3. Any blocking job fails

### Soft Warnings

These log warnings but don't fail the pipeline:

1. **ShellCheck issues** - Code style and potential issues (informational)
2. **Capability tests fail** - Skipped or fail gracefully (integration test)

To make ShellCheck failures block the pipeline, modify `.github/workflows/ci.yml` to remove `continue-on-error: true` from shellcheck jobs.

## Local Testing

### Run Tests Locally

Before pushing, test locally:

```bash
# Run a specific test
./tests/test-query.sh

# Run all tests
for test in tests/*.sh; do
  echo "Running $test..."
  bash "$test"
done
```

### Run ShellCheck Locally

```bash
# Install shellcheck
sudo apt-get install shellcheck

# Check core scripts
shellcheck -x core/*.sh

# Check test scripts
shellcheck -x tests/*.sh
```

### Validate YAML Locally

```bash
# Install yq
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

# Validate all operation files
find capabilities -name "*.yaml" -type f -exec yq eval '.' {} \;

# Check specific file
yq eval '.operation.id' capabilities/avd/operations/appgroup-create.yaml
```

## Troubleshooting

### YAML Validation Fails

**Error:** "operation key missing" or "operation.id missing"

**Solution:**
1. Open the failing YAML file
2. Ensure it has top-level `operation` key
3. Ensure `operation` section has `id` field
4. Use `yq` locally to validate: `yq eval '.operation.id' file.yaml`

### Tests Fail

**Steps to debug:**
1. View the test log in GitHub Actions artifacts
2. Run the test locally with: `bash tests/test-name.sh`
3. Look for the failing assertion
4. Check if mocked dependencies are available (jq, sqlite3, yq)

### ShellCheck Reports Issues

**Common issues:**
- `SC2086` - Unquoted variables: Wrap in quotes - `"$VAR"` instead of `$VAR`
- `SC2181` - Check exit code properly - use `if ! command; then`
- `SC2128` - Array reference without index - use `"${array[@]}"` or `"${array[0]}"`

See [ShellCheck wiki](https://www.shellcheck.net/wiki/) for detailed explanations.

## Performance Optimization

### Current Performance

- **ShellCheck:** ~30 seconds
- **YAML Validation:** ~20 seconds
- **Tests:** ~3-5 minutes (parallel)
- **Capability Tests:** ~2-3 minutes (optional)
- **Total:** ~6-9 minutes

### Optimization Tips

1. **Use caching** - Dependencies (yq, shellcheck) are installed fresh each run
   - Consider using GitHub Actions cache for faster setup
   - Pin versions to avoid version checks

2. **Parallel test execution** - Already implemented using matrix strategy
   - Tests run in parallel, faster than serial

3. **Skip optional tests** - Capability tests can be skipped
   - Safe for PRs, manual runs available

4. **Limit artifacts retention** - Currently 7 days (can reduce to save storage)

## Customization

### Add New Test

1. Create test script in `tests/` directory: `tests/test-myfeature.sh`
2. Make executable: `chmod +x tests/test-myfeature.sh`
3. Update `.github/workflows/ci.yml` matrix strategy:

```yaml
strategy:
  matrix:
    test-script:
      - tests/test-query-simple.sh
      - tests/test-query.sh
      - tests/test-discovery.sh
      - tests/test-executor.sh
      - tests/test-dependency-resolver.sh
      - tests/test-myfeature.sh  # Add here
```

### Change Triggers

To enable/disable pipeline on certain conditions, edit `.github/workflows/ci.yml`:

```yaml
on:
  push:
    branches: [ dev, main ]
    paths:  # Only run on changes to these paths
      - 'core/**'
      - 'tests/**'
      - 'capabilities/**'
```

### Adjust Artifact Retention

Set retention days in `.github/workflows/ci.yml`:

```yaml
env:
  ARTIFACT_RETENTION_DAYS: 7  # Change from 7 to desired days
```

## Integration with GitHub

### View Pipeline Results

1. **In PR:** Look for check status in PR UI
   - Green checkmark: All checks passed
   - Red X: One or more checks failed
   - Yellow dot: Checks in progress

2. **In Actions tab:** See all workflow runs
   - Filter by branch, status, event
   - Drill into specific run for details

3. **In Commits:** See check status next to commit hash

### Status Badges

To add a badge to README.md:

```markdown
[![CI/CD Pipeline](https://github.com/YOUR_REPO/actions/workflows/ci.yml/badge.svg?branch=dev)](https://github.com/YOUR_REPO/actions/workflows/ci.yml)
```

Replace `YOUR_REPO` with your GitHub repository path.

## Best Practices

1. **Run tests locally before pushing** - Catch issues early
2. **Fix ShellCheck warnings** - Prevent future bugs
3. **Keep YAML files valid** - Use validation tools
4. **Review artifact logs** - Understand test failures
5. **Update tests** - Add tests for new features

## Related Documentation

- [Test Framework Guide](./test-framework.md)
- [Executor Reference](./executor-reference.md)
- [Dependency Resolver Guide](./dependency-resolver.md)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
