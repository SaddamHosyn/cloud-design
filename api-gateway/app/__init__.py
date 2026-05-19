"""
API Gateway App Factory
Purpose: Initialize Flask app with proxy and publisher routes

Routes:
- /api/movies/* -> HTTP proxy to Inventory API
- /api/billing POST -> Publish to RabbitMQ queue (not HTTP proxy)
"""

import os
import json
from functools import wraps

from flask import Flask, jsonify, request, g
import requests
import pika
import jwt
from jwt import PyJWKClient


def create_app():
    app = Flask(__name__)

    INVENTORY_URL = os.environ.get('INVENTORY_SERVICE_URL', 'http://localhost:8080')
    BILLING_URL = os.environ.get('BILLING_SERVICE_URL', 'http://localhost:8080')

    print(f"[Gateway] Inventory API target: {INVENTORY_URL}")
    print(f"[Gateway] Billing App target: {BILLING_URL}")

    COGNITO_REGION = os.environ.get("COGNITO_REGION")
    COGNITO_USER_POOL_ID = os.environ.get("COGNITO_USER_POOL_ID")
    COGNITO_APP_CLIENT_ID = os.environ.get("COGNITO_APP_CLIENT_ID")

    cognito_enabled = all([COGNITO_REGION, COGNITO_USER_POOL_ID, COGNITO_APP_CLIENT_ID])

    if cognito_enabled:
        issuer = f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}"
        jwks_url = f"{issuer}/.well-known/jwks.json"
        jwk_client = PyJWKClient(jwks_url)
        print(f"[Gateway] Cognito JWT verification ENABLED")
        print(f"[Gateway] Cognito issuer: {issuer}")
        print(f"[Gateway] Cognito app client id: {COGNITO_APP_CLIENT_ID}")
    else:
        issuer = None
        jwk_client = None
        print("[Gateway] Cognito JWT verification DISABLED (missing env vars)")

    def extract_bearer_token():
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return None
        return auth_header.split(" ", 1)[1].strip()

    def verify_cognito_token(token):
        signing_key = jwk_client.get_signing_key_from_jwt(token).key

        unverified = jwt.decode(
            token,
            options={
                "verify_signature": False,
                "verify_exp": False,
                "verify_aud": False,
            },
        )

        token_use = unverified.get("token_use")

        decoded = jwt.decode(
            token,
            signing_key,
            algorithms=["RS256"],
            issuer=issuer,
            options={
                "require": ["exp", "iat", "iss"],
                "verify_aud": False,
            },
        )

        if token_use not in ["id", "access"]:
            raise jwt.InvalidTokenError("Invalid token_use")

        if token_use == "id":
            if decoded.get("aud") != COGNITO_APP_CLIENT_ID:
                raise jwt.InvalidTokenError("Invalid audience/app client id")

        if token_use == "access":
            if decoded.get("client_id") != COGNITO_APP_CLIENT_ID:
                raise jwt.InvalidTokenError("Invalid client_id")

        return decoded

    def require_auth(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            if not cognito_enabled:
                return jsonify({
                    "error": "Authentication is not configured",
                    "message": "Missing Cognito environment variables in API Gateway"
                }), 500

            token = extract_bearer_token()
            if not token:
                return jsonify({
                    "error": "Unauthorized",
                    "message": "Missing Bearer token"
                }), 401

            try:
                claims = verify_cognito_token(token)
                g.user_claims = claims
                g.user_sub = claims.get("sub")
                g.user_email = claims.get("email")
                return fn(*args, **kwargs)
            except jwt.ExpiredSignatureError:
                return jsonify({
                    "error": "Unauthorized",
                    "message": "Token has expired"
                }), 401
            except jwt.InvalidTokenError as e:
                return jsonify({
                    "error": "Unauthorized",
                    "message": f"Invalid token: {str(e)}"
                }), 401
            except Exception as e:
                return jsonify({
                    "error": "Authentication verification failed",
                    "message": str(e)
                }), 401

        return wrapper

    def forward_headers():
        headers = dict(request.headers)
        headers.pop("Host", None)
        return headers

    @app.route('/api/movies', methods=['GET', 'POST', 'DELETE'], strict_slashes=False)
    @require_auth
    def proxy_movies_list():
        try:
            target_url = f"{INVENTORY_URL}/api/movies"

            response = requests.request(
                method=request.method,
                url=target_url,
                json=request.get_json(silent=True) if request.method in ['POST', 'PUT'] else None,
                params=request.args,
                headers=forward_headers(),
                timeout=10
            )

            excluded_headers = ['content-encoding', 'content-length', 'transfer-encoding', 'connection']
            response_headers = [(name, value) for name, value in response.raw.headers.items() if name.lower() not in excluded_headers]
            return response.content, response.status_code, response_headers

        except requests.exceptions.ConnectionError:
            return jsonify({
                'error': 'Inventory API is unreachable',
                'message': f'Could not reach {INVENTORY_URL}'
            }), 502
        except requests.exceptions.Timeout:
            return jsonify({
                'error': 'Inventory API timeout',
                'message': 'Request to inventory API took too long'
            }), 504
        except Exception as e:
            return jsonify({
                'error': 'Gateway error',
                'message': str(e)
            }), 500

    @app.route('/api/movies/<int:movie_id>', methods=['GET', 'PUT', 'DELETE'], strict_slashes=False)
    @require_auth
    def proxy_movies_by_id(movie_id):
        try:
            target_url = f"{INVENTORY_URL}/api/movies/{movie_id}"

            response = requests.request(
                method=request.method,
                url=target_url,
                json=request.get_json(silent=True) if request.method in ['POST', 'PUT'] else None,
                params=request.args,
                headers=forward_headers(),
                timeout=10
            )

            excluded_headers = ['content-encoding', 'content-length', 'transfer-encoding', 'connection']
            response_headers = [(name, value) for name, value in response.raw.headers.items() if name.lower() not in excluded_headers]
            return response.content, response.status_code, response_headers

        except requests.exceptions.ConnectionError:
            return jsonify({
                'error': 'Inventory API is unreachable',
                'message': f'Could not reach {INVENTORY_URL}'
            }), 502
        except requests.exceptions.Timeout:
            return jsonify({
                'error': 'Inventory API timeout',
                'message': 'Request to inventory API took too long'
            }), 504
        except Exception as e:
            return jsonify({
                'error': 'Gateway error',
                'message': str(e)
            }), 500

    @app.route('/api/billing', methods=['POST'], strict_slashes=False)
    @require_auth
    def publish_to_billing_queue():
        try:
            order_data = request.get_json(silent=True)

            if not order_data:
                return jsonify({'error': 'Request body is required (JSON)'}), 400

            required_fields = ['user_id', 'number_of_items', 'total_amount']
            missing = [f for f in required_fields if f not in order_data]

            if missing:
                return jsonify({
                    'error': 'Missing required fields',
                    'missing_fields': missing
                }), 400

            rabbitmq_host = os.environ.get('RABBITMQ_HOST', 'localhost')
            rabbitmq_port = int(os.environ.get('RABBITMQ_PORT', '5672'))
            rabbitmq_user = os.environ['RABBITMQ_USER']
            rabbitmq_password = os.environ['RABBITMQ_PASSWORD']
            rabbitmq_queue = os.environ.get('RABBITMQ_QUEUE', 'billing_queue')

            print(f"[Gateway] Publishing order to RabbitMQ/queue: {rabbitmq_queue}")
            print(f"[Gateway] Order data: {order_data}")
            print(f"[Gateway] Authenticated user sub: {g.get('user_sub')}")

            credentials = pika.PlainCredentials(rabbitmq_user, rabbitmq_password)
            params = pika.ConnectionParameters(
                host=rabbitmq_host,
                port=rabbitmq_port,
                credentials=credentials,
                heartbeat=600,
                blocked_connection_timeout=300
            )

            connection = pika.BlockingConnection(params)
            channel = connection.channel()
            channel.queue_declare(queue=rabbitmq_queue, durable=True)

            channel.basic_publish(
                exchange='',
                routing_key=rabbitmq_queue,
                body=json.dumps(order_data),
                properties=pika.BasicProperties(delivery_mode=2)
            )

            print("[Gateway] Order published to RabbitMQ queue")
            connection.close()

            return jsonify({
                'message': 'Order accepted and queued for processing',
                'order': order_data
            }), 200

        except pika.exceptions.ProbableAuthenticationError:
            return jsonify({'error': 'RabbitMQ authentication failed'}), 503
        except pika.exceptions.AMQPConnectionError:
            return jsonify({
                'error': 'Cannot connect to RabbitMQ',
                'message': f'RabbitMQ server at {rabbitmq_host}:{rabbitmq_port} is unreachable'
            }), 503
        except Exception as e:
            return jsonify({
                'error': 'Error publishing order to queue',
                'message': str(e)
            }), 500

    @app.route('/health', methods=['GET'], strict_slashes=False)
    def health_check():
        return jsonify({
            'status': 'healthy',
            'service': 'API Gateway',
            'inventory_api': f"{INVENTORY_URL}",
            'rabbit_mq_host': os.environ.get('RABBITMQ_HOST', 'localhost')
        }), 200

    @app.route('/ready', methods=['GET'], strict_slashes=False)
    def readiness_check():
        return jsonify({
            'status': 'ready',
            'service': 'API Gateway'
        }), 200

    return app