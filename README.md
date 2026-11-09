# energy-data-pipeline

Electricity data pipeline for France (RTE eCO2mix): ingestion, storage, analysis
and, later, forecasting.

**Current stage (week 1):** one year of eCO2mix (2024, 30-min steps) loaded into
PostgreSQL, and 8 advanced SQL queries (window functions, CTEs, conditional
aggregation, `generate_series`), each documented and reproducible, plus an index
benchmark.

## Prerequisites

- PostgreSQL 16 or later (developed on PostgreSQL 18), with the `psql` client
- Git
- About 6 MB for the source files, a few MB in the database

On Windows, `psql` is in `C:\Program Files\PostgreSQL\<version>\bin\`. Use the full
path (`& "C:\Program Files\PostgreSQL\18\bin\psql.exe" ...`) or add that folder
to the `PATH`. See [`docs/psql-cheatsheet.md`](docs/psql-cheatsheet.md) (in French).

## Data

The data files are **not** in the repository (`*.csv` is ignored by Git).
Download them into `data/`, with these exact names:

| File | Source | Content | Licence |
|---|---|---|---|
| `data/eco2mix-national-cons-def.csv` | [ODRÉ, dataset `eco2mix-national-cons-def`](https://odre.opendatasoft.com/explore/dataset/eco2mix-national-cons-def/) (RTE eCO2mix national, consolidated and definitive data). Export as CSV (`;` separator), filtered on 2024 | Consumption, generation by source, exchanges and CO2 intensity, France, 2024. 15-min rows (35,136), of which the 30-min steps are kept | [Licence Ouverte v2.0 (Etalab)](https://www.etalab.gouv.fr/wp-content/uploads/2017/04/ETALAB-Licence-Ouverte-v2.0.pdf), as stated in the ODRÉ dataset metadata |
| `data/RTE_PAD_emissions_co2_production_2026-11-06.csv` | RTE, monthly CO2 emissions of electricity generation by sector (Mt), downloaded on 2026-11-06 | Used to derive the 2024 emission factors (`sql/02_emission_factors.sql`) | No licence stated on the RTE page (checked on 2026-11-09). The file is not redistributed here: download it from RTE |

Methodology of the CO2 indicator: [RTE, CO2 emissions per kWh generated in France](https://www.rte-france.com/donnees-publications/eco2mix-donnees-temps-reel/emissions-co2-par-kwh-produit-france).

## Recreate the database

All commands are run **from the repository root**: `\i` and `\copy` use paths
relative to the folder `psql` was started from.

1. Create the database (once):

   ```bash
   psql -U postgres -c "CREATE DATABASE energy;"
   ```

2. Connect to it:

   ```bash
   psql -U postgres -d energy
   ```

3. Run the scripts in order:

   ```
   \i sql/00_schema.sql            -- tables eco2mix_staging and eco2mix
   \i sql/01_load.sql              -- CSV -> staging -> eco2mix, with checks
   \i sql/02_emission_factors.sql  -- emission_factors table (needed by Q5 and Q7)
   ```

   Every script can be rerun: it drops and recreates what it builds.

4. Check the load. `01_load.sql` prints these checks:

   | Check | Expected |
   |---|---|
   | Rows in staging | 35,136 (366 days x 96 steps of 15 min) |
   | Rows in `eco2mix` | **17,566** (366 x 48 = 17,568, minus 2 steps missing from the source file) |
   | First / last step (Paris time) | 2024-01-01 00:00 / 2024-12-31 23:30 |
   | Steps with NULL consumption | 0 |

   `02_emission_factors.sql` must return 8 rows (gas, coal, fuel oil,
   bioenergy, and 4 sources at 0).

## Queries

One query per file in [`sql/queries/`](sql/queries/). Each file starts with a
header giving its goal, its assumptions and the expected result. Run one with,
for example, `\i sql/queries/q01_daily_peak.sql`.

| # | File | Question | SQL concept |
|---|---|---|---|
| Q1 | `q01_daily_peak.sql` | Daily consumption peak (value and time) | `RANK()` / `ROW_NUMBER()` per day |
| Q2 | `q02_rolling_avg_7d.sql` | 7-day rolling average consumption | `AVG() OVER (... ROWS BETWEEN ...)` |
| Q3 | `q03_monthly_renewable_share.sql` | Share of renewables in generation, by month | CTE + aggregation |
| Q4 | `q04_consumption_ramps.sql` | Change from one step to the next, steepest ramp of the year | `LAG()` |
| Q5 | `q05_carbon_intensity.sql` | Estimated carbon intensity per step, compared with RTE | CTE, unpivot (`CROSS JOIN LATERAL VALUES`), join |
| Q6 | `q06_hourly_profile_by_season.sql` | Typical day: average hourly profile by season | `EXTRACT`, `CASE`, `GROUP BY` |
| Q7 | `q07_top10_carbon_days.sql` | Top 10 days with the highest carbon intensity | CTE + `ORDER BY ... LIMIT` |
| Q8 | `q08_missing_steps.sql` | Missing time steps in the data | `generate_series` + `LEFT JOIN` (anti-join) |
| Q9 | `q09_consumption_wind_corr.sql` | *(optional, not done)* Correlation between consumption and wind | `CORR()` |
| Q10 | `q10_monthly_net_exchanges.sql` | *(optional, not done)* Net import/export by month | conditional aggregation |

## Index benchmark

[`docs/index-benchmark.md`](docs/index-benchmark.md) measures a selective query
with `EXPLAIN (ANALYZE, BUFFERS)` before and after a B-tree index:
**251 → 3 pages read, execution time divided by about 25**. It also explains why
the index does not help Q1 to Q8. To replay it: `\i sql/03_index_benchmark.sql`
(this creates the index `idx_eco2mix_consumption`).

## Design choices

- **One dataset, one time step:** eCO2mix consolidated/definitive, 30 min. The
  15-min rows (hh:15, hh:45) only hold commercial exchanges and are dropped.
- **Time zone:** timestamps are stored as `timestamptz` (absolute instants, UTC).
  They are converted to `Europe/Paris` only to display them or to group by local
  day, month or hour.
- **Daylight saving time:** on 2024-03-31, the source adds fake 02:00 / 02:30
  rows; they are removed at load time. On 2024-10-27, the 02:00 / 02:30 summer
  time steps are absent from the source file (Q8 finds them).
- **Missing values:** empty cells become `NULL` (not measured), never 0.
- **Emission factors:** derived from RTE's 2024 monthly emissions divided by the
  2024 eCO2mix generation of each source. Like RTE's own indicator, they count
  direct combustion emissions only, so Q5 can be compared with RTE's value.

## Repository structure

```
data/      data files (ignored by Git, see "Data")
docs/      index benchmark, psql cheat sheet
sql/       schema, load, emission factors, index benchmark
sql/queries/  Q1 to Q10, one query per file
src/       Python code (next weeks)
tests/     tests (next weeks)
```

## Licence

Code: MIT (see [`LICENSE`](LICENSE)). Data: see the licences in the "Data" table.
