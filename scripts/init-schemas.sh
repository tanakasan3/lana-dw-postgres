#!/usr/bin/env bash
# Initialize data warehouse schemas in the target PostgreSQL database
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load .env if it exists
if [[ -f "$PROJECT_DIR/.env" ]]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

# Validate required environment variables
required_vars=(DW_PG_HOST DW_PG_PORT DW_PG_DATABASE DW_PG_USER DW_PG_PASSWORD DW_RAW_SCHEMA DW_DBT_SCHEMA)
missing_vars=()

for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        missing_vars+=("$var")
    fi
done

if [[ ${#missing_vars[@]} -gt 0 ]]; then
    echo -e "${RED}Error: Missing required environment variables:${NC}"
    printf '  - %s\n' "${missing_vars[@]}"
    echo ""
    echo "Set them in .env or export them before running this script."
    exit 1
fi

echo -e "${GREEN}Initializing schemas in:${NC} $DW_PG_HOST:$DW_PG_PORT/$DW_PG_DATABASE"
echo "  Raw schema:  $DW_RAW_SCHEMA"
echo "  dbt schema:  $DW_DBT_SCHEMA"
echo ""

# Build connection string for psql
export PGPASSWORD="$DW_PG_PASSWORD"

# Create schemas
psql -h "$DW_PG_HOST" -p "$DW_PG_PORT" -U "$DW_PG_USER" -d "$DW_PG_DATABASE" << EOF
-- Create raw schema for dlt data
CREATE SCHEMA IF NOT EXISTS ${DW_RAW_SCHEMA};
COMMENT ON SCHEMA ${DW_RAW_SCHEMA} IS 'Raw data extracted by dlt from lana-bank';

-- Create dbt schema for transformed models
CREATE SCHEMA IF NOT EXISTS ${DW_DBT_SCHEMA};
COMMENT ON SCHEMA ${DW_DBT_SCHEMA} IS 'dbt transformed models for analytics';

-- Grant usage (adjust user as needed)
GRANT USAGE ON SCHEMA ${DW_RAW_SCHEMA} TO ${DW_PG_USER};
GRANT USAGE ON SCHEMA ${DW_DBT_SCHEMA} TO ${DW_PG_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA ${DW_RAW_SCHEMA} TO ${DW_PG_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA ${DW_DBT_SCHEMA} TO ${DW_PG_USER};

-- Grant default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA ${DW_RAW_SCHEMA} GRANT ALL ON TABLES TO ${DW_PG_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA ${DW_DBT_SCHEMA} GRANT ALL ON TABLES TO ${DW_PG_USER};

\echo 'Schemas created successfully'
EOF

echo ""
echo -e "${GREEN}✓ Schemas initialized!${NC}"
echo ""
echo "Verify with:"
echo "  psql -h $DW_PG_HOST -p $DW_PG_PORT -U $DW_PG_USER -d $DW_PG_DATABASE -c '\\dn'"
