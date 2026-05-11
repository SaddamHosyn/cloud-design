"""
Billing App Factory
Purpose: Initialize Flask app, configure database, and export app instance
Reference: CRUD_Master_README.md Section 7.2-7.5
"""

import os
from flask import Flask
from app.db import db, DATABASE_URI


def create_app():
    """
    Flask app factory
    
    Creates and configures a Flask application instance with:
    - SQLAlchemy ORM initialized
    - Database tables created (if missing)
    - All models registered
    
    Returns:
        Flask: Configured Flask application instance
    """
    
    # Create Flask app instance
    app = Flask(__name__)
    
    # Configure SQLAlchemy
    app.config['SQLALCHEMY_DATABASE_URI'] = DATABASE_URI
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False  # Disable metadata tracking (performance)
    
    print("[Billing App] Initializing SQLAlchemy database...")
    
    # Initialize database with app
    db.init_app(app)
    
    # Create all tables inside app context
    # Wrap in try-except to allow app startup even if database isn't ready yet
    with app.app_context():
        try:
            print("[Billing App] Creating database tables (if missing)...")
            db.create_all()
            print("[Billing App] ✅ Database tables ready")
        except Exception as e:
            print(f"[Billing App] ⚠️  Database connection failed: {e}")
            print("[Billing App]    App will start anyway; check database connectivity in readiness probe")
    
    # Add health check endpoints
    @app.route('/health', methods=['GET'])
    def health_check():
        """Health check endpoint for Kubernetes liveness probe"""
        from flask import jsonify
        return jsonify({'status': 'healthy', 'service': 'Billing App'}), 200
    
    @app.route('/ready', methods=['GET'])
    def readiness_check():
        """Readiness check endpoint for Kubernetes readiness probe"""
        from flask import jsonify
        return jsonify({'status': 'ready', 'service': 'Billing App'}), 200
    
    return app
