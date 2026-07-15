# SPDX-License-Identifier: MIT
# Copyright (c) 2024 Mercedes-Benz Group AG
"""
Expected results for user test project.

This defines what the SCD2 output should look like after processing
all 3 daily files (2024-01-01, 2024-01-02, 2024-01-03).
"""

# Expected SCD2 output after processing all files
# Format: (employee_id, name, department, salary, status, valid_from, valid_to, change_type)

EXPECTED_ROWS = [
    # Employee 1 (Alice): salary changes each day
    (1, "Alice", "Engineering", 100000, "Active", "2024-01-01", "2024-01-02", "update"),
    (1, "Alice", "Engineering", 105000, "Active", "2024-01-02", "2024-01-03", "update"),
    (1, "Alice", "Engineering", 110000, "Active", "2024-01-03", None, "insert"),

    # Employee 2 (Bob): goes inactive on day 2, then deleted on day 3
    (2, "Bob", "Sales", 80000, "Active", "2024-01-01", "2024-01-02", "update"),
    (2, "Bob", "Sales", 80000, "Inactive", "2024-01-02", None, "delete"),  # Missing in file3

    # Employee 3 (Carol): no change day 2, moves to Data Science day 3
    (3, "Carol", "Engineering", 95000, "Active", "2024-01-01", "2024-01-03", "update"),
    (3, "Carol", "Data Science", 100000, "Active", "2024-01-03", None, "insert"),

    # Employee 4 (Dave): joins day 2, goes inactive day 3
    (4, "Dave", "Marketing", 75000, "Active", "2024-01-02", "2024-01-03", "update"),
    (4, "Dave", "Marketing", 75000, "Inactive", "2024-01-03", None, "insert"),

    # Employee 5 (Eve): joins day 3
    (5, "Eve", "Engineering", 90000, "Active", "2024-01-03", None, "insert"),
]

# SQL to validate results
VALIDATION_SQL = """
SELECT
    employee_id,
    name,
    department,
    salary,
    status,
    DATE(dbt_valid_from) as valid_from,
    DATE(dbt_valid_to) as valid_to,
    dbt_change_type
FROM {catalog}.user_test_iterative_snapshot.employee_history
ORDER BY employee_id, dbt_valid_from
"""

# Count expectations
EXPECTED_TOTAL_ROWS = 10
EXPECTED_CURRENT_ROWS = 5  # Rows where dbt_valid_to IS NULL
EXPECTED_EMPLOYEES = 5
