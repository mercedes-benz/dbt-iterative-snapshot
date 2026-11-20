# SPDX-License-Identifier: MIT
# Copyright (c) 2024 Mercedes-Benz Group AG
"""   Reappearing record across multiple sequences

Scope: We want to test a u_key that is deleted from the source and becomes active again. This is the scenario
the SCD2 validity consistency check repairs. file2 and file3 are loaded in the same run, so a single run
processes multiple sequences.

u_key 1 : present in file1, missing from file2 (hard delete), back with new values in file3
u_key 2 : present in every file, updated in file3

Expectation:

u_key 1 : the closed file1 version is followed directly by the reappeared file3 version (no gap in the timeline),
          current version has attribute1 = 'Z'
u_key 2 : file1 version closed when file3 is loaded, current version has attribute1 = 'Y'

"""

t7_insert_batch_1 = [
('1','U1','A','A1','file1','2024-01-01'),
('2','U2','B','B1','file1','2024-01-01')
]


t7_insert_batch_2 = [
('2','U2','B','B1','file2','2024-01-02'),

('1','U1','Z','Z1','file3','2024-01-03'),
('2','U2','Y','Y1','file3','2024-01-03')
]


# Current (dbt_valid_to IS NULL) attribute1 per u_key after both runs
t7_expected_current = {
    ('1', 'U1'): 'Z',
    ('2', 'U2'): 'Y',
}
