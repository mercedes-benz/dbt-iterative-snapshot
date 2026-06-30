#!/usr/bin/env python3
"""
Test runner for dbt-iterative-snapshot.

Usage:
    python run_tests.py              # Run all tests (dbt + functional)
    python run_tests.py --dbt-only   # Only run dbt integration tests
    python run_tests.py --func-only  # Only run pytest functional tests
    python run_tests.py --skip-seed  # Skip seeding, run models + tests only
    python run_tests.py --full-refresh  # Full refresh all models
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
        print("Copy .env.example to .env and fill in your Databricks credentials:")
        print("  cp .env.example .env")
        sys.exit(1)

    with open(env_file) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                os.environ[key.strip()] = value.strip()

    # Validate required vars
    required = ["DBT_DATABRICKS_HOST", "DBT_DATABRICKS_HTTP_PATH",
                "DBT_DATABRICKS_TOKEN", "DBT_DATABRICKS_CATALOG"]
    missing = [v for v in required if not os.environ.get(v)]

    if missing:
        print(f"ERROR: Missing required environment variables: {', '.join(missing)}")
        sys.exit(1)

    print(f"✓ Loaded credentials for: {os.environ['DBT_DATABRICKS_HOST']}")
    print(f"✓ Catalog: {os.environ['DBT_DATABRICKS_CATALOG']}")


def run_dbt(args, cwd):
    """Run a dbt command and return success status."""
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


def run_dbt_tests(skip_seed=False, full_refresh=False):
    """Run dbt integration tests."""
    integration_tests_dir = Path(__file__).parent / "integration_tests"

    if not integration_tests_dir.exists():
        print(f"ERROR: integration_tests directory not found at {integration_tests_dir}")
        return False

    print(f"\n🚀 Running dbt integration tests from: {integration_tests_dir}\n")

    # Step 1: Install dependencies
    print("\n📦 Step 1: Installing dependencies...")
    if not run_dbt(["deps"], integration_tests_dir):
        print("❌ Failed to install dependencies")
        return False
    print("✓ Dependencies installed")

    # Step 2: Load seed data
    if not skip_seed:
        print("\n🌱 Step 2: Loading seed data...")
        if not run_dbt(["seed"], integration_tests_dir):
            print("❌ Failed to load seed data")
            return False
        print("✓ Seed data loaded")

    # Step 3: Run models
    print("\n🔨 Step 3: Running models...")
    run_args = ["run"]
    if full_refresh:
        run_args.append("--full-refresh")

    if not run_dbt(run_args, integration_tests_dir):
        print("❌ Failed to run models")
        return False
    print("✓ Models completed")

    # Step 4: Run tests
    print("\n🧪 Step 4: Running dbt tests...")
    if not run_dbt(["test"], integration_tests_dir):
        print("❌ Some dbt tests failed")
        return False
    print("✓ All dbt tests passed")

    return True


def run_functional_tests():
    """Run pytest functional tests."""
    project_root = Path(__file__).parent
    test_path = "tests/functional/test_iterative_snapshot.py"

    if not (project_root / test_path).exists():
        print(f"ERROR: Functional tests not found at {test_path}")
        return False

    print(f"\n🧪 Running functional tests...\n")

    if not run_pytest(test_path, project_root):
        print("❌ Some functional tests failed")
        return False
    print("✓ All functional tests passed")

    return True


def main():
    # Parse args
    args = sys.argv[1:]
    dbt_only = "--dbt-only" in args
    func_only = "--func-only" in args
    skip_seed = "--skip-seed" in args
    full_refresh = "--full-refresh" in args

    # Load .env
    load_env()

    dbt_success = True
    func_success = True

    # Run dbt tests
    if not func_only:
        dbt_success = run_dbt_tests(skip_seed=skip_seed, full_refresh=full_refresh)

    # Run functional tests
    if not dbt_only:
        func_success = run_functional_tests()

    # Summary
    print("\n" + "="*60)
    if dbt_success and func_success:
        print("✅ All tests completed successfully!")
    else:
        if not dbt_success:
            print("❌ dbt integration tests failed")
        if not func_success:
            print("❌ Functional tests failed")
        sys.exit(1)
    print("="*60)


if __name__ == "__main__":
    main()
