# Contributing to dbt-iterative-snapshot

Thank you for your interest in contributing! All pull requests must meet the requirements below.

## Before You Start

Every PR must be linked to an existing issue. If one doesn't exist, [create an issue](https://github.com/mercedes-benz/dbt-iterative-snapshot/issues) first and wait for maintainer approval before starting work.

## Requirements

### 1. Tests Required
- Add integration tests in `integration_tests/` for new functionality
- All existing tests must pass
- Run locally before submitting:
  ```bash
  cd integration_tests
  dbt deps
  dbt seed --target dev
  dbt run --target dev
  dbt test --target dev
  ```

### 2. Code Quality
- `dbt compile` must succeed
- SQL must pass linting:
  ```bash
  sqlfluff lint macros/ --dialect databricks
  ```
- Follow existing code patterns

### 3. Documentation
- Update `README.md` for new features/config options
- Add docstrings to new macros
- Add entry to `CHANGELOG.md` under `## Unreleased`

### 4. CI Checks
All checks must pass before merge.

## Development Setup

```bash
git clone https://github.com/mercedes-benz/dbt-iterative-snapshot.git
cd dbt-iterative-snapshot/integration_tests

# Configure credentials
cp profiles.yml.example profiles.yml
# Edit profiles.yml with your Databricks credentials

dbt deps
dbt compile --target dev
```

## Developer Certificate of Origin (DCO)

All contributions must be signed off under the [Developer Certificate of Origin (DCO)](https://developercertificate.org/). This certifies that you have the right to submit the contribution under the project's license.

**Every commit must include a sign-off line:**

```
Signed-off-by: Your Name <your.email@example.com>
```

You can do this automatically with `git commit -s`.

Pull requests without DCO sign-off cannot be merged.

## Pull Request Process

1. Fork and create a feature branch from `main`
2. Make changes following requirements above
3. Sign off all commits (`git commit -s`)
4. Open PR using the template
5. Address review feedback

## Acceptance Criteria

**We accept:**
- Bug fixes with tests
- Performance improvements with benchmarks
- Features aligned with package purpose (SCD2 snapshots for out-of-order data)

**We don't accept:**
- PRs without tests
- PRs that don't pass CI
- Breaking changes without migration path

## Questions?

Open a [discussion](https://github.com/mercedes-benz/dbt-iterative-snapshot/discussions).
