class IterativeSnapshot:
    """
    A class to manage SQL operations related to iterative snapshots, such as dropping, truncating,
    and generating queries for source, snapshot, meta, and error tables.
    """

    def __init__(self, adapter, catalog, schema, source_table, snapshot_table, meta_table, error_table):
        """
        Initialize the class with necessary table and schema details.

        Args:
            catalog (str): The catalog name.
            schema (str): The schema name.
            source_table (str): The source table name.
            snapshot_table (str): The snapshot table name.
            meta_table (str): The meta table name.
            error_table (str): The error table name.
        """
        self.adapter = adapter
        self.catalog = catalog
        self.schema = schema
        self.source_table = source_table
        self.snapshot_table = snapshot_table
        self.meta_table = meta_table
        self.error_table = error_table

    @staticmethod
    def create_source_dbt_model():
        return """
        {{ config(
            materialized='table',
            tags=['source']
            )
        }}

        SELECT
            CAST(null as string) AS uk1,
            CAST(null as string) AS uk2,
            CAST(null as string) AS attribute1,
            CAST(null as string) AS attribute2,
            CAST(null as string) AS file_name,
            CAST(null as timestamp) AS file_datetime
        WHERE False
        """

    @staticmethod
    def create_snapshot_dbt_model(table_name,metadata_table,error_log_table):
        return f"""
        {{{{ config(
            materialized='iterative_snapshot',
            tags=['snapshot'],
            strategy='check',
            updated_at='file_datetime',
            invalidate_hard_deletes=True,
            check_cols=["attribute1","attribute2"],
            unique_key=["uk1","uk2"],
            sequence_by="file_name",
            metadata_table_name='{metadata_table}',
            error_log_table_name='{error_log_table}'
            )
        }}}}


        SELECT * FROM  {{{{ ref('{table_name}') }}}}
        """


    def _format_sql(self, sql):
        """
        Helper method to format SQL queries for consistency.

        Args:
            sql (str): SQL string to format.

        Returns:
            str: Formatted SQL string.
        """
        return sql.strip()

    def drop_table(self, table_name):
        """
        Generate a SQL query to drop a table if it exists.

        Args:
            table_name (str): The table name to drop.

        Returns:
            str: SQL query to drop the table.
        """
        return self._format_sql(f"DROP TABLE IF EXISTS `{self.catalog}`.`{self.schema}`.`{table_name}`;")
    
    def truncate_table(self, table_name):
        """
        Generate a SQL query to truncate a table.

        Args:
            table_name (str): The table name to truncate.

        Returns:
            str: SQL query to truncate the table.
        """
        return self._format_sql(f"TRUNCATE TABLE `{self.catalog}`.`{self.schema}`.`{table_name}`;")
    

    def insert_values(self, values):
        formatted_values = []
        
        for row in values:
            formatted_row = ", ".join([f"'{v}'" if v is not None else 'NULL' for v in row])
            formatted_values.append(f"({formatted_row})")

        # Join all formatted rows with a comma
        formatted_values = ",\n".join(formatted_values)

        return f"INSERT INTO `{self.catalog}`.`{self.schema}`.`{self.source_table}` VALUES {formatted_values};"


    def generate_actual_sql(self):
        return f"""
        SELECT
            uk1,
            uk2,
            attribute1,
            attribute2,
            file_name,
            file_datetime,
            dbt_valid_from,
            to_date(dbt_valid_to) as dbt_valid_to,
            dbt_change_type
        FROM  `{self.catalog}`.`{self.schema}`.`{self.snapshot_table}`
            order by uk1,file_datetime
        """.strip()

    
    def generate_expected_sql(self,values):
        rows = []
        for val in values:
            uk1, uk2, attribute1, attribute2, file_name, file_datetime, dbt_valid_from, dbt_valid_to, dbt_change_type = val
            row = f"""
            SELECT
                '{uk1}' AS uk1,
                '{uk2}' AS uk2,
                '{attribute1}' AS attribute1,
                '{attribute2}' AS attribute2,
                '{file_name}' AS file_name,
                TRY_TO_TIMESTAMP('{file_datetime}') AS file_datetime,
                TRY_TO_TIMESTAMP('{dbt_valid_from}') AS dbt_valid_from,
                {f"TO_DATE('{dbt_valid_to}')" if dbt_valid_to else "NULL"} AS dbt_valid_to,
                '{dbt_change_type}' AS dbt_change_type
            """
            rows.append(row.strip())

        sql = " UNION ALL\n".join(rows)
        return sql.strip()