# SPDX-License-Identifier: MIT
# Copyright (c) 2024 Mercedes-Benz Group AG
"""   Loading new records after retention period

Scope: We want to test how the Snapshot logic behaves if u_keys are not present in raw layer anymore due to retention period.

u_key 2 is deleted from source on 2024-01-02. 
After retention period u_key 2 will not be present in the raw table anymore.

Expectation: 

u_key 2 : is deleted and shows valid_to to current time
u_key 3 : is updated from valid_from 2024-10-01 ; valid_to 2024-10-02 to valid_from 2024-10-02 ; valid_to NULL
other keys no change

"""
from datetime import datetime
import pytz

t5_insert_batch_1 = [
('1','U1','A','A1','file1','2024-01-01'),
('2','U2','B','B1','file1','2024-01-01'),
('3','U3','C','C1','file1','2024-01-01')
]


t5_insert_batch_2 = [
('1','U1','A','A1','file2','2024-01-02'),

('3','U3','X','X1','file2','2024-01-02'),
('4','U4','D','D1','file2','2024-01-02')
]


t5_insert_batch_3 = [
('1','U1','A','A1','file3','2024-01-03'),

('3','U3','X','X1','file3','2024-01-03'),
('4','U4','D','D1','file3','2024-01-03'),
('5','U5','E','E1','file3','2024-01-03') 
]


t5_expected_result_1 = [
("1", "U1", "A", "A1", "file1", "2024-01-01", "2024-01-01", None, "insert"),
("2", "U2", "B", "B1", "file1", "2024-01-01", "2024-01-01", f"{datetime.now(pytz.utc).date()}", "delete"),
("3", "U3", "C", "C1", "file1", "2024-01-01", "2024-01-01", "2024-01-02", "update"),
("3", "U3", "X", "X1", "file2", "2024-01-02", "2024-01-02", None, "insert"),
("4", "U4", "D", "D1", "file2", "2024-01-02", "2024-01-02", None, "insert"),
("5", "U5", "E", "E1", "file3", "2024-01-03", "2024-01-03", None, "insert"),
]
