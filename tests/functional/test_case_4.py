"""   handle back fill with older files

Scope: We want to test snapshots that load multiple files at once. One file should have no changes. 
Snapshots should be run twice and 20_clean table checked after each run, to check how the "no change" file is handled.

Scope: We want to test how the Snapshot logic behaves if multiple files are loaded that are older that the current file in the 20_Clean table. The logic should recalculate the correct stages and update the current.

Expectation:

u_key 1 : gets no changes so it will show data valid_from 2024-10-01  ; valid_to NULL

u_key 2 : is updated from valid_from 2024-10-01 ; valid_to 2024-10-02 to valid_from 2024-10-02 ; valid_to NULL

u_key 3 : is deleted and shows valid_to to current time

u_key 4 : is updated from valid_from 2024-10-01 ; valid_to 2024-10-02 to valid_from 2024-10-02 ; valid_to NULL


"""
from datetime import datetime
import pytz

t4_insert_batch_1 = [
('1','U1','A','A1','file3','2024-01-01'),
('2','U2','B','B1','file3','2024-01-01'),
('4','U4','D','D1','file3','2024-01-01')
]


t4_insert_batch_2 = [
('1','U1','A','A1','file1','2023-12-01'),
('2','U2','X','X1','file1','2023-12-01'),
('3','U3','Y','Y1','file1','2023-12-01'),


('1','U1','A','A1','file2','2023-12-02'),
('2','U2','B','B1','file2','2023-12-02'),
('4','U4','Z','Z1','file2','2023-12-02')
]


t4_expected_result_1 = [
("1", "U1", "A", "A1", "file1", "2023-12-01", "2023-12-01", None, "insert"),
("2", "U2", "X", "X1", "file1", "2023-12-01", "2023-12-01", "2023-12-02", "update"),
("2", "U2", "B", "B1", "file2", "2023-12-02", "2023-12-02", None, "insert"),
("3", "U3", "Y", "Y1", "file1", "2023-12-01", "2023-12-01", f"{datetime.now(pytz.utc).date()}" , "delete"),
("4", "U4", "Z", "Z1", "file2", "2023-12-02", "2023-12-02", "2024-01-01" , "update"),
("4", "U4", "D", "D1", "file3", "2024-01-01", "2024-01-01", None , "insert"),

]

