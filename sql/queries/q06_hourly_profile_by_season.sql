-- =============================================================================
-- Q6 - Typical day: average hourly profile for each season
-- Target concept: EXTRACT, GROUP BY
--
-- Goal            : For each season, the average consumption at each hour of
--                   the day (a "typical day"), to compare daily shapes between
--                   seasons.
-- Assumptions     :
--   * Hours and months are taken in local time (Europe/Paris), since daily
--     habits follow the clock, not UTC.
--   * Meteorological seasons, by whole months: winter = Dec-Jan-Feb,
--     spring = Mar-Apr-May, summer = Jun-Jul-Aug, autumn = Sep-Oct-Nov.
--     Winter mixes January-February 2024 with December 2024 (single year).
--   * Each hour averages its two 30-min steps over every day of the season.
--     DST change days add or drop a step, which is negligible in the average.
--   * season_order gives a logical sort (winter -> autumn); sorting on the
--     text would give the alphabetical order (autumn, spring, summer, winter).
-- Expected result : 96 rows (4 seasons x 24 hours), in MW. Winter is the
--                   highest season, with a morning rise and an evening peak
--                   around 19:00 (heating + lighting); summer is the lowest and
--                   flattest. Lowest values of each season in the early
--                   morning (around 04:00-05:00).
--
-- Usage: \i sql/queries/q06_hourly_profile_by_season.sql
-- =============================================================================

WITH seasonal_eco2mix AS (
    -- Step 1: one row per time step, with its season and local hour
    SELECT
        CASE
            WHEN EXTRACT(month FROM ts AT TIME ZONE 'Europe/Paris') IN (12, 1, 2)  THEN 'winter'
            WHEN EXTRACT(month FROM ts AT TIME ZONE 'Europe/Paris') IN (3, 4, 5)   THEN 'spring'
            WHEN EXTRACT(month FROM ts AT TIME ZONE 'Europe/Paris') IN (6, 7, 8)   THEN 'summer'
            WHEN EXTRACT(month FROM ts AT TIME ZONE 'Europe/Paris') IN (9, 10, 11) THEN 'autumn'
        END                                              AS season,
        CASE
            WHEN EXTRACT(month FROM ts AT TIME ZONE 'Europe/Paris') IN (12, 1, 2)  THEN 1
            WHEN EXTRACT(month FROM ts AT TIME ZONE 'Europe/Paris') IN (3, 4, 5)   THEN 2
            WHEN EXTRACT(month FROM ts AT TIME ZONE 'Europe/Paris') IN (6, 7, 8)   THEN 3
            WHEN EXTRACT(month FROM ts AT TIME ZONE 'Europe/Paris') IN (9, 10, 11) THEN 4
        END                                              AS season_order,
        EXTRACT(hour FROM ts AT TIME ZONE 'Europe/Paris') AS hour,
        consumption_mw
    FROM eco2mix
)
-- Step 2: one row per (season, hour)
SELECT
    season,
    hour,
    round(AVG(consumption_mw)) AS avg_consumption_mw
FROM seasonal_eco2mix
GROUP BY season_order, season, hour
ORDER BY season_order, hour;
