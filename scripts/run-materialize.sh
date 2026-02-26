#!/usr/bin/env bash
# Trigger a full materialization of all dagster assets
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if dagster is running
if ! docker compose -f "$PROJECT_DIR/docker-compose.yml" ps --status running | grep -q "lana-dw-webserver"; then
    echo -e "${RED}Error: Dagster webserver is not running${NC}"
    echo "Start it with: docker compose up -d"
    exit 1
fi

echo -e "${GREEN}Triggering full materialization...${NC}"

# Execute dagster CLI in the webserver container
docker compose -f "$PROJECT_DIR/docker-compose.yml" exec dagster-webserver \
    dagster asset materialize -f /lana-dw/src/definitions.py --select "*"

echo ""
echo -e "${GREEN}✓ Materialization triggered!${NC}"
echo "Monitor progress at: http://localhost:3000"
