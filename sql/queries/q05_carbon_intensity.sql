-- =============================================================================
-- Q5 - Estimated carbon intensity (gCO2e/kWh) per time step
-- Target concept: CTE, join with emission_factors
--
-- Goal            : For each 30-min step of 2024, estimate the carbon intensity
--                   of French generation: SUM(generation x factor) / total
--                   generation, and show RTE's own value next to it.
-- Assumptions     :
--   * Factors come from emission_factors (sql/02_emission_factors.sql): 2024
--     annual factors derived from RTE monthly emissions, direct emissions only
--     (combustion in French thermal plants, no lifecycle, no imports). Same
--     definition as RTE's co2_intensity_g_kwh, so the two can be compared.
--   * Annual factors are applied to every step, while RTE applies its own
--     factors step by step: small differences are expected.
--   * Denominator = total generation of the 8 sources (as in Q3), pumping
--     excluded, imports/exports excluded (consumption is not used).
--   * eco2mix has one column per source and emission_factors one row per
--     source: the CTE "long" unpivots eco2mix (CROSS JOIN LATERAL VALUES) into
--     one row per (step, source) so both can be joined.
--   * MW x g/kWh summed then divided by MW: the time unit cancels out, the
--     ratio is directly in g/kWh.
-- Expected result : 17,566 rows (time, estimated intensity, RTE intensity).
--                   Yearly mean ~19 g/kWh for both, mean absolute gap ~1 g/kWh.
--                   Lowest ~7 g/kWh on summer middays (solar, no gas), highest
--                   ~75 g/kWh on winter evenings (gas and coal running).
--
-- Usage: \i sql/queries/q05_carbon_intensity.sql
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
-- Step 2: join the factors, then one row per time step
SELECT
    long.ts AT TIME ZONE 'Europe/Paris'                   AS time,
    round(SUM(long.production_mw * f.factor_g_kwh)
          / SUM(long.production_mw), 1)                    AS estimated_g_kwh,
    MAX(long.co2_intensity_g_kwh)                         AS rte_g_kwh
FROM long
JOIN emission_factors AS f ON f.source_name = long.source_name
GROUP BY long.ts
ORDER BY long.ts;
