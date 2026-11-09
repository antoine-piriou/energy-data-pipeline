-- =============================================================================
-- Q3 - Share of renewables in generation, by month
-- Target concept: CTE + aggregation
--
-- Goal            : For each month of 2024, the share of renewable sources in
--                   total French generation, in %.
-- Assumptions     :
--   * Renewables = wind + solar + hydro + bioenergy.
--   * Total generation = fuel oil + coal + gas + nuclear + wind + solar + hydro
--     + bioenergy. Consumption is NOT the denominator: France was a large net
--     exporter in 2024, so dividing by consumption would overstate the share.
--   * Pumping (pumping_mw) is excluded from both sides: it is negative and is
--     electricity consumed by pumped-storage plants, not generation.
--   * hydro_mw includes pumped-storage turbining, which is not strictly
--     renewable; it cannot be separated with the kept columns, so it is counted.
--   * Months are Paris local months.
--   * MW summed over 30-min steps is not energy (x 0.5 h for MWh), but the
--     factor cancels out in a ratio, so the share is correct.
--   * No NULL in generation columns for 2024 (checked), so plain + is safe.
-- Expected result : 12 rows (month, share in %). Between ~24 % (November) and
--                   ~34 % (April); higher in spring (hydro + solar), lower in
--                   late autumn and winter.
--
-- Usage: \i sql/queries/q03_monthly_renewable_share.sql
-- =============================================================================

WITH monthly AS (
    -- Step 1: one row per month, with renewable and total generation summed
    SELECT
        date_trunc('month', ts AT TIME ZONE 'Europe/Paris') AS month,
        SUM(wind_mw + solar_mw + hydro_mw + bioenergy_mw)   AS renewable_mw_sum,
        SUM(fuel_oil_mw + coal_mw + gas_mw + nuclear_mw
            + wind_mw + solar_mw + hydro_mw + bioenergy_mw) AS generation_mw_sum
    FROM eco2mix
    GROUP BY date_trunc('month', ts AT TIME ZONE 'Europe/Paris')
)
-- Step 2: compute the share from the monthly sums
SELECT
    month::date                                           AS month,
    round(100.0 * renewable_mw_sum / generation_mw_sum, 1) AS renewable_share_pct
FROM monthly
ORDER BY month;
