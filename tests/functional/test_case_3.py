# SPDX-License-Identifier: MIT
# Copyright (c) 2024 Mercedes-Benz Group AG
"""  load multiple files at once - same change tracking value
Scope: We want to test snapshots that load multiple files at once. One file should have no changes.
Snapshots should be run twice and 20_clean table checked after each run, to check how the "no change" file is handled.

We use 2 u_keys for 4 different days (2024-01-01; 2024-01-05; 2024-01-06; 2024-01-07)

Expectations:

u_key 2 current entry only for 2024-01-01
u_key 1 closed entry for 2024-01-01 till 2024-01-05
u_key 1 closed entry for 2024-01-06 till 2024-01-07
u_key 1 current entry on 2024-01-07

"""
from datetime import datetime
import pytz

t3_insert_batch_1 = [
('1','U1','A','A1','file1','2024-01-01'),
('2','U2','B','B1','file1','2024-01-01'),


('1','U1','X','X1','file2','2024-01-05'),
('2','U2','B','B1','file2','2024-01-05'),

('1','U1','X','X1','file3','2024-01-06'),
('2','U2','B','B1','file3','2024-01-06'),

('1','U1','A','A1','file4','2024-01-07'),
('2','U2','B','B1','file4','2024-01-07')
]



t3_expected_result_1 = [
("1", "U1", "A", "A1","file1", "2024-01-01", "2024-01-01", "2024-01-05", "update"),
("1", "U1", "X", "X1","file2", "2024-01-05", "2024-01-05", "2024-01-07", "update"),
("1", "U1", "A", "A1","file4", "2024-01-07", "2024-01-07", None, "insert"),
("2", "U2", "B", "B1","file1", "2024-01-01", "2024-01-01", None, "insert")]

