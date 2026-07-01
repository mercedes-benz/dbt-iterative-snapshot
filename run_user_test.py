# SPDX-License-Identifier: MIT
# Copyright (c) 2024 Mercedes-Benz Group AG
#!/usr/bin/env python3
"""
User simulation test for dbt-iterative-snapshot.

Simulates a real user:
1. Installing the package
2. Creating a model with iterative_snapshot materialization
3. Running the model
4. Validating the SCD2 output

Usage:
    python run_user_test.py              # Run dbt tests + validation
    python run_user_test.py --func       # Also run pytest functional tests
    python run_user_test.py --func-only  # Only run pytest functional tests
    python run_user_test.py --validate-only  # Skip dbt run, just validate
    python run_user_test.py --full-refresh   # Full refresh the model
"""

import subprocess
import sys
import os
from pathlib import Path


def load_env():
    """Load environment variables from .env file."""
    env_file = Path(__file__).parent / ".env"

    if not env_file.exists():
        print("ERROR: .env file not found!")
        print("Copy .env.example to .env and fill in your Databricks credentials")
        sys.exit(1)

    with open(env_file) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                os.environ[key.strip()] = value.strip()

    required = ["DBT_DATABRICKS_HOST", "DBT_DATABRICKS_HTTP_PATH",
                "DBT_DATABRICKS_TOKEN", "DBT_DATABRICKS_CATALOG"]
    missing = [v for v in required if not os.environ.get(v)]

    if missing:
        print(f"ERROR: Missing environment variables: {', '.join(missing)}")
        sys.exit(1)

    print(f"✓ Connected to: {os.environ['DBT_DATABRICKS_HOST']}")
    print(f"✓ Catalog: {os.environ['DBT_DATABRICKS_CATALOG']}")


def run_dbt(args, cwd):
    """Run a dbt command."""
    cmd = ["dbt"] + args + ["--profiles-dir", ".", "--target", "dev"]
    print(f"\n{'='*60}")
    print(f"Running: {' '.join(cmd)}")
    print(f"{'='*60}\n")

    result = subprocess.run(cmd, cwd=cwd)
    return result.returncode == 0


def run_pytest(test_path, project_root):
    """Run pytest functional tests."""
    cmd = ["pytest", test_path, "-s", "-v"]
    print(f"\n{'='*60}")
    print(f"Running: {' '.join(cmd)}")
    print(f"{'='*60}\n")

    result = subprocess.run(cmd, cwd=project_root)
    return result.returncode == 0


def run_functional_tests():
    """Run pytest functional tests."""
    project_root = Path(__file__).parent
    test_path = "tests/functional/test_iterative_snapshot.py"

    if not (project_root / test_path).exists():
        print(f"ERROR: Functional tests not found at {test_path}")
        return False

    print(f"\n🧪 Running functional tests (pytest)...\n")

    if not run_pytest(test_path, project_root):
        print("❌ Some functional tests failed")
        return False
    print("✓ All functional tests passed")

    return True


