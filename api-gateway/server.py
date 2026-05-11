"""
API Gateway Entry Point
Purpose: Start the API Gateway server
Reference: CRUD_Master_README.md Section 8.4

The API Gateway is the single entry point for all external client requests:
- Routes HTTP requests to appropriate backend services
- Proxies /api/movies/* to Inventory API
- Publishes /api/billing events to RabbitMQ queue
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv

# CRITICAL: Load environment variables FIRST (before importing app)
env_candidates = [
    Path('/app/.env'),  # Docker container path
    Path('/home/vagrant/.env'),  # Vagrant path
    Path('./.env'),  # Current directory (development)
    Path(__file__).resolve().parent.parent.parent / '.env'  # Fallback: up from /app/server.py
]
for env_file in env_candidates:
    if env_file.exists():
        load_dotenv(env_file, override=True)
        break

from app import create_app


def main():
    """
    Main entry point for API Gateway service
    
    Sequence:
    1. Load .env file (if present, for development)
    2. Validate environment variables (with defaults for Kubernetes)
    3. Create Flask app
    4. Start server on configured port (default 3000)
    """
    
    print("=" * 70)
    print("🚪 API GATEWAY - Starting HTTP Server")
    print("=" * 70)
    
    # Get environment variables with defaults for Kubernetes
    # Kubernetes provides INVENTORY_SERVICE_URL and BILLING_SERVICE_URL
    # Default to Docker Compose style if not in Kubernetes
    inventory_url = os.environ.get('INVENTORY_SERVICE_URL', 'http://localhost:8080')
    billing_url = os.environ.get('BILLING_SERVICE_URL', 'http://localhost:8081')
    gateway_port = int(os.environ.get('PORT', os.environ.get('GATEWAY_PORT', '3000')))
    
    # Optional RabbitMQ configuration (used if available)
    rabbitmq_host = os.environ.get('RABBITMQ_HOST', 'localhost')
    rabbitmq_port = os.environ.get('RABBITMQ_PORT', '5672')
    
    print("\n[Startup] Environment Configuration:")
    print(f"  ✅ INVENTORY_SERVICE_URL: {inventory_url}")
    print(f"  ✅ BILLING_SERVICE_URL: {billing_url}")
    print(f"  ✅ GATEWAY_PORT: {gateway_port}")
    print(f"  ✅ RABBITMQ_HOST: {rabbitmq_host}:{rabbitmq_port}")
    
    print("\n[Startup] ✅ All environment variables validated")
    
    # Create Flask app
    print("\n[Startup] Creating Flask application...")
    app = create_app()
    print("[Startup] ✅ Flask app created with routes registered")
    
    print("\n[Startup] ✅ All initialization complete")
    print("[Startup] Starting Flask development server...")
    print("-" * 70)
    print("\n📍 API GATEWAY is listening on: http://0.0.0.0:{}\n".format(gateway_port))
    print("📍 Proxying /api/movies/* to Inventory API: {}".format(inventory_url))
    print("📍 Proxying /api/billing/* to Billing API: {}".format(billing_url))
    print("📍 RabbitMQ available at: {}:{}".format(rabbitmq_host, rabbitmq_port))
    print("\n" + "-" * 70 + "\n")
    
    # Available endpoints
    print("Available API Gateway endpoints:")
    print("  GET    /api/movies           → Get all movies (supports ?title=filter)")
    print("  POST   /api/movies           → Create a new movie")
    print("  DELETE /api/movies           → Delete all movies")
    print("  GET    /api/movies/{id}      → Get movie by ID")
    print("  PUT    /api/movies/{id}      → Update movie by ID")
    print("  DELETE /api/movies/{id}      → Delete movie by ID")
    print("  POST   /api/billing          → Create order (publish to RabbitMQ)")
    print("  GET    /health               → Health check")
    print("")
    
    # Start Flask development server
    try:
        app.run(
            host='0.0.0.0',
            port=gateway_port,
            debug=False,  # Set to False for production; True for development
            use_reloader=False  # Disable reloader for PM2 compatibility
        )
    except KeyboardInterrupt:
        print("\n" + "-" * 70)
        print("[Shutdown] Received keyboard interrupt")
    except Exception as e:
        print(f"\n[Error] Fatal error: {e}")
        sys.exit(1)
    finally:
        print("[Shutdown] ✅ API Gateway stopped")
        print("=" * 70)


if __name__ == '__main__':
    main()
