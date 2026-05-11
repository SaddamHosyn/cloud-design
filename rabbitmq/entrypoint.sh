#!/bin/bash

echo "🚀 Starting RabbitMQ server..."

# Ensure RabbitMQ data directory has proper permissions
mkdir -p /var/lib/rabbitmq
chmod -R 700 /var/lib/rabbitmq
chown -R rabbitmq:rabbitmq /var/lib/rabbitmq

# Enable RabbitMQ management plugin (for monitoring)
/usr/lib/rabbitmq/bin/rabbitmq-plugins enable rabbitmq_management 2>/dev/null || true

# Start RabbitMQ server in background first to configure it
echo "⏳ Starting RabbitMQ server (background)..."
/usr/lib/rabbitmq/bin/rabbitmq-server -detached

# Wait for RabbitMQ to fully start
sleep 8

# Check if user already exists, create if not
# Use RABBITMQ_DEFAULT_USER env var (set by K8s secret) instead of hardcoded username
RMQ_USER="${RABBITMQ_DEFAULT_USER:-rabbitmq_user}"
RMQ_PASS="${RABBITMQ_DEFAULT_PASS:-${RABBITMQ_PASSWORD}}"
echo "🔑 Setting up RabbitMQ user: ${RMQ_USER}..."
/usr/lib/rabbitmq/bin/rabbitmqctl list_users 2>/dev/null | grep -q "${RMQ_USER}" || \
  /usr/lib/rabbitmq/bin/rabbitmqctl add_user "${RMQ_USER}" "${RMQ_PASS}"

# Set user permissions for all vhosts and operations
/usr/lib/rabbitmq/bin/rabbitmqctl set_permissions -p / "${RMQ_USER}" ".*" ".*" ".*" 2>/dev/null || true

echo "✅ RabbitMQ configuration complete"

# Stop the background process
echo "⏳ Restarting RabbitMQ..."
/usr/lib/rabbitmq/bin/rabbitmqctl stop 2>/dev/null || true
sleep 3

# Start RabbitMQ server in foreground for Docker
echo "🚀 Starting RabbitMQ in foreground..."
exec /usr/lib/rabbitmq/bin/rabbitmq-server
