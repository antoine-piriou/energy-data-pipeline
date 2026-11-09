-- =============================================================================
-- 01_load.sql: load the eCO2mix CSV into the database
-- Prerequisites: sql/00_schema.sql executed, CSV present in data/
-- Usage (from the repository root, connected to the energy database):
--     \i sql/01_load.sql
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Raw CSV -> staging table
--    \copy (psql) reads the file on the client machine, path relative to the
--    directory psql was started from. COPY (SQL) would read it server-side.
-- -----------------------------------------------------------------------------
TRUNCATE eco2mix_staging;

\copy eco2mix_staging FROM 'data/eco2mix-national-cons-def.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8')

-- Expected: 35,136 rows (366 days x 96 steps of 15 min)
SELECT count(*) AS staging_rows FROM eco2mix_staging;


-- -----------------------------------------------------------------------------
-- 2. staging -> clean table eco2mix
-- -----------------------------------------------------------------------------
-- Documented choices:
--   * 30-min time step: hh:15 / hh:45 rows have neither consumption nor
--     generation (only commercial exchanges), so they are dropped.
--   * Duplicates on 2024-03-31 (switch to summer time, 02:xx does not exist):
--     RTE added rows with local time 02:00 / 02:30 converted to 03:00 / 03:30+02.
--     We keep the row whose local time matches the actual local time.
--   * Empty values -> NULL (not measured), never 0.
TRUNCATE eco2mix;

INSERT INTO eco2mix (
    ts,
    consumption_mw, forecast_d1_mw, forecast_d_mw,
    fuel_oil_mw, coal_mw, gas_mw, nuclear_mw, wind_mw, solar_mw,
    hydro_mw, pumping_mw, bioenergy_mw,
    physical_exchanges_mw, comm_exch_gb_mw, comm_exch_spain_mw,
    comm_exch_italy_mw, comm_exch_switzerland_mw, comm_exch_germany_belgium_mw,
    co2_intensity_g_kwh
)
SELECT
    datetime::timestamptz,
    consumption::integer, forecast_d1::integer, forecast_d::integer,
    fuel_oil::integer, coal::integer, gas::integer, nuclear::integer,
    wind::integer, solar::integer,
    hydro::integer, pumping::integer, bioenergy::integer,
    physical_exchanges::integer, comm_exch_gb::integer, comm_exch_spain::integer,
    comm_exch_italy::integer, comm_exch_switzerland::integer, comm_exch_germany_belgium::integer,
    co2_intensity::integer
FROM eco2mix_staging
WHERE consumption IS NOT NULL                    -- 30-min steps only
  AND substr(datetime, 12, 5) = local_time;      -- drops the fake 02:xx rows of 2024-03-31


-- -----------------------------------------------------------------------------
-- 3. Checks
-- -----------------------------------------------------------------------------
-- Expected: 17,566 = 366 d x 48 steps (17,568) - 2 steps missing from the file
--           (02:00 and 02:30 summer time on 2024-10-27, switch to winter time)
SELECT count(*) AS nb_rows FROM eco2mix;

-- Expected: 2024-01-01 00:00 -> 2024-12-31 23:30, Paris time
SELECT min(ts AT TIME ZONE 'Europe/Paris') AS first_step,
       max(ts AT TIME ZONE 'Europe/Paris') AS last_step
FROM eco2mix;

-- Expected: 0
SELECT count(*) AS null_consumption FROM eco2mix WHERE consumption_mw IS NULL;
