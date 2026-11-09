-- =============================================================================
-- Q2 - 7-day rolling average consumption
-- Target concept: AVG() OVER (... ROWS BETWEEN ...)
--
-- Goal            : For each day, the average consumption over that day and the
--                   6 previous days, to smooth out the weekly (weekend) pattern.
-- Assumptions     : Computed per day, not per 30-min step: daily means first
--                   (Paris local days), then a 7-row window over those 366 rows.
--                   One row = one day, so ROWS 6 PRECEDING = exactly 7 days
--                   (the 2 missing steps of 2024-10-27 only slightly affect that
--                   day's mean). The first 6 days of 2024 average fewer than
--                   7 days (1 to 6), they are kept as is.
-- Expected result : 366 rows (day, rolling average in MW). 2024-01-01 equals its
--                   own daily mean (~51.6 GW). Max ~74.7 GW around 2024-01-14,
--                   min ~39.6 GW around 2024-08-20.
--
-- Usage: \i sql/queries/q02_rolling_avg_7d.sql
-- =============================================================================

SELECT
    day,
    round(AVG(daily_mean_mw) OVER (
        ORDER BY day
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    )) AS rolling_avg_7d_mw
FROM (
    SELECT
        (ts AT TIME ZONE 'Europe/Paris')::date AS day,
        AVG(consumption_mw)                    AS daily_mean_mw
    FROM eco2mix
    GROUP BY (ts AT TIME ZONE 'Europe/Paris')::date
) AS daily
ORDER BY day;
