-- =============================================================================
-- 02_emission_factors.sql: emission factors by generation source (used by Q5, Q7)
-- Usage (connected to the energy database):
--     \i sql/02_emission_factors.sql
-- Values must come from a cited source (RTE eCO2mix methodology or ADEME),
-- never from memory.
-- =============================================================================

-- This file is UTF-8 and compares accented strings ('Déchets ménagers').
-- On Windows psql defaults to the console code page (WIN1252/850) and would
-- read those literals wrongly, so the match would silently fail.
\encoding UTF8

DROP TABLE IF EXISTS emission_factors;

CREATE TABLE emission_factors (
    source_name    text PRIMARY KEY,   -- same name as the eco2mix column, without _mw (e.g. 'gas')
    factor_g_kwh   numeric NOT NULL,   -- gCO2 emitted per kWh generated
    reference      text    NOT NULL,   -- exact document (title, page or section, URL)
    year           integer NOT NULL    -- publication or validity year of the factor
);

COMMENT ON TABLE emission_factors IS
    'Emission factors by generation source, with their reference.';
COMMENT ON COLUMN emission_factors.source_name IS
    'Generation source, named like the matching eco2mix column without the _mw suffix.';
COMMENT ON COLUMN emission_factors.factor_g_kwh IS
    'Emission factor in gCO2/kWh.';
COMMENT ON COLUMN emission_factors.reference IS
    'Reference of the document the factor comes from.';
COMMENT ON COLUMN emission_factors.year IS
    'Year of the reference.';

-- -----------------------------------------------------------------------------
-- 1. Load the RTE monthly CO2 emissions file (Mt per month and per fossil source)
--    Source: RTE, "Emissions de CO2 de la production" (file
--    data/RTE_PAD_emissions_co2_production_2026-11-06.csv).
--    Loaded as text: values use a decimal comma ("0,78"), converted later.
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS rte_emissions_staging;

CREATE TABLE rte_emissions_staging (
    month      text,   -- Date        ('2024-01')
    sector     text,   -- Filière     ('Gaz', 'Charbon', 'Fioul', 'Déchets ménagers',
                       --              'Émission de gaz à effet de serre' = total of the 4)
    value_mt   text,   -- Valeur (Mt) (decimal comma)
    nature     text    -- Nature      ('Données Consolidées' / 'Données provisoires')
);

\copy rte_emissions_staging FROM 'data/RTE_PAD_emissions_co2_production_2026-11-06.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8')

SELECT count(*) AS rte_rows FROM rte_emissions_staging;   -- expected: 769

-- -----------------------------------------------------------------------------
-- 2. Fossil sources: derive one 2024 factor per source
--    factor (g/kWh) = 2024 emissions / 2024 generation of the same source
--      * emissions : RTE file, Mt, decimal comma converted to a point
--      * generation: eco2mix, each row is a 30-min step, so MW x 0.5 h = MWh
--      * units     : Mt -> g is x 1e12, MWh -> kWh is x 1e3,
--                    so g/kWh = Mt x 1e12 / (MWh x 1e3) = Mt x 1e9 / MWh
--    Assumptions:
--      * 'Déchets ménagers' (household waste) is spread over all of bioenergy_mw:
--        biomass and biogas count as zero direct emissions (biogenic CO2), so
--        the bioenergy factor is an average over the whole sector.
--      * The total row ('Émission de gaz à effet de serre') is left out: it is
--        the sum of the 4 sectors.
--      * All 2024 months are 'Données Consolidées' (final data).
-- -----------------------------------------------------------------------------
INSERT INTO emission_factors (source_name, factor_g_kwh, reference, year)
WITH emissions AS (
    -- one row per sector: total 2024 emissions in Mt
    SELECT
        CASE sector
            WHEN 'Gaz'              THEN 'gas'
            WHEN 'Charbon'          THEN 'coal'
            WHEN 'Fioul'            THEN 'fuel_oil'
            WHEN 'Déchets ménagers' THEN 'bioenergy'
        END                                          AS source_name,
        SUM(replace(value_mt, ',', '.')::numeric)    AS emissions_mt
    FROM rte_emissions_staging
    WHERE month LIKE '2024-%'
      AND sector <> 'Émission de gaz à effet de serre'
    GROUP BY sector
),
generation AS (
    -- one row per source: total 2024 generation in MWh
    -- eco2mix has one COLUMN per source, the RTE file one ROW per sector:
    -- UNION ALL turns the columns into rows so both sides can be joined
    SELECT 'gas'       AS source_name, SUM(gas_mw)       * 0.5 AS generation_mwh FROM eco2mix
    UNION ALL
    SELECT 'coal',                     SUM(coal_mw)      * 0.5 FROM eco2mix
    UNION ALL
    SELECT 'fuel_oil',                 SUM(fuel_oil_mw)  * 0.5 FROM eco2mix
    UNION ALL
    SELECT 'bioenergy',                SUM(bioenergy_mw) * 0.5 FROM eco2mix
)
SELECT
    e.source_name,
    round(e.emissions_mt * 1e9 / g.generation_mwh, 1)                     AS factor_g_kwh,
    'RTE, monthly CO2 emissions of generation by sector '
        || '(RTE_PAD_emissions_co2_production_2026-11-06.csv), '
        || 'divided by eco2mix 2024 generation'                           AS reference,
    2024                                                                  AS year
FROM emissions  AS e
JOIN generation AS g ON g.source_name = e.source_name;

-- -----------------------------------------------------------------------------
-- 3. Sources with zero direct emissions
--    RTE page "Emissions de gaz à effet de serre liées à la production
--    d'électricité en France": the indicator only counts combustion emissions of
--    thermal plants on French soil (gas, coal, fuel oil, household waste). It
--    excludes plant construction and the fuel cycle (no lifecycle / ACV), and
--    imports. So nuclear and renewables count as 0 direct emissions.
--    The fuel factors themselves come from ADEME Base Empreinte (primary factor
--    of the fuel), combined with RTE's average efficiency per sector: ADEME is
--    an input of the RTE method, not a separate lifecycle method here.
-- -----------------------------------------------------------------------------
INSERT INTO emission_factors (source_name, factor_g_kwh, reference, year) VALUES
    ('nuclear', 0, 'RTE, "Emissions de gaz à effet de serre liées à la production d''électricité en France" (eCO2mix methodology): combustion emissions only (https://www.rte-france.com/donnees-publications/eco2mix-donnees-temps-reel/emissions-co2-par-kwh-produit-france)', 2024),
    ('wind',    0, 'RTE, "Emissions de gaz à effet de serre liées à la production d''électricité en France" (eCO2mix methodology): combustion emissions only (https://www.rte-france.com/donnees-publications/eco2mix-donnees-temps-reel/emissions-co2-par-kwh-produit-france)', 2024),
    ('solar',   0, 'RTE, "Emissions de gaz à effet de serre liées à la production d''électricité en France" (eCO2mix methodology): combustion emissions only (https://www.rte-france.com/donnees-publications/eco2mix-donnees-temps-reel/emissions-co2-par-kwh-produit-france)', 2024),
    ('hydro',   0, 'RTE, "Emissions de gaz à effet de serre liées à la production d''électricité en France" (eCO2mix methodology): combustion emissions only (https://www.rte-france.com/donnees-publications/eco2mix-donnees-temps-reel/emissions-co2-par-kwh-produit-france)', 2024);

-- Check: 8 rows expected
SELECT source_name, factor_g_kwh FROM emission_factors ORDER BY factor_g_kwh DESC;
