-- =============================================================================
-- Q8 - Gaps in the data (missing time steps)
-- Target concept: generate_series + LEFT JOIN
--
-- Goal            : List the 30-min time steps of 2024 that have no row in
--                   eco2mix (gaps in the data).
-- Assumptions     :
--   * A missing row cannot be selected, so the full calendar of expected steps
--     is built with generate_series, then compared to eco2mix with a LEFT JOIN
--     (anti-join): steps of the series with no match are the gaps.
--   * Series bounds = MIN(ts) and MAX(ts) of eco2mix (2024-01-01 00:00 ->
--     2024-12-31 23:30, Paris time). A gap at the very start or end of the year
--     would not be detected.
--   * Series and join use timestamptz (absolute instants): adding
--     '30 minutes' is always 30 real minutes, so DST changes need no special
--     handling (48 steps per UTC day, 17,568 for 2024, a leap year). Local time
--     is only used for display.
--   * The test is on eco2mix.ts IS NULL: ts is the primary key, never NULL in a
--     real row, so NULL means "no match". A nullable column (e.g. coal_mw)
--     would also catch existing rows.
-- Expected result : 2 rows: 2024-10-27 02:00 and 02:30 (Paris time), the
--                   02:00-03:00 hour repeated by the switch to winter time.
--                   17,568 expected - 17,566 loaded = 2. These steps (summer
--                   time, +02) are absent from the RTE source file itself (see
--                   sql/01_load.sql): a limit of the source, not of the load.
--                   No gap on 2024-03-31: the skipped local hour does not exist
--                   on the UTC timeline.
--
-- Usage: \i sql/queries/q08_missing_steps.sql
-- =============================================================================
WITH normal_ts AS (SELECT * FROM generate_series((SELECT MIN(ts) FROM eco2mix), (SELECT MAX(ts) FROM eco2mix), interval '30 minutes') AS s(ts))
SELECT normal_ts.ts AT TIME ZONE 'Europe/Paris' FROM normal_ts LEFT JOIN eco2mix ON normal_ts.ts=eco2mix.ts
WHERE eco2mix.ts IS NULL
ORDER BY normal_ts.ts;
