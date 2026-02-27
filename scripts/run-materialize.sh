#!/usr/bin/env bash
# Trigger materialization of dagster assets
# Usage: ./run-materialize.sh [el|seeds|dbt|all]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TARGET="${1:-all}"

# Check if dagster is running
if ! docker compose -f "$PROJECT_DIR/docker-compose.yml" ps --status running | grep -q "lana-dw-webserver"; then
    echo -e "${RED}Error: Dagster webserver is not running${NC}"
    echo "Start it with: make up"
    exit 1
fi

run_job() {
    local job_name="$1"
    local description="$2"
    
    echo -e "${GREEN}Executing: ${description}...${NC}"
    docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T lana-dw-webserver \
        dagster job execute -j "$job_name" -w workspace.yaml
    echo -e "${GREEN}✓ ${description} complete${NC}"
    echo ""
}

case "$TARGET" in
    el)
        run_job "lana_to_dw_el" "EL raw tables (lana-core → DW)"
        ;;
    seeds)
        run_job "dbt_seeds_job" "dbt seeds"
        ;;
    dbt)
        run_job "dbt_models_job" "dbt models"
        ;;
    bitfinex)
        run_job "bitfinex_ticker_el" "Bitfinex ticker"
        run_job "bitfinex_trades_el" "Bitfinex trades"
        run_job "bitfinex_order_book_el" "Bitfinex order book"
        ;;
    all)
        echo -e "${YELLOW}Running full materialization in dependency order...${NC}"
        echo ""
        run_job "lana_to_dw_el" "EL raw tables (lana-core → DW)"
        run_job "dbt_seeds_job" "dbt seeds"
        run_job "dbt_models_job" "dbt models"
        echo -e "${GREEN}✓ All assets materialized successfully!${NC}"
        ;;
    refresh)
        echo -e "${YELLOW}Running quick refresh (EL + dbt models)...${NC}"
        echo ""
        run_job "lana_to_dw_el" "EL raw tables (lana-core → DW)"
        run_job "dbt_models_job" "dbt models"
        echo -e "${GREEN}✓ Refresh complete!${NC}"
        ;;
    *)
        echo -e "${RED}Unknown target: $TARGET${NC}"
        echo "Usage: $0 [el|seeds|dbt|bitfinex|all|refresh]"
        exit 1
        ;;
esac

echo "Monitor progress at: http://localhost:3000"
