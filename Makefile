.PHONY: help sync init-schemas up down logs materialize shell clean

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
	@echo "Pipeline:"
	@echo "  make materialize   Trigger full asset materialization"
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

# Pipeline
materialize:
	@./scripts/run-materialize.sh

# Cleanup
clean:
	docker compose down -v
	rm -rf dagster/
	@echo "Cleaned dagster directory and Docker volumes"
