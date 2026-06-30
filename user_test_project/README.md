# User Test Project

This project simulates how a real user would install and use `dbt-iterative-snapshot`.

## Structure

```
user_test_project/
├── dbt_project.yml          # User's project config
├── packages.yml             # Installs dbt-iterative-snapshot (local)
├── profiles.yml             # Databricks connection
├── seeds/
│   └── raw_employee_exports.csv   # 3 daily files of employee data
├── models/
│   ├── employee_history.sql       # Uses iterative_snapshot materialization
│   └── schema.yml                 # Tests
└── expected_results.py            # Expected SCD2 output for validation
```

## Test Data

The seed file simulates 3 daily employee exports:

| Date | Changes |
|------|---------|
| 2024-01-01 | Initial: Alice, Bob, Carol |
| 2024-01-02 | Alice salary +5k, Bob inactive, Dave joins |
| 2024-01-03 | Alice salary +5k, Carol moves to Data Science, Dave inactive, Eve joins |

## Running Manually

```bash
cd user_test_project

# Set credentials (or use parent .env)
source ../.env 2>/dev/null || export DBT_DATABRICKS_TOKEN=your_token

# Install package
dbt deps --profiles-dir .

# Load seed data
dbt seed --profiles-dir . --target dev

# Run the snapshot model
dbt run --profiles-dir . --target dev

# Validate with tests
dbt test --profiles-dir . --target dev
```

## Expected Output

After running, `employee_history` should contain 10 SCD2 rows:
- 5 current records (dbt_valid_to IS NULL)
- 5 historical records (closed versions)

See `expected_results.py` for the exact expected output.
