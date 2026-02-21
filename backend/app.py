from flask import Flask, request, jsonify
import requests

app = Flask(__name__)

# Health check endpoint
@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy'}), 200

# Authentication decorator
def authenticate_user():
    token = request.headers.get('Authorization')
    if not token:
        return jsonify({'message': 'Missing token'}), 401
    # Validate token here (e.g., against your user database or an auth provider)
    # Assuming a simple validation for example purposes:
    valid_tokens = ['token1', 'token2']
    if token not in valid_tokens:
        return jsonify({'message': 'Invalid token'}), 403

# Policy enforcement using OPA
def check_policy(user, action):
    opa_url = 'http://<opa-server>/v1/data/policies'
    response = requests.post(opa_url, json={'input': {'user': user, 'action': action}})
    return response.json().get('result', False)

# Example endpoint: Get user data
@app.route('/user/data', methods=['GET'])
@authenticate_user()
def get_user_data():
    user = request.headers.get('Authorization')
    if check_policy(user, 'get_user_data'):
        return jsonify({'data': 'User data here'}), 200
    return jsonify({'message': 'Permission denied'}), 403

# Example endpoint: Update user data
@app.route('/user/data', methods=['PUT'])
@authenticate_user()
def update_user_data():
    user = request.headers.get('Authorization')
    if check_policy(user, 'update_user_data'):
        data = request.json
        # Process update...
        return jsonify({'message': 'User data updated successfully'}), 200
    return jsonify({'message': 'Permission denied'}), 403

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
