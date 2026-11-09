-- =============================================================================
-- Q1 - Daily consumption peak (value and time)
-- Target concept: RANK() / ROW_NUMBER() per day
--
-- Goal            : For each day of 2024, return the highest consumption step
--                   and the time it occurred.
-- Assumptions     : Days are Paris local days (the 23 h and 25 h DST days are
--                   handled naturally). ROW_NUMBER() rather than RANK(): one row
--                   per day even if two steps tie for the peak.
-- Expected result : 366 rows, one per day. Winter peaks around 19:30
--                   (yearly max ~85 GW on 2024-01-10), summer peaks around
--                   13:00 (lowest daily peak ~42 GW in mid-August).
--
-- Usage: \i sql/queries/q01_daily_peak.sql
-- =============================================================================

SELECT
    ts AT TIME ZONE 'Europe/Paris' AS peak_time,
    consumption_mw                 AS peak_mw
FROM (
    SELECT
        ts,
        consumption_mw,
        ROW_NUMBER() OVER (
            PARTITION BY (ts AT TIME ZONE 'Europe/Paris')::date
            ORDER BY consumption_mw DESC
        ) AS rank_in_day
    FROM eco2mix
) AS ranked
WHERE rank_in_day = 1
ORDER BY ts;
