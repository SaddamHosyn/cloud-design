#!/usr/bin/env python3
from dotenv import load_dotenv
import os
from pathlib import Path

env_candidates = [
    Path('/app/.env'),
    Path('/home/vagrant/.env'),
    Path('./.env'),
    Path(__file__).resolve().parent.parent.parent / '.env'
]
for env_file in env_candidates:
    if env_file.exists():
        load_dotenv(env_file, override=True)
        break

from app import create_app

os.environ.setdefault('INVENTORY_DB_HOST', 'localhost')
os.environ.setdefault('INVENTORY_DB_PORT', '5432')
os.environ.setdefault('INVENTORY_DB_NAME', 'inventory')
os.environ.setdefault('INVENTORY_DB_USER', 'inventoryuser')
os.environ.setdefault('INVENTORY_PORT', '8080')

required_env_vars = [
    'INVENTORY_DB_USER',
    'INVENTORY_DB_PASSWORD',
    'INVENTORY_DB_HOST',
    'INVENTORY_DB_PORT',
    'INVENTORY_DB_NAME',
    'INVENTORY_PORT'
]

missing_vars = [var for var in required_env_vars if not os.environ.get(var)]
if missing_vars:
    print(f"WARNING: Missing environment variables: {', '.join(missing_vars)}")

# THIS IS THE FIX: app is created at module level, not inside if __name__ == '__main__'
app = create_app()

with app.app_context():
    from app.db import db
    db.create_all()
    print("Database tables ready!")

if __name__ == '__main__':
    host = '0.0.0.0'
    port = int(os.environ['INVENTORY_PORT'])
    app.run(host=host, port=port, debug=False)