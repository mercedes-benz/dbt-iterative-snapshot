"""   Test 'backing_table' scenario: Out of order file older than 60 days

Scope: Out of order logic with files older than 60 days

Expectations:

uk_1 : is updated from valid_from 2023-10-01 ; valid_to 2024-10-01 to valid_from 2024-10-01 ; valid_to NULL
uk_2 : is updated from valid_from 2023-10-01 ; valid_to 2024-10-02 to valid_from 2024-10-02 ; valid_to NULL
uk_3 : is deleted and valid_to current time
uk_4 : is active from 2024-01-02

"""
from datetime import datetime
import pytz

t6_insert_batch_1 = [
('1','U1','A','A1','file1','2024-01-01'),
('2','U2','B','B1','file1','2024-01-01'),
('3','U3','C','C1','file1','2024-01-01'),

('1','U1','A','A1','file2','2024-01-02'),
('2','U2','X','X1','file2','2024-01-02'),

('4','U4','D','D1','file2','2024-01-02')
]


t6_insert_batch_2 = [
('1','U1','Z','Z1','file0','2023-01-01')
]




t6_expected_result_1 = [
("1", "U1", "Z", "Z1", "file0", "2023-01-01", "2023-01-01", "2024-01-01", "update"),
("1", "U1", "A", "A1", "file1", "2024-01-01", "2024-01-01", None, "insert"),
("2", "U2", "B", "B1", "file1", "2024-01-01", "2024-01-01", "2024-01-02", "update"),
("2", "U2", "X", "X1", "file2", "2024-01-02", "2024-01-02", None, "insert"),
("3", "U3", "C", "C1", "file1", "2024-01-01", "2024-01-01", f"{datetime.now(pytz.utc).date()}", "delete"),
("4", "U4", "D", "D1", "file2", "2024-01-02", "2024-01-02", None, "insert"),
]
