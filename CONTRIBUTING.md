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
- Update `README.md` and the guides in `docs/` for new features/config options
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

## Developer Certificate of Origin

Contributors must agree to the "Developer Certificate of Origin Version 1.1" (DCO) and comply with the sign-off procedure for contributing to `dbt-iterative-snapshot`.
All contributions submitted to the `dbt-iterative-snapshot` repository have to carry a signed-off-by statement in the commit message using the following format:

    Signed-off-by: Firstname Lastname <email.address>

where the specified email address must be associated with your [GitHub account](https://docs.github.com/en/account-and-profile/concepts/email-addresses). You can do this automatically with `git commit -s`.

If a commit does not carry such a signed-off-by statement, the pull request cannot be merged into the official `dbt-iterative-snapshot` repository because by adding signed-off-by statements to the commit messages, you convey that you have the necessary rights to contribute the respective changes.

We will accept pull requests without a signing comment, but you must still include the signed-off-by line in your commit messages.

### Developer Certificate of Origin (Text)

```text
Developer's Certificate of Origin 1.1

By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I have the right to submit it under the open source license indicated in the file; or

(b) The contribution is based upon previous work that, to the best of my knowledge, is covered under an appropriate open source license and I have the right under that license to submit that work with modifications, whether created in whole or in part by me, under the same open source license (unless I am permitted to submit under a different license), as indicated in the file; or

(c) The contribution was provided directly to me by some other person who certified (a), (b) or (c) and I have not modified it.

(d) I understand and agree that this project and the contribution are public and that a record of the contribution (including all personal information I submit with it, including my sign-off) is maintained indefinitely and may be redistributed consistent with this project or the open source license(s) involved.
```

The text of the DCO is also available at <https://developercertificate.org>.

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
