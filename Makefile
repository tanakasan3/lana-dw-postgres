.PHONY: help sync init-schemas up down logs shell clean \
        materialize materialize-el materialize-seeds materialize-dbt materialize-bitfinex refresh \
        psql psql-schemas psql-tables

# Default lana-bank path (override with: make sync LANA_BANK=~/path/to/lana-bank)
LANA_BANK ?= ../lana-bank

help:
	@echo "lana-dw-postgres - Dagster pipeline for PostgreSQL"
	@echo ""
	@echo "Setup:"
	@echo "  make sync          Sync dagster code from lana-bank"
	@echo "  make init-schemas  Create raw/dbt schemas in target DB"
	@echo ""
	@echo "Docker:"
	@echo "  make up            Start dagster services"
	@echo "  make down          Stop dagster services"
	@echo "  make logs          Tail dagster logs"
	@echo "  make shell         Shell into webserver container"
	@echo ""
	@echo "Materialization (run in dependency order):"
	@echo "  make materialize-el      1. Load raw tables from lana-core"
	@echo "  make materialize-seeds   2. Load dbt seeds (reference data)"
	@echo "  make materialize-dbt     3. Run dbt models (transforms)"
	@echo "  make materialize         Run all above in order (cold start)"
	@echo "  make refresh             Quick: EL + dbt models (skip seeds)"
	@echo ""
	@echo "  make materialize-bitfinex  Load Bitfinex market data"
	@echo ""
	@echo "Debug:"
	@echo "  make psql          Connect to DW postgres"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean         Remove dagster directory and volumes"
	@echo ""
	@echo "Options:"
	@echo "  LANA_BANK=<path>   Path to lana-bank repo (default: ../lana-bank)"

# Setup
sync:
	@./scripts/sync-dagster.sh $(LANA_BANK)

init-schemas:
	@./scripts/init-schemas.sh

# Docker
up:
	docker compose up -d --build
	@echo ""
	@echo "Dagster UI: http://localhost:3000"

down:
	docker compose down

logs:
	docker compose logs -f

shell:
	docker compose exec dagster-webserver bash

# Materialization - individual steps
materialize-el:
	@./scripts/run-materialize.sh el

materialize-seeds:
	@./scripts/run-materialize.sh seeds

materialize-dbt:
	@./scripts/run-materialize.sh dbt

materialize-bitfinex:
	@./scripts/run-materialize.sh bitfinex

# Materialization - combined
materialize:
	@./scripts/run-materialize.sh all

refresh:
	@./scripts/run-materialize.sh refresh

# Debug - connect to DW postgres (runs inside container to resolve host.docker.internal)
psql:
	docker compose exec dagster-webserver bash -c 'PGPASSWORD="$$DW_PG_PASSWORD" psql -h "$$DW_PG_HOST" -p "$$DW_PG_PORT" -U "$$DW_PG_USER" -d "$$DW_PG_DATABASE"'

# List schemas in DW
psql-schemas:
	docker compose exec dagster-webserver bash -c 'PGPASSWORD="$$DW_PG_PASSWORD" psql -h "$$DW_PG_HOST" -p "$$DW_PG_PORT" -U "$$DW_PG_USER" -d "$$DW_PG_DATABASE" -c "\\dn"'

# List tables in raw schema
psql-tables:
	docker compose exec dagster-webserver bash -c 'PGPASSWORD="$$DW_PG_PASSWORD" psql -h "$$DW_PG_HOST" -p "$$DW_PG_PORT" -U "$$DW_PG_USER" -d "$$DW_PG_DATABASE" -c "SELECT schemaname, tablename FROM pg_tables WHERE schemaname IN ('\''$$DW_RAW_SCHEMA'\'', '\''$$DW_DBT_SCHEMA'\'') ORDER BY schemaname, tablename;"'

# Cleanup
clean:
	docker compose down -v
	rm -rf dagster/
	@echo "Cleaned dagster directory and Docker volumes"
