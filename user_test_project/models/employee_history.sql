-- User's model using the iterative_snapshot materialization
-- This is exactly how a real user would configure their model

{{
    config(
        materialized='iterative_snapshot',
        unique_key='employee_id',
        updated_at='modified_date',
        sequence_by='file_date',
        strategy='check',
        check_cols=['name', 'department', 'salary', 'status']
    )
}}

SELECT
    employee_id,
    name,
    department,
    salary,
    status,
    CAST(modified_date AS TIMESTAMP) AS modified_date,
    CAST(file_date AS DATE) AS file_date
FROM {{ ref('raw_employee_exports') }}
