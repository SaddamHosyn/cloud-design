#!/bin/bash
set -e

# PostgreSQL paths and settings
DATA_DIR="/var/lib/postgresql/13/main"
PG_BIN="/usr/lib/postgresql/13/bin"
PGCTL="$PG_BIN/pg_ctl"

echo "🔧 PostgreSQL setup starting..."

# Step 1: Ensure parent directory exists and is owned by postgres
mkdir -p /var/lib/postgresql
chmod 755 /var/lib/postgresql
chown postgres:postgres /var/lib/postgresql

# Step 2: Create data directory with proper permissions BEFORE initdb
if [ ! -d "$DATA_DIR" ]; then
    mkdir -p "$DATA_DIR"
fi
chmod 700 "$DATA_DIR"
chown postgres:postgres "$DATA_DIR"

# Step 3: Clean up stale lock files from crashed restarts
if [ -f "$DATA_DIR/postmaster.pid" ]; then
    echo "🧹 Cleaning up stale lock file..."
    rm -f "$DATA_DIR/postmaster.pid"
    rm -f "$DATA_DIR/postmaster.pid.lock"
fi

# Step 4: Initialize PostgreSQL cluster if needed
if [ ! -f "$DATA_DIR/PG_VERSION" ]; then
    echo "🔧 Initializing PostgreSQL cluster..."
    rm -rf "$DATA_DIR"/*
    runuser -u postgres -- $PG_BIN/initdb -D "$DATA_DIR" -A trust -U postgres
    echo "✅ Cluster initialized"
fi

# Step 4: Ensure config file exists
if [ ! -f "$DATA_DIR/postgresql.conf" ]; then
    echo "⚠️ Config file missing, reinitializing..."
    rm -f "$DATA_DIR/PG_VERSION"
    rm -rf "$DATA_DIR"/*
    runuser -u postgres -- $PG_BIN/initdb -D "$DATA_DIR" -A trust -U postgres
fi

# Step 5: Configure pg_hba.conf to allow connections from anywhere
configure_hba() {
    HBA_FILE="$DATA_DIR/pg_hba.conf"
    echo "🔧 Configuring pg_hba.conf..."
    
    # Add entries for Kubernetes network
    if ! grep -q "0.0.0.0/0" "$HBA_FILE"; then
        echo "host    all             all             0.0.0.0/0              trust" >> "$HBA_FILE"
    fi
}

configure_hba

# Step 6: Configure postgresql.conf to listen on all interfaces
if ! grep -q "listen_addresses = '\*'" "$DATA_DIR/postgresql.conf"; then
    echo "listen_addresses = '*'" >> "$DATA_DIR/postgresql.conf"
fi

# Step 7: Start PostgreSQL server in foreground
echo "🚀 Starting PostgreSQL server on port 5432..."

# Start server in background for initialization
runuser -u postgres -- $PG_BIN/postgres -D "$DATA_DIR" -F &
SERVER_PID=$!

# Wait for server to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 5

# Step 8: Initialize database and roles (from environment variables)
echo "🗄️  Initializing database and roles..."
PSQL="$PG_BIN/psql -h localhost -U postgres -w"

# Extract database info from environment
DB_NAME=${POSTGRES_DB:-billing}
DB_USER=${POSTGRES_USER:-billing_user}
DB_PASSWORD=${POSTGRES_PASSWORD:-billing_password}

# Create role if not exists
$PSQL <<-EOSQL
  CREATE ROLE $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD' LOGIN;
  ALTER ROLE $DB_USER CREATEDB;
  CREATE DATABASE $DB_NAME OWNER $DB_USER;
EOSQL

echo "✅ Database and roles initialized"

# Keep running
wait $SERVER_PID
