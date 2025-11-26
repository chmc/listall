# Workflow YAML Validation

## Overview

All GitHub Actions workflow files in this repository are automatically validated using [yamllint](https://yamllint.readthedocs.io/) to ensure:
- Correct YAML syntax
- Consistent formatting
- No trailing whitespace
- Proper indentation
- Adherence to style guidelines

## Automatic Validation

The `validate-workflows.yml` workflow runs automatically on:
- Every push to `main` that modifies workflows or yamllint config
- Every pull request to `main` that modifies workflows or yamllint config

This ensures broken or malformed workflow files never get merged.

## Local Validation

### Installation

Install yamllint using one of these methods:

**Using pipx (recommended):**
```bash
brew install pipx
pipx install yamllint
```

**Using pip:**
```bash
pip install yamllint
```

**Using Homebrew:**
```bash
brew install yamllint
```

### Running Validation

To validate all workflow files locally:

```bash
# From repository root
yamllint .github/workflows/*.yml
```

To validate a specific workflow:

```bash
yamllint .github/workflows/ci.yml
```

### Expected Output

**Success:** No output (exit code 0) or only warnings
**Failure:** Error messages with file, line number, and issue description (exit code 1)

Example warning (acceptable):
```
.github/workflows/release.yml
  72:121    warning  line too long (141 > 120 characters)  (line-length)
```

Example error (must fix):
```
.github/workflows/ci.yml
  13:1      error    trailing spaces  (trailing-spaces)
```

## Configuration

Validation rules are defined in `.yamllint` at the repository root.

### Key Rules

- **Line length**: Max 120 characters (warnings only)
- **Indentation**: Consistent spacing required
- **Trailing spaces**: Not allowed (errors)
- **Document start**: Optional (GitHub Actions don't require `---`)
- **Truthy values**: Allows `on`, `off`, `yes`, `no` for GitHub Actions

### Customization

To modify rules, edit `.yamllint`. See [yamllint documentation](https://yamllint.readthedocs.io/en/stable/rules.html) for available options.

## Common Issues and Fixes

### Trailing Spaces

**Error:**
```
15:1  error  trailing spaces  (trailing-spaces)
```

**Fix:** Remove spaces at end of line
```bash
# Remove all trailing spaces from a file
sed -i '' 's/[[:space:]]*$//' .github/workflows/filename.yml
```

### Indentation Errors

**Error:**
```
15:5  error  wrong indentation: expected 6 but found 4  (indentation)
```

**Fix:** Ensure consistent indentation (typically 2 spaces per level)

### Line Too Long

**Warning:**
```
72:121  warning  line too long (141 > 120 characters)  (line-length)
```

**Fix (optional):** Break long lines using YAML multi-line syntax if needed, but warnings are acceptable for GitHub Actions.

## Integration with CI/CD

The validation workflow is designed to be:
- **Fast**: Completes in <1 minute
- **Lightweight**: Uses minimal resources
- **Non-blocking**: Warnings don't fail the build
- **Informative**: Provides clear error messages

## Workflow Performance

Typical execution time: 30-45 seconds
- Checkout: ~5s
- Python setup + cache: ~10s
- yamllint installation: ~10s
- Validation: ~5s

## Troubleshooting

### yamllint not found

Ensure yamllint is in your PATH:
```bash
which yamllint
# Should output: /usr/local/bin/yamllint (or pipx path)
```

### Permission errors

Use `pipx` instead of system pip to avoid permission issues.

### False positives

If a rule produces too many false positives, you can disable it in `.yamllint` or change the severity from `error` to `warning`.

## Benefits

1. **Early detection**: Catch syntax errors before pushing
2. **Consistency**: Enforce uniform style across all workflows
3. **Quality**: Prevent common YAML mistakes
4. **Documentation**: `.yamllint` serves as style guide
5. **Efficiency**: Automated validation saves review time

## References

- [yamllint Documentation](https://yamllint.readthedocs.io/)
- [GitHub Actions YAML Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [YAML Specification](https://yaml.org/spec/)
