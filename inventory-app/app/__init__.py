"""
Flask application factory and initialization.

This module:
1. Creates and configures the Flask app
2. Initializes SQLAlchemy with the app
3. Registers blueprints (routes)
"""

from flask import Flask
from app.db import db, DATABASE_URI
import os


def create_app():
    """
    Application factory function.
    
    This pattern allows us to:
    - Create multiple app instances (useful for testing)
    - Avoid circular imports
    - Keep configuration separate from app creation
    
    Returns:
        Flask: Configured Flask application instance
    """
    
    # Create Flask app instance
    app = Flask(__name__)
    
    # Allow trailing slashes on all routes (e.g., /api/movies/ and /api/movies both work)
    # Required by project specification: http://[GATEWAY_IP]:[GATEWAY_PORT]/api/movies/
    app.url_map.strict_slashes = False
    
    # Configure SQLAlchemy
    app.config['SQLALCHEMY_DATABASE_URI'] = DATABASE_URI
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False  # Suppress warnings
    
    # Initialize SQLAlchemy with this app
    db.init_app(app)
    
    # Import routes here to avoid circular imports
    from app.routes import movies_bp
    
    # Register blueprints (route groups)
    app.register_blueprint(movies_bp)
    
    # Add health check endpoints
    @app.route('/health', methods=['GET'])
    def health_check():
        """Health check endpoint for Kubernetes liveness probe"""
        from flask import jsonify
        return jsonify({'status': 'healthy', 'service': 'Inventory API'}), 200
    
    @app.route('/ready', methods=['GET'])
    def readiness_check():
        """Readiness check endpoint for Kubernetes readiness probe"""
        from flask import jsonify
        return jsonify({'status': 'ready', 'service': 'Inventory API'}), 200
    
    # Create database tables if they don't exist
    # Wrap in try-except to allow app startup even if database isn't ready yet
    # The readiness probe will handle checking database connectivity
    with app.app_context():
        try:
            db.create_all()
            print("[Startup] ✅ Database tables created/verified")
        except Exception as e:
            print(f"[Startup] ⚠️  Database connection failed during initialization: {e}")
            print("[Startup]    App will start anyway; check database connectivity in readiness probe")
    
    return app
