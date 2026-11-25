"""Count the rows of the 2024 eCO2mix backfill.

Run from the repo root: python scripts/count_backfill.py

Prints:
1. the number of 2024 partitions;
2. the total number of data rows (headers excluded);
3. every day whose row count is not 96, with its count.
"""

from pathlib import Path

EXPECTED_ROWS_PER_DAY = 96  # 24 h x 4 quarter-hours

nb_partitions = 0
nb_data_rows = 0
awkward_days = []

for path in sorted(Path("data/raw/source=eco2mix").glob("date=2024-*/data.csv")):
    nb_partitions += 1
    lines = path.read_text(encoding="utf-8").splitlines()
    n_rows = len(lines) - 1  # minus header
    nb_data_rows += n_rows
    if n_rows != EXPECTED_ROWS_PER_DAY:
        awkward_days.append((path.parent.name, n_rows))

print(f"Partitions: {nb_partitions}")
print(f"Data rows:  {nb_data_rows}")
print(f"Days without {EXPECTED_ROWS_PER_DAY} rows:")
for day, n_rows in awkward_days:
    print(f"  {day}: {n_rows}")
