-- =============================================================================
-- Q4 - Consumption change from one step to the next, and steepest ramp of the year
-- Target concept: LAG()
--
-- Goal            : Compute the consumption change between each 30-min step and
--                   the previous one (CTE "change"), then return the steepest
--                   upward ramp of 2024.
-- Assumptions     :
--   * Change = consumption(t) - consumption(t - 1 step), in MW per 30 min.
--   * Steps are ordered on ts (UTC), not on local time: on 2024-10-27 the local
--     02:00-03:00 hour occurs twice, local time alone is ambiguous. Paris time
--     is used for display only.
--   * LAG() takes the previous row, not "30 min earlier". Rows following a gap
--     (2 missing steps on 2024-10-27) would compare values 1h30 apart, so only
--     changes with step_gap = 30 minutes are kept. This also drops the first
--     row of the year (no previous step, NULL change).
--   * "Steepest ramp" = largest increase. The steepest decrease can be obtained
--     with ORDER BY ... ASC (expected: -3,820 MW on 2024-10-27 at 03:00, a real
--     30-min step in winter time).
-- Expected result : 1 row: 2024-01-08 06:30 (Paris time), +3,720 MW
--                   (Monday morning in winter: heating and activity start).
--
-- Usage: \i sql/queries/q04_consumption_ramps.sql
-- =============================================================================

WITH change AS (
    SELECT
        ts AT TIME ZONE 'Europe/Paris'                          AS time,
        ts - LAG(ts) OVER (ORDER BY ts)                         AS step_gap,
        consumption_mw - LAG(consumption_mw) OVER (ORDER BY ts) AS consumption_change
    FROM eco2mix
)
SELECT
    time,
    consumption_change AS steepest_ramp
FROM change
WHERE step_gap = INTERVAL '30 minutes'
  AND consumption_change IS NOT NULL
ORDER BY consumption_change DESC
LIMIT 1;
