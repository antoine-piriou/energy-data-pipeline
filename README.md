# energy-data-pipeline

Electricity data pipeline for France (RTE eCO2mix): ingestion, storage, analysis
and, later, forecasting.

**Current stage (week 2):**

- **Week 1, SQL:** one year of eCO2mix (2024, 30-min steps) loaded into
  PostgreSQL, and 8 advanced SQL queries (window functions, CTEs, conditional
  aggregation, `generate_series`), each documented and reproducible, plus an
  index benchmark.
- **Week 2, Python ingestion:** an installable package that downloads raw data
  from three public APIs (eCO2mix, Open-Meteo, ENTSO-E) into files partitioned
  by UTC day, idempotent and atomic, with retries, logs and 13 tests that need
  no network.

See [Use of AI](#use-of-ai) for what was written with AI assistance.

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

## Python ingestion

### Install

Python 3.11 or later. From the repository root:

```bash
python -m venv .venv
.venv\Scripts\activate        # Windows; on Linux/macOS: source .venv/bin/activate
pip install -e ".[dev]"
```

ENTSO-E needs a free API token (request it from the
[Transparency Platform](https://transparency.entsoe.eu/)). Copy `.env.example`
to `.env` and fill in `ENTSOE_API_TOKEN`. `.env` is ignored by Git. The other
two sources need no key.

### Commands

One command, one source, one range of days (both included):

```bash
python -m energy_pipeline.cli ingest --source eco2mix    --start 2024-01-01 --end 2024-01-07
python -m energy_pipeline.cli ingest --source open_meteo --start 2024-01-01 --end 2024-01-07
python -m energy_pipeline.cli ingest --source entsoe     --start 2024-01-01 --end 2024-01-07
```

Options:

- `--force` rewrites days that are already present (by default they are skipped).
- `--root <dir>` changes the output folder (default `data/raw`, or
  `RAW_DATA_DIR` from the environment).
- `--log-level DEBUG|INFO|WARNING` goes **before** `ingest`:
  `python -m energy_pipeline.cli --log-level DEBUG ingest ...`

The exit code is 0 if every day succeeded, 1 otherwise. A failed day is logged
and the run goes on; rerunning the same command only fetches the missing days.

### Sources

| Source | API | Data | Raw format | Rows per UTC day |
|---|---|---|---|---|
| `eco2mix` | [ODRÉ](https://odre.opendatasoft.com/explore/dataset/eco2mix-national-cons-def/), export endpoint, no key | France, consolidated and definitive data | CSV (`;`) | 96 (15 min), except DST days |
| `open_meteo` | [Open-Meteo archive](https://open-meteo.com/en/docs/historical-weather-api), no key | Paris hourly temperature (`temperature_2m`) | JSON | 24 |
| `entsoe` | [ENTSO-E Transparency Platform](https://transparency.entsoe.eu/), token | Germany actual total load (A65, A16) | XML | 96 (15 min) |

### Partitioning

```
data/raw/source=<source>/date=YYYY-MM-DD/data.<csv|json|xml>
```

One file per source and per **UTC** day, holding the API response unchanged.

### Tests and checks

```bash
pytest                       # 13 tests, no network: HTTP is faked
ruff check .
python scripts/count_backfill.py   # counts the 2024 eCO2mix backfill (from the repo root)
```

## Design choices

- **One dataset, one time step:** eCO2mix consolidated/definitive, 30 min. The
  15-min rows (hh:15, hh:45) only hold commercial exchanges and are dropped.
- **Time zone:** timestamps are stored as `timestamptz` (absolute instants, UTC).
  They are converted to `Europe/Paris` only to display them or to group by local
  day, month or hour.
- **Daylight saving time:** on 2024-03-31, the source adds fake 02:00 / 02:30
  rows; they are removed at load time. On 2024-10-27, the 02:00 / 02:30 summer
  time steps are absent from the source file (Q8 finds them).
- **Raw layer keeps source quirks:** the Python ingestion writes the source
  rows unchanged, one partition per UTC day. The 2024 backfill has 366
  partitions and 35136 rows (366 x 96), checked by `scripts/count_backfill.py`
  (run from the repo root). Two days differ from 96 rows because of daylight
  saving time: 2024-03-31 has 100 (UTC 01:00-01:45 appear twice, once as the
  non-existent local 02:xx) and 2024-10-27 has 92 (UTC 00:00-00:45, the first
  local 02:xx, is missing). Cleaning happens later, not in the raw layer.
- **UTC partitions:** a UTC day always has 24 hours, so no partition has 23 or
  25 hours at daylight saving time changes.
- **Idempotent and atomic writes:** a day that is already present is skipped
  before any API call (`--force` to rewrite). A file is written to `data.tmp`
  first, then renamed (`os.replace`), so an interrupted run never leaves a
  half-written file.
- **Errors:** network errors and 5xx responses are retried with exponential
  backoff (1 s, 2 s, 4 s); 4xx responses fail at once, since retrying a wrong
  request does not help.
- **ENTSO-E token:** read from the environment when ENTSO-E is called, so the
  other sources work without it. It never appears in logs or error messages:
  the HTTP client logs only the base URL, and `urllib3` (used by `requests`,
  which logs full URLs at DEBUG level) is kept at WARNING. A test checks this.
- **One weather point:** Paris temperature is used as a proxy for French
  temperature, which drives demand through electric heating. Paris is not the
  centre of French consumption (Ile-de-France is roughly 15-20 %), but cold
  spells usually hit the whole country.
- **Missing values:** empty cells become `NULL` (not measured), never 0.
- **Emission factors:** derived from RTE's 2024 monthly emissions divided by the
  2024 eCO2mix generation of each source. Like RTE's own indicator, they count
  direct combustion emissions only, so Q5 can be compared with RTE's value.

## Repository structure

```
data/         data files (ignored by Git, see "Data"); data/raw/ for the ingestion
docs/         index benchmark, psql cheat sheet
scripts/      count_backfill.py (checks the 2024 backfill)
sql/          schema, load, emission factors, index benchmark
sql/queries/  Q1 to Q10, one query per file
src/energy_pipeline/
  config.py         settings from the environment (.env)
  logging_setup.py  log format and levels
  http.py           GET with timeout and retries
  storage.py        partition paths, atomic writes
  cli.py            command line
  sources/          eco2mix.py, open_meteo.py, entsoe.py
tests/        pytest tests and small fixtures
```

## Use of AI

This project is a learning project. I used Claude (Anthropic) as a tutor and
pair programmer. What it did, file by file:

| Part | Who wrote it |
|---|---|
| SQL (week 1) | Me; AI explained concepts and reviewed |
| `config.py`, `logging_setup.py`, `http.py` | Me, from AI skeletons and hints; AI fixed formatting and translated comments. The `urllib3` line in `logging_setup.py` is from AI |
| `sources/eco2mix.py` | AI skeleton and API research; I wrote the logic |
| `storage.py` | Me (`partition_path`, first write logic); AI finalised `write_partition` |
| `cli.py` | AI, explained to me line by line |
| `sources/open_meteo.py` | Me, after choosing the design with AI; AI fixed comments and formatting |
| `sources/entsoe.py` | AI, explained to me |
| `scripts/count_backfill.py` | Me; AI tidied it |
| Tests | `test_storage.py` and `test_cli.py`: the first 3 tests by me, the others by AI. `test_http.py` and `test_entsoe.py`: AI. `test_eco2mix.py` and `test_open_meteo.py`: AI skeletons, I filled them in |
| Documentation (README, docs) | Drafted with AI; facts and numbers checked by me |

## Licence

Code: MIT (see [`LICENSE`](LICENSE)). Data: see the licences in the "Data" table.
