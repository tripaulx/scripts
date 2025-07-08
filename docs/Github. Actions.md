GitHub Actions is a powerful automation platform that can run ShellCheck against your shell scripts. ShellCheck is pre-installed on GitHub's Ubuntu runners, making it easy to integrate into your workflows.

## Basic Usage

The simplest way to run ShellCheck is directly using the pre-installed binary:

```yaml
name: "ShellCheck"
on: [push, pull_request]

jobs:
  shellcheck:
    name: ShellCheck
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Run ShellCheck
      run: find . -type f -name "*.sh" -exec shellcheck {} +
```

## GitHub Advanced Security Integration

To use ShellCheck with GitHub Advanced Security code scanning, you can use [shellcheck-scan](https://github.com/marketplace/actions/shellcheck-sarif-analysis) which generates SARIF reports:

```yaml
name: ShellCheck SARIF
on: [push, pull_request]

jobs:
  scan:
    name: ShellCheck Analysis
    runs-on: ubuntu-latest
    permissions:
      security-events: write  # required for uploading SARIF results
      actions: read          # only required for workflows in private repositories
      contents: read
    steps:
    - uses: actions/checkout@v4
    - name: Run ShellCheck with SARIF output
      uses: reactive-firewall/shellcheck-scan@v1
```

## Differential ShellCheck

GitHub action for running ShellCheck differentially. New findings are reported directly at GitHub pull requests (using SARIF format).

- Source: [@redhat-plumbers-in-action/differential-shellcheck](https://github.com/redhat-plumbers-in-action/differential-shellcheck)

[Usage](https://github.com/redhat-plumbers-in-action/differential-shellcheck#usage):

```yaml
name: Differential ShellCheck
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  lint:
    runs-on: ubuntu-latest

    permissions:
      # required for all workflows
      security-events: write

      # only required for workflows in private repositories
      actions: read
      contents: read

    steps: 
      - name: Repository checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Differential ShellCheck
        uses: redhat-plumbers-in-action/differential-shellcheck@v5
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
```

## Advanced Configuration

### Customizing ShellCheck Options

ShellCheck supports various options that can be used in your workflow (in this case, set minimum severity, specify shell dialect, and set output format):

```yaml
- name: Run ShellCheck
  run: |
    find . -type f -name "*.sh" -exec shellcheck \
      --severity=warning \
      --shell=bash \
      --format=gcc \
      {} +
```

### Common Options

- `-S [error|warning|info|style]`: Set minimum severity of errors to consider
- `-s [sh|bash|dash|ksh]`: Specify shell dialect
- `-e [SC1234,SC2345]`: Exclude specific error codes
- `-f [checkstyle|diff|gcc|json|quiet|tty]`: Set output format

### Version Pinning

To ensure reproducible builds, you can pin to a specific ShellCheck version:

```yaml
- name: Install specific ShellCheck version
  run: |
    wget https://github.com/koalaman/shellcheck/releases/download/v0.9.0/shellcheck-v0.9.0.linux.x86_64.tar.xz
    tar -xf shellcheck-v0.9.0.linux.x86_64.tar.xz
    sudo cp shellcheck-v0.9.0/shellcheck /usr/bin/
```

## Example Configurations

### Check All Shell Scripts

```yaml
- name: Run ShellCheck
  run: find . -type f -name "*.sh" -exec shellcheck {} +
```

### Using with Matrix Strategy

```yaml
jobs:
  shellcheck:
    strategy:
      matrix:
        shell: [bash, sh, dash, ksh]
    steps:
    - name: Run ShellCheck
      run: shellcheck --shell=${{ matrix.shell }} **/*.sh
```

### Selective Checking

```yaml
- name: Check scripts in specific directory
  run: shellcheck scripts/*.sh src/scripts/*.sh
```

## Additional Resources

- [ShellCheck Documentation](https://github.com/koalaman/shellcheck)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [shellcheck-scan Action](https://github.com/marketplace/actions/shellcheck-sarif-analysis)
- [@redhat-plumbers-in-action/differential-shellcheck](https://github.com/redhat-plumbers-in-action/differential-shellcheck)

---
_Last updated: 2024-12-21 by [@reactive-firewall](https://github.com/reactive-firewall)_