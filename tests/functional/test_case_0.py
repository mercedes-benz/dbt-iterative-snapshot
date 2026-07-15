# SPDX-License-Identifier: MIT
# Copyright (c) 2024 Mercedes-Benz Group AG
""" regular snapshot load
Scope:

We load 1st file of data with 3 u_key values to 10_raw for 2024-01-01
We load the snapshot to create base history in 20_clean
We load 2nd file from 2024-01-02: no change (u_key 1), update (u_key 2) in 2024-01-02,
missing (u_key 3) for 2024-01-02, insert (u_key 4)
Expectations:

u_key 1 no changes
u_key 2 updated row and new row valid_from=2024-01-01
u_key 3 valid_from 2024-09-01 and is_deleted activated for 2024-01-01
u_key 4 new row inserted valid_from=2024-01-01

"""
from datetime import datetime
import pytz

t0_insert_batch_1 = [
('1','U1','A','A1','file1','2024-01-01'),
('2','U2','B','B1','file1','2024-01-01'),
('3','U3','C','C1','file1','2024-01-01')
]

t0_insert_batch_2 = [	
('1','U1','A','A1','file2','2024-01-02'),
('2','U2','Z','Z1','file2','2024-01-02'),
('4','U4','D','D1','file2','2024-01-02')
]

t0_expected_result_1 = [
("1","U1", "A","A1", "file1", "2024-01-01", "2024-01-01", None, "insert"),
("2","U2", "B","B1", "file1", "2024-01-01", "2024-01-01", "2024-01-02", "update"),
("2","U2", "Z","Z1", "file2", "2024-01-02", "2024-01-02", None, "insert"),
("3","U3", "C","C1", "file1", "2024-01-01", "2024-01-01", f"{datetime.now(pytz.utc).date()}", "delete"),
("4","U4", "D","D1", "file2", "2024-01-02", "2024-01-02", None, "insert")
]
