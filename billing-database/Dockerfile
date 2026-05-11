# Use the official, lightweight Alpine-based PostgreSQL image
FROM postgres:13-alpine

# The official image already handles initialization via /docker-entrypoint-initdb.d/
# and handles postgres users, data directories, and basic pg_hba.conf automatically.

# If you have custom initialization SQL scripts, you can copy them like this:
# COPY init.sql /docker-entrypoint-initdb.d/

EXPOSE 5432