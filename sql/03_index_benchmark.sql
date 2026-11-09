-- =============================================================================
-- 03_index_benchmark.sql: measure one query before and after a B-tree index
-- Results and conclusion: docs/index-benchmark.md
-- Usage (connected to the energy database):
--     \i sql/03_index_benchmark.sql
-- Run the EXPLAIN lines several times and keep the median Execution Time.
-- =============================================================================

-- Start from a table without the index, so the script can be rerun
DROP INDEX IF EXISTS idx_eco2mix_consumption;

-- Context: table size
SELECT count(*) AS nb_rows,
       pg_size_pretty(pg_relation_size('eco2mix')) AS table_size
FROM eco2mix;

-- Up-to-date statistics for the planner
ANALYZE eco2mix;

-- BEFORE: no index on consumption_mw -> full table scan expected
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) FROM eco2mix WHERE consumption_mw > 85000;

-- Index on the filtered column
CREATE INDEX idx_eco2mix_consumption ON eco2mix (consumption_mw);

-- VACUUM sets the visibility map, so an Index Only Scan needs no heap fetches;
-- ANALYZE refreshes the statistics
VACUUM ANALYZE eco2mix;

-- AFTER: same query
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) FROM eco2mix WHERE consumption_mw > 85000;

-- Cost of the index: disk space
SELECT pg_size_pretty(pg_relation_size('idx_eco2mix_consumption')) AS index_size;
