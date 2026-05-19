#!/bin/sh
set -e

echo "Starting api-gateway without blocking on downstream dependencies..."
exec python server.py