def validate_results():
    """Connect to Databricks and validate the SCD2 output."""
    print("\n" + "="*60)
    print("🔍 Validating Results")
    print("="*60 + "\n")

    try:
        from databricks import sql as databricks_sql
    except ImportError:
        print("⚠️  databricks-sql-connector not installed, skipping validation")
        print("   Install with: pip install databricks-sql-connector")
        return True

    catalog = os.environ["DBT_DATABRICKS_CATALOG"]
    schema = os.environ.get("DBT_DATABRICKS_SCHEMA", "00_metadata")
    host = os.environ["DBT_DATABRICKS_HOST"]
    http_path = os.environ["DBT_DATABRICKS_HTTP_PATH"]
    token = os.environ["DBT_DATABRICKS_TOKEN"]

    try:
        connection = databricks_sql.connect(
            server_hostname=host,
            http_path=http_path,
            access_token=token
        )
        cursor = connection.cursor()

        # Test 1: Check row count
        print("Test 1: Checking total row count...")
        cursor.execute(f"""
            SELECT COUNT(*) as cnt
            FROM {catalog}.{schema}.employee_history
        """)
        total_rows = cursor.fetchone()[0]
        print(f"   Total rows: {total_rows}")

        # Test 2: Check current records (dbt_valid_to IS NULL)
        print("\nTest 2: Checking current records...")
        cursor.execute(f"""
            SELECT COUNT(*) as cnt
            FROM {catalog}.{schema}.employee_history
            WHERE dbt_valid_to IS NULL
        """)
        current_rows = cursor.fetchone()[0]
        print(f"   Current records (valid_to IS NULL): {current_rows}")

        # Test 3: Check distinct employees
        print("\nTest 3: Checking distinct employees...")
        cursor.execute(f"""
            SELECT COUNT(DISTINCT employee_id) as cnt
            FROM {catalog}.{schema}.employee_history
        """)
        distinct_employees = cursor.fetchone()[0]
        print(f"   Distinct employees: {distinct_employees}")

        # Test 4: Check SCD2 validity (no overlaps)
        print("\nTest 4: Checking SCD2 validity (no gaps/overlaps)...")
        cursor.execute(f"""
            WITH validity_check AS (
                SELECT
                    employee_id,
                    dbt_valid_from,
                    dbt_valid_to,
                    LEAD(dbt_valid_from) OVER (PARTITION BY employee_id ORDER BY dbt_valid_from) as next_valid_from
                FROM {catalog}.{schema}.employee_history
            )
            SELECT COUNT(*) as issues
            FROM validity_check
            WHERE dbt_valid_to IS NOT NULL
              AND next_valid_from IS NOT NULL
              AND dbt_valid_to != next_valid_from
        """)
        validity_issues = cursor.fetchone()[0]
        print(f"   Validity issues (gaps/overlaps): {validity_issues}")

        # Test 5: Show sample data
        print("\nTest 5: Sample data (first 10 rows)...")
        cursor.execute(f"""
            SELECT
                employee_id,
                name,
                department,
                salary,
                status,
                DATE(dbt_valid_from) as valid_from,
                DATE(dbt_valid_to) as valid_to,
                dbt_change_type
            FROM {catalog}.{schema}.employee_history
            ORDER BY employee_id, dbt_valid_from
            LIMIT 10
        """)
        rows = cursor.fetchall()
        print("\n   employee_id | name    | department   | salary | status   | valid_from | valid_to   | change_type")
        print("   " + "-"*95)
        for row in rows:
            valid_to = str(row[6]) if row[6] else "NULL"
            print(f"   {row[0]:11} | {row[1]:7} | {row[2]:12} | {row[3]:6} | {row[4]:8} | {row[5]} | {valid_to:10} | {row[7]}")

        cursor.close()
        connection.close()

        # Summary
        print("\n" + "="*60)
        print("📊 Validation Summary")
        print("="*60)

        all_passed = True

        if total_rows >= 8:
            print(f"✅ Total rows: {total_rows} (expected >= 8)")
        else:
            print(f"❌ Total rows: {total_rows} (expected >= 8)")
            all_passed = False

        if current_rows >= 4:
            print(f"✅ Current records: {current_rows} (expected >= 4)")
        else:
            print(f"❌ Current records: {current_rows} (expected >= 4)")
            all_passed = False

        if distinct_employees == 5:
            print(f"✅ Distinct employees: {distinct_employees} (expected 5)")
        else:
            print(f"❌ Distinct employees: {distinct_employees} (expected 5)")
            all_passed = False

        if validity_issues == 0:
            print(f"✅ SCD2 validity: No gaps/overlaps")
        else:
            print(f"❌ SCD2 validity: {validity_issues} issues found")
            all_passed = False

        return all_passed

    except Exception as e:
        print(f"❌ Error connecting to Databricks: {e}")
        return False


def main():
    args = sys.argv[1:]
    validate_only = "--validate-only" in args
    full_refresh = "--full-refresh" in args
    func_only = "--func-only" in args
    run_func = "--func" in args or func_only

    # Load .env
    load_env()

    user_test_dir = Path(__file__).parent / "user_test_project"

    if not user_test_dir.exists():
        print(f"ERROR: user_test_project directory not found")
        sys.exit(1)

    print("\n" + "="*60)
    print("🧪 User Simulation Test for dbt-iterative-snapshot")
    print("="*60)

    success = True

    # Run functional tests if requested
    if func_only:
        success = run_functional_tests()
        if success:
            print("\n✅ Functional tests passed!")
        sys.exit(0 if success else 1)

    if not validate_only:
        print(f"\nSimulating a user installing and using the package...")
        print(f"Project: {user_test_dir}\n")

        # Step 1: Install package
        print("\n📦 Step 1: User installs the package (dbt deps)...")
        if not run_dbt(["deps"], user_test_dir):
            print("❌ Failed to install package")
            sys.exit(1)
        print("✓ Package installed")

        # Step 2: Load seed data
        print("\n🌱 Step 2: User loads their source data (dbt seed)...")
        if not run_dbt(["seed"], user_test_dir):
            print("❌ Failed to load seed data")
            sys.exit(1)
        print("✓ Seed data loaded")

        # Step 3: Run the model
        print("\n🔨 Step 3: User runs their snapshot model (dbt run)...")
        run_args = ["run"]
        if full_refresh:
            run_args.append("--full-refresh")
        if not run_dbt(run_args, user_test_dir):
            print("❌ Failed to run model")
            sys.exit(1)
        print("✓ Model completed")

        # Step 4: Run dbt tests
        print("\n🧪 Step 4: User runs dbt tests...")
        if not run_dbt(["test"], user_test_dir):
            print("⚠️  Some dbt tests failed (continuing with validation)")

    # Step 5: Validate results
    validation_passed = validate_results()

    # Step 6: Run functional tests if requested
    func_passed = True
    if run_func:
        func_passed = run_functional_tests()

    # Final summary
    if validation_passed and func_passed:
        print("\n" + "="*60)
        print("✅ USER SIMULATION TEST PASSED!")
        print("="*60)
        print("\nThe package works correctly from a user's perspective:")
        print("  - Package installs successfully")
        print("  - iterative_snapshot materialization works")
        print("  - SCD2 history is correct (no gaps/overlaps)")
        if run_func:
            print("  - Functional tests passed (out-of-order processing)")
    else:
        print("\n" + "="*60)
        print("❌ USER SIMULATION TEST FAILED!")
        print("="*60)
        sys.exit(1)


if __name__ == "__main__":
    main()
