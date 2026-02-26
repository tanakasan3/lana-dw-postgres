#!/usr/bin/env bash
# Sync dagster pipeline code from lana-bank repository
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DAGSTER_DIR="$PROJECT_DIR/dagster"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 <path-to-lana-bank>"
    echo ""
    echo "Syncs the dagster pipeline from lana-bank to this project."
    echo ""
    echo "Arguments:"
    echo "  path-to-lana-bank    Path to the lana-bank repository"
    echo ""
    echo "Requirements:"
    echo "  - lana-bank must be on 'feature/cross-platform-dw-target' branch"
    echo "    (or have the cross-platform changes merged)"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

LANA_BANK_DIR="$1"

# Validate lana-bank path
if [[ ! -d "$LANA_BANK_DIR/dagster" ]]; then
    echo -e "${RED}Error: '$LANA_BANK_DIR' does not appear to be a lana-bank repository${NC}"
    echo "Expected to find: $LANA_BANK_DIR/dagster"
    exit 1
fi

# Check for cross-platform support
if [[ ! -f "$LANA_BANK_DIR/dagster/src/resources/dw.py" ]]; then
    echo -e "${YELLOW}Warning: Cross-platform DW support not found.${NC}"
    echo "Make sure lana-bank is on 'feature/cross-platform-dw-target' branch."
    echo ""
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${GREEN}Syncing dagster from:${NC} $LANA_BANK_DIR"

# Clean existing dagster directory
if [[ -d "$DAGSTER_DIR" ]]; then
    echo "Cleaning existing dagster directory..."
    rm -rf "$DAGSTER_DIR"
fi

# Create dagster directory
mkdir -p "$DAGSTER_DIR"

# Copy dagster source
echo "Copying dagster source..."
cp -r "$LANA_BANK_DIR/dagster/src" "$DAGSTER_DIR/"

# Copy workspace.yaml if it exists
if [[ -f "$LANA_BANK_DIR/dagster/workspace.yaml" ]]; then
    cp "$LANA_BANK_DIR/dagster/workspace.yaml" "$DAGSTER_DIR/"
fi

# Create our custom Dockerfile for PostgreSQL
echo "Creating Dockerfile..."
cat > "$DAGSTER_DIR/Dockerfile" << 'EOF'
FROM python:3.13-slim

ENV PYTHONUNBUFFERED=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    libpq-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip

# Install dagster and dependencies
ARG DAGSTER_VERSION=1.12.0
ARG DAGSTER_EXT_VERSION=0.28.0
RUN pip install \
    dagster~=${DAGSTER_VERSION} \
    dagster-webserver~=${DAGSTER_VERSION} \
    dagster-postgres~=${DAGSTER_EXT_VERSION} \
    dagster-dbt~=${DAGSTER_EXT_VERSION} \
    dagster-dlt~=${DAGSTER_EXT_VERSION}

# Install dbt and dlt with postgres support
RUN pip install \
    dbt-core~=1.10.0 \
    dbt-postgres~=1.10.0 \
    "dlt[postgres]~=1.18.1" \
    pandas \
    requests \
    opentelemetry-api \
    opentelemetry-sdk \
    opentelemetry-exporter-otlp-proto-grpc \
    google-cloud-bigquery \
    google-cloud-storage

# Copy source code
RUN mkdir -p /lana-dw
COPY src/ /lana-dw/src/

WORKDIR /lana-dw

# Pre-parse dbt manifest (with dummy vars for build)
RUN DW_TARGET=postgres \
    DW_PG_HOST=localhost \
    DW_PG_PORT=5432 \
    DW_PG_DATABASE=lana \
    DW_PG_USER=postgres \
    DW_PG_PASSWORD=dummy \
    DW_RAW_SCHEMA=raw \
    DW_DBT_SCHEMA=dbt \
    dbt parse --project-dir /lana-dw/src/dbt_lana_dw --profiles-dir /lana-dw/src/dbt_lana_dw || true

EXPOSE 3000

CMD ["dagster-webserver", "-h", "0.0.0.0", "-p", "3000", "-f", "/lana-dw/src/definitions.py", "-d", "/lana-dw"]
EOF

# Create workspace.yaml for code location
echo "Creating workspace.yaml..."
cat > "$DAGSTER_DIR/workspace.yaml" << 'EOF'
load_from:
  - python_file:
      relative_path: src/definitions.py
      working_directory: /lana-dw
EOF

# Create dagster.yaml for instance configuration
echo "Creating dagster.yaml..."
cat > "$DAGSTER_DIR/dagster.yaml" << 'EOF'
storage:
  postgres:
    postgres_db:
      hostname:
        env: DAGSTER_PG_HOST
      port:
        env: DAGSTER_PG_PORT
      username:
        env: DAGSTER_PG_USER
      password:
        env: DAGSTER_PG_PASSWORD
      db_name:
        env: DAGSTER_PG_DB

run_launcher:
  module: dagster.core.launcher
  class: DefaultRunLauncher
EOF

echo ""
echo -e "${GREEN}✓ Sync complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Review .env configuration"
echo "  2. Run: docker compose up -d --build"
echo "  3. Open: http://localhost:3000"
