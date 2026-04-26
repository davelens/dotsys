#!/usr/bin/env bash
set -e

# Simple PostgreSQL client with autocompletion
sudo pacman -S --noconfirm --needed pgcli

# Ensure mise-installed binaries are in PATH
eval "$(mise activate bash 2>/dev/null || true)"

PGDATA="${PGDATA:-$HOME/.local/share/postgres/data}"

# Initialize PostgreSQL data directory if it doesn't exist
if [ ! -d "$PGDATA" ]; then
  echo "Initializing PostgreSQL data directory at $PGDATA..."
  initdb -D "$PGDATA" -U root --auth=trust
  FRESH_INSTALL=true
else
  FRESH_INSTALL=false
fi

# Check if server is already running
if pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
  SERVER_WAS_RUNNING=true
else
  SERVER_WAS_RUNNING=false
  pg_ctl -D "$PGDATA" -l "$PGDATA/logfile" start -w
fi

# Configure root user
if [ "$FRESH_INSTALL" = true ]; then
  # Fresh install: root user already exists as superuser, just set password
  psql -U root -d postgres -c "ALTER USER root WITH PASSWORD 'root';"
else
  # Existing install: create root user if it doesn't exist. The bootstrap
  # superuser may be the current OS user when the cluster was not made here.
  SUPERUSER=""
  SUPERUSER_CANDIDATES=(root postgres "$USER")
  for candidate in "${SUPERUSER_CANDIDATES[@]}"; do
    if [ -n "$candidate" ] && [ -z "$SUPERUSER" ]; then
      SUPERUSER=$(psql -U "$candidate" -d postgres -tAc "SELECT current_user FROM pg_roles WHERE rolname = current_user AND rolsuper;" 2>/dev/null || echo "")
    fi
  done
  if [ -z "$SUPERUSER" ]; then
    echo "Error: Could not find a superuser to connect with"
    exit 1
  fi

  # Create root user if it doesn't exist, or update password if it does
  psql -q -U "$SUPERUSER" -d postgres -c "
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'root') THEN
        CREATE USER root WITH SUPERUSER PASSWORD 'root';
      ELSE
        ALTER USER root WITH PASSWORD 'root';
      END IF;
    END
    \$\$;
  "
fi

# Only stop the server if we started it
if [ "$SERVER_WAS_RUNNING" = false ]; then
  pg_ctl -D "$PGDATA" stop -w
fi

echo "PostgreSQL configured with user 'root' and password 'root'"
