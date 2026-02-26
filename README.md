# lana-dw-postgres

Simplified wrapper for running the lana-bank dagster data pipeline targeting PostgreSQL instead of BigQuery.

## Overview

This project provides:
- Docker Compose setup for Dagster with PostgreSQL data warehouse
- Scripts to sync dagster code from lana-bank
- Environment configuration for local development

## Prerequisites

- Docker and Docker Compose
- Access to a running lana-bank PostgreSQL database (source)
- Git clone of lana-bank with `feature/cross-platform-dw-target` branch

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/tanakasan3/lana-dw-postgres.git
cd lana-dw-postgres

# 2. Configure environment
cp .env.example .env
# Edit .env with your lana-bank source database connection

# 3. Sync dagster code from lana-bank
./scripts/sync-dagster.sh /path/to/lana-bank

# 4. Start services
docker compose up -d

# 5. Open Dagster UI
open http://localhost:3000
```

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   lana-bank     │────▶│     Dagster     │────▶│   PostgreSQL    │
│   (source DB)   │     │   (ETL/dbt)     │     │   (DW schemas)  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                       │
                                                       ├── raw (dlt data)
                                                       └── dbt (transforms)
```

## Configuration

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `LANA_PG_CON` | Source lana-bank database connection | `postgres://user:pass@host:5432/lana` |
| `DW_TARGET` | Data warehouse target | `postgres` |
| `DW_PG_HOST` | DW PostgreSQL host | `localhost` or `dw-postgres` |
| `DW_PG_PORT` | DW PostgreSQL port | `5432` |
| `DW_PG_DATABASE` | DW database name | `lana` (same-db) or `lana_dw` |
| `DW_PG_USER` | DW database user | `postgres` |
| `DW_PG_PASSWORD` | DW database password | `secret` |
| `DW_RAW_SCHEMA` | Schema for raw dlt data | `raw` |
| `DW_DBT_SCHEMA` | Schema for dbt models | `dbt` |

### Same-Database Setup

To use the same PostgreSQL database as lana-bank (with separate schemas):

```bash
# In .env
DW_PG_HOST=your-lana-db-host
DW_PG_DATABASE=lana          # Same database
DW_RAW_SCHEMA=raw            # Raw data schema
DW_DBT_SCHEMA=dbt            # dbt models schema
```

### Separate Database Setup

For a dedicated data warehouse database:

```bash
# In .env
DW_PG_HOST=dw-postgres       # Use compose service
DW_PG_DATABASE=lana_dw       # Separate database
DW_RAW_SCHEMA=raw
DW_DBT_SCHEMA=dbt
```

## Scripts

### sync-dagster.sh

Syncs the dagster pipeline code from lana-bank:

```bash
./scripts/sync-dagster.sh /path/to/lana-bank
```

This copies:
- `dagster/src/` → `dagster/`
- Required Python dependencies

### run-materialize.sh

Runs a full materialization of all assets:

```bash
./scripts/run-materialize.sh
```

## Development

### Local Setup (without Docker)

```bash
# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -e ./dagster

# Run dagster dev server
cd dagster && dagster dev
```

### Checking dbt Models

```bash
cd dagster/dbt_lana_dw
dbt debug --target postgres
dbt run --target postgres
```

## Limitations

- **File reports**: Not available (require BigQuery/GCS integration)
- **Historical backfills**: May need manual date range configuration

## Related

- [lana-bank](https://github.com/GaloyMoney/lana-bank) - Source repository
- [lana-sim-scenarios](https://github.com/tanakasan3/lana-sim-scenarios) - Simulation scenario generator
