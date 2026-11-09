-- =============================================================================
-- Q7 - Top 10 days with the highest carbon intensity
-- Target concept: CTE + ORDER BY ... LIMIT
--
-- Goal            : The 10 days of 2024 with the highest estimated carbon
--                   intensity of French generation, with RTE's value next to
--                   it as a check.
-- Assumptions     :
--   * Same calculation as Q5 (CTE "long" + emission_factors: 2024 annual
--     factors, direct emissions only, 8 sources, pumping and exchanges
--     excluded), but grouped by day instead of by time step.
--   * Day = calendar date in local time (Europe/Paris).
--   * Estimated intensity = SUM(generation x factor) / SUM(generation) over the
--     day: each step is weighted by its generation (energy-weighted daily
--     intensity), not a plain mean of the 48 step intensities.
--   * RTE column = plain AVG of co2_intensity_g_kwh over the day's steps (each
--     step appears 8 times in "long", once per source, so the mean is not
--     biased). Different weighting from the estimate: small gaps expected.
-- Expected result : 10 rows (day, estimated g/kWh, RTE g/kWh), sorted from the
--                   highest. Obtained: all winter days (Jan, Feb, early Mar,
--                   Dec), 50-56 g/kWh, max 55.8 on 2024-02-28, gap with RTE
--                   <= 2 g/kWh. The 9-16 January cold spell fills 6 of the 10
--                   places. Values stay below the 76.5 g/kWh step peak of Q5
--                   (night and midday lower the daily mean).
--
-- Usage: \i sql/queries/q07_top10_carbon_days.sql
-- =============================================================================

WITH long AS (
    -- Step 1: one row per (time step, source)
    SELECT
        e.ts,
        e.co2_intensity_g_kwh,
        v.source_name,
        v.production_mw
    FROM eco2mix AS e
    CROSS JOIN LATERAL (VALUES
        ('fuel_oil',  e.fuel_oil_mw),
        ('coal',      e.coal_mw),
        ('gas',       e.gas_mw),
        ('nuclear',   e.nuclear_mw),
        ('wind',      e.wind_mw),
        ('solar',     e.solar_mw),
        ('hydro',     e.hydro_mw),
        ('bioenergy', e.bioenergy_mw)
    ) AS v(source_name, production_mw)
)
SELECT
    (long.ts AT TIME ZONE 'Europe/Paris')::date                   AS day,
    round(SUM(long.production_mw * f.factor_g_kwh)
          / SUM(long.production_mw), 1)                    AS estimated_g_kwh,
    round(AVG(long.co2_intensity_g_kwh),1)    AS rte_g_kwh  
FROM long
JOIN emission_factors AS f ON f.source_name = long.source_name
GROUP BY (long.ts AT TIME ZONE 'Europe/Paris')::date
ORDER BY estimated_g_kwh DESC
LIMIT 10;
