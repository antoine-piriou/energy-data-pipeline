# Index benchmark: `EXPLAIN (ANALYZE, BUFFERS)` before and after a B-tree index

## Goal

Measure what a B-tree index changes for a selective query on a column that has
no index, and decide whether the index is worth keeping for this project.

## Context

| Item | Value |
|---|---|
| Table | `eco2mix`, 17,566 rows (2024, 30-min steps) |
| Size | 251 pages of 8 kB, about 2 MB |
| Existing index | `eco2mix_pkey`, B-tree on `ts` (primary key) |
| PostgreSQL | 18, Windows, local machine |
| Cache | All pages already in memory (`shared hit`, no `read`): warm cache |

Script: [`sql/03_index_benchmark.sql`](../sql/03_index_benchmark.sql).

## Measured query

```sql
SELECT count(*) FROM eco2mix WHERE consumption_mw > 85000;
```

Time steps with a consumption above 85 GW (winter peaks). It returns **4 rows out
of 17,566 (0.02 %)**: a very selective filter, the case where an index can help.
`ts` was not used because it is already indexed by the primary key, so there
would be no "before" to measure.

## Protocol

1. `ANALYZE eco2mix` so the planner has up-to-date statistics.
2. Measure without index with `EXPLAIN (ANALYZE, BUFFERS)`, several runs, keep the median.
3. `CREATE INDEX idx_eco2mix_consumption ON eco2mix (consumption_mw)`.
4. `VACUUM ANALYZE eco2mix`. The query only counts rows, so PostgreSQL can answer
   from the index alone (Index Only Scan). It still has to know that every row
   is visible, and that information (visibility map) is set by `VACUUM`. Without
   it, the plan would add heap fetches (trips back to the table) and the
   comparison would be unfair.
5. Measure again with the same query.

Only one variable changes between the two measures: the index.

## Before (no index)

```
 Aggregate  (cost=470.60..470.61 rows=1 width=8) (actual time=0.922..0.922 rows=1.00 loops=1)
   Buffers: shared hit=251
   ->  Seq Scan on eco2mix  (cost=0.00..470.58 rows=8 width=0) (actual time=0.893..0.917 rows=4.00 loops=1)
         Filter: (consumption_mw > 85000)
         Rows Removed by Filter: 17562
         Buffers: shared hit=251
 Planning:
   Buffers: shared hit=3
 Planning Time: 0.139 ms
 Execution Time: 0.943 ms
```

- `Seq Scan`: the whole table is read, row by row.
- `Rows Removed by Filter: 17562`: 17,566 rows examined to keep 4.
- `shared hit=251`: all 251 pages of the table are read.
- The estimate (`rows=8`) is close to the actual value (`rows=4`): the
  statistics are good, so the plan choice is not caused by bad estimates.

## After (index on `consumption_mw`)

```
 Aggregate  (cost=4.45..4.46 rows=1 width=8) (actual time=0.009..0.010 rows=1.00 loops=1)
   Buffers: shared hit=3
   ->  Index Only Scan using idx_eco2mix_consumption on eco2mix  (cost=0.29..4.43 rows=8 width=0) (actual time=0.004..0.005 rows=4.00 loops=1)
         Index Cond: (consumption_mw > 85000)
         Heap Fetches: 0
         Index Searches: 1
         Buffers: shared hit=3
 Planning:
   Buffers: shared hit=7 read=2
 Planning Time: 0.233 ms
 Execution Time: 0.030 ms
```

- `Index Only Scan`: PostgreSQL goes down the B-tree to 85,000 and reads only
  the matching entries; the filter became an `Index Cond`.
- `Heap Fetches: 0`: the table itself is never read, thanks to `VACUUM`.
- `shared hit=3`: 3 index pages instead of 251 table pages.

## Results

| Measure | Before | After | Ratio |
|---|---|---|---|
| Plan | Seq Scan | Index Only Scan | |
| Rows examined then removed | 17,562 | 0 | |
| Pages read (execution) | 251 | 3 | **÷ 84** |
| Execution Time, runs | 0.955 / 0.943 ms | 0.038 ms | |
| Execution Time, retained | 0.943 ms | 0.038 ms | **÷ 25** |
| Planning Time | 0.139 ms | 0.233 ms | × 1.7 |
| Index size | (none) | 384 kB | (none) |

## Conclusion

**On this query, the index divides the pages read by 84 (251 → 3) and the
execution time by about 25 (0.94 ms → 0.04 ms).** PostgreSQL stops reading the
whole table and goes straight to the 4 matching rows.

Limits and decision:

- **Pages are the meaningful figure, not milliseconds.** The table is small and
  fully cached, so times are below 1 ms and dominated by fixed costs. The number
  of pages read, however, grows with the table: on a table 1,000 times bigger,
  the sequential scan would read about 1,000 times more pages, while the index
  would still read only a few.
- **Planning time went up** (0.14 → 0.23 ms): the planner has one more index to
  consider. On such a fast query, planning now costs more than execution.
  Negligible here, but not free.
- **The gain only exists because the filter is selective** (0.02 % of the rows).
  For a filter keeping a large share of the table, PostgreSQL would keep the
  sequential scan even with the index, because reading the table in order is
  cheaper than jumping between index and table.
- **This index helps none of the project queries Q1 to Q8.** They all aggregate
  over the whole year (daily peaks, rolling averages, monthly shares, seasonal
  profiles...), so they must read every row anyway. Q7's `LIMIT 10` does not
  help either: it applies after the daily aggregation.
- **An index has a cost:** disk space, and every `INSERT`/`UPDATE` must also
  update the index, which slows down loading.

**Decision: do not keep `idx_eco2mix_consumption` for this project.** It would
only be worth it if queries regularly filtered on rare consumption values (for
example an alert on peaks above a threshold). The primary key index on `ts` is
enough for the time-range filters the pipeline needs.
