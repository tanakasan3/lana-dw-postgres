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

# Clean existing dagster directory (preserve Dockerfile if exists)
if [[ -d "$DAGSTER_DIR" ]]; then
    echo "Cleaning existing dagster directory..."
    # Preserve our custom files
    if [[ -f "$DAGSTER_DIR/Dockerfile" ]]; then
        cp "$DAGSTER_DIR/Dockerfile" /tmp/lana-dw-dockerfile.bak
    fi
    if [[ -f "$DAGSTER_DIR/dagster.yaml" ]]; then
        cp "$DAGSTER_DIR/dagster.yaml" /tmp/lana-dw-dagster-yaml.bak
    fi
    rm -rf "$DAGSTER_DIR"
fi

# Create dagster directory
mkdir -p "$DAGSTER_DIR"

# Copy dagster source
echo "Copying dagster source..."
cp -r "$LANA_BANK_DIR/dagster/src/"* "$DAGSTER_DIR/"

# Copy pyproject.toml and adjust if needed
if [[ -f "$LANA_BANK_DIR/dagster/pyproject.toml" ]]; then
    echo "Copying pyproject.toml..."
    cp "$LANA_BANK_DIR/dagster/pyproject.toml" "$DAGSTER_DIR/"
fi

# Restore our custom files
if [[ -f /tmp/lana-dw-dockerfile.bak ]]; then
    cp /tmp/lana-dw-dockerfile.bak "$DAGSTER_DIR/Dockerfile"
    rm /tmp/lana-dw-dockerfile.bak
fi
if [[ -f /tmp/lana-dw-dagster-yaml.bak ]]; then
    cp /tmp/lana-dw-dagster-yaml.bak "$DAGSTER_DIR/dagster.yaml"
    rm /tmp/lana-dw-dagster-yaml.bak
fi

# Create Dockerfile if it doesn't exist
if [[ ! -f "$DAGSTER_DIR/Dockerfile" ]]; then
    echo "Creating Dockerfile..."
    cat > "$DAGSTER_DIR/Dockerfile" << 'EOF'
FROM python:3.11-slim

WORKDIR /opt/dagster/app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    libpq-dev \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies
COPY pyproject.toml .
RUN pip install --no-cache-dir -e .

# Install dbt postgres adapter
RUN pip install --no-cache-dir dbt-postgres

# Copy application code
COPY . .

# Create dagster home directory
RUN mkdir -p /opt/dagster/dagster_home

# Set environment
ENV DAGSTER_HOME=/opt/dagster/dagster_home

EXPOSE 3000
EOF
fi

# Create dagster.yaml if it doesn't exist
if [[ ! -f "$DAGSTER_DIR/dagster.yaml" ]]; then
    echo "Creating dagster.yaml..."
    cat > "$DAGSTER_DIR/dagster.yaml" << 'EOF'
# Dagster instance configuration
storage:
  postgres:
    postgres_db:
      hostname: dagster-postgres
      username: dagster
      password: dagster
      db_name: dagster
      port: 5432

run_launcher:
  module: dagster.core.launcher
  class: DefaultRunLauncher

run_coordinator:
  module: dagster.core.run_coordinator
  class: DefaultRunCoordinator
EOF
fi

echo ""
echo -e "${GREEN}✓ Sync complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Review .env configuration"
echo "  2. Run: docker compose up -d"
echo "  3. Open: http://localhost:3000"
