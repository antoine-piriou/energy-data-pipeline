-- =============================================================================
-- 00_schema.sql: create the eCO2mix tables
-- Usage (from the repository root, connected to the energy database):
--     \i sql/00_schema.sql
-- Re-runnable: drops and recreates the tables.
-- =============================================================================

DROP TABLE IF EXISTS eco2mix_staging;
DROP TABLE IF EXISTS eco2mix;


-- -----------------------------------------------------------------------------
-- 1. Staging table: raw copy of the CSV
--    37 columns, in the exact order of the file, all as text.
--    \copy fills columns by position: the order must match the CSV.
--    Comments give the original (French) CSV header.
-- -----------------------------------------------------------------------------
CREATE TABLE eco2mix_staging (
    perimeter                   text,  -- Périmètre
    nature                      text,  -- Nature
    local_date                  text,  -- Date
    local_time                  text,  -- Heure
    datetime                    text,  -- Date et Heure
    consumption                 text,  -- Consommation (MW)
    forecast_d1                 text,  -- Prévision J-1 (MW)
    forecast_d                  text,  -- Prévision J (MW)
    fuel_oil                    text,  -- Fioul (MW)
    coal                        text,  -- Charbon (MW)
    gas                         text,  -- Gaz (MW)
    nuclear                     text,  -- Nucléaire (MW)
    wind                        text,  -- Eolien (MW)
    solar                       text,  -- Solaire (MW)
    hydro                       text,  -- Hydraulique (MW)
    pumping                     text,  -- Pompage (MW)
    bioenergy                   text,  -- Bioénergies (MW)
    physical_exchanges          text,  -- Ech. physiques (MW)
    co2_intensity               text,  -- Taux de CO2 (g/kWh)
    comm_exch_gb                text,  -- Ech. comm. Angleterre (MW)
    comm_exch_spain             text,  -- Ech. comm. Espagne (MW)
    comm_exch_italy             text,  -- Ech. comm. Italie (MW)
    comm_exch_switzerland       text,  -- Ech. comm. Suisse (MW)
    comm_exch_germany_belgium   text,  -- Ech. comm. Allemagne-Belgique (MW)
    fuel_oil_ct                 text,  -- Fioul - TAC (MW)
    fuel_oil_chp                text,  -- Fioul - Cogénération (MW)
    fuel_oil_other              text,  -- Fioul - Autres (MW)
    gas_ct                      text,  -- Gaz - TAC (MW)
    gas_chp                     text,  -- Gaz - Cogénération (MW)
    gas_ccgt                    text,  -- Gaz - CCG (MW)
    gas_other                   text,  -- Gaz - Autres (MW)
    hydro_run_of_river          text,  -- Hydraulique - Fil de l'eau + éclusée (MW)
    hydro_reservoir             text,  -- Hydraulique - Lacs (MW)
    hydro_pumped_storage        text,  -- Hydraulique - STEP turbinage (MW)
    bioenergy_waste             text,  -- Bioénergies - Déchets (MW)
    bioenergy_biomass           text,  -- Bioénergies - Biomasse (MW)
    bioenergy_biogas            text   -- Bioénergies - Biogaz (MW)
);

COMMENT ON TABLE eco2mix_staging IS
    'Raw load of the eCO2mix national consolidated/definitive CSV (ODRE), no conversion. Transit table.';


-- -----------------------------------------------------------------------------
-- 2. Clean table: useful columns only, with proper types
--    One time step = 30 min, timestamp stored as timestamptz (absolute instant).
-- -----------------------------------------------------------------------------
CREATE TABLE eco2mix (
    ts                           timestamptz PRIMARY KEY,
    consumption_mw               integer,
    forecast_d1_mw               integer,
    forecast_d_mw                integer,

    -- Generation by source
    fuel_oil_mw                  integer,
    coal_mw                      integer,
    gas_mw                       integer,
    nuclear_mw                   integer,
    wind_mw                      integer,
    solar_mw                     integer,
    hydro_mw                     integer,
    pumping_mw                   integer,
    bioenergy_mw                 integer,

    -- Exchanges
    physical_exchanges_mw        integer,
    comm_exch_gb_mw              integer,
    comm_exch_spain_mw           integer,
    comm_exch_italy_mw           integer,
    comm_exch_switzerland_mw     integer,
    comm_exch_germany_belgium_mw integer,

    co2_intensity_g_kwh          integer
);

COMMENT ON TABLE eco2mix IS
    'French power mix 2024, 30-min time step. Source: eCO2mix national consolidated/definitive, RTE via ODRE.';
COMMENT ON COLUMN eco2mix.ts IS
    'Start of the time step, with time zone (stored in UTC).';
COMMENT ON COLUMN eco2mix.consumption_mw IS
    'Actual consumption, in MW (average power over the time step).';
COMMENT ON COLUMN eco2mix.forecast_d1_mw IS
    'Consumption forecast made the day before (D-1), in MW.';
COMMENT ON COLUMN eco2mix.forecast_d_mw IS
    'Consumption forecast updated on the same day (D), in MW.';

COMMENT ON COLUMN eco2mix.fuel_oil_mw IS
    'Fuel oil generation (combustion turbines + CHP + other), in MW.';
COMMENT ON COLUMN eco2mix.coal_mw IS
    'Coal generation, in MW.';
COMMENT ON COLUMN eco2mix.gas_mw IS
    'Gas generation (combustion turbines + CHP + CCGT + other), in MW.';
COMMENT ON COLUMN eco2mix.nuclear_mw IS
    'Nuclear generation, in MW.';
COMMENT ON COLUMN eco2mix.wind_mw IS
    'Wind generation, in MW.';
COMMENT ON COLUMN eco2mix.solar_mw IS
    'Solar PV generation, in MW.';
COMMENT ON COLUMN eco2mix.hydro_mw IS
    'Hydro generation (run-of-river + pondage, reservoirs, pumped-storage turbining), in MW.';
COMMENT ON COLUMN eco2mix.pumping_mw IS
    'Pumped-storage consumption in pumping mode, in MW. Negative value (energy absorbed).';
COMMENT ON COLUMN eco2mix.bioenergy_mw IS
    'Bioenergy generation (waste + biomass + biogas), in MW.';

COMMENT ON COLUMN eco2mix.physical_exchanges_mw IS
    'Net physical cross-border flows, in MW. Positive = import, negative = export.';
COMMENT ON COLUMN eco2mix.comm_exch_gb_mw IS
    'Commercial exchanges with Great Britain, in MW. Positive = import, negative = export.';
COMMENT ON COLUMN eco2mix.comm_exch_spain_mw IS
    'Commercial exchanges with Spain, in MW. Positive = import, negative = export.';
COMMENT ON COLUMN eco2mix.comm_exch_italy_mw IS
    'Commercial exchanges with Italy, in MW. Positive = import, negative = export.';
COMMENT ON COLUMN eco2mix.comm_exch_switzerland_mw IS
    'Commercial exchanges with Switzerland, in MW. Positive = import, negative = export.';
COMMENT ON COLUMN eco2mix.comm_exch_germany_belgium_mw IS
    'Commercial exchanges with the Germany-Belgium area (CWE), in MW. Positive = import, negative = export.';

COMMENT ON COLUMN eco2mix.co2_intensity_g_kwh IS
    'Carbon intensity of French generation, in gCO2/kWh (RTE estimate).';
