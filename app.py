from flask import Flask, request, jsonify
from flask_cors import CORS
from datetime import datetime
import requests
import os
import logging

app = Flask(__name__)
CORS(app)

# Configuration
OPA_URL = os.getenv('OPA_URL', 'http://opa:8181')
DEVICE_POSTURE_URL = os.getenv('DEVICE_POSTURE_URL', 'http://device-posture:8082')

# Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Données mock
MOCK_USERS = {
    'admin-001': {
        'user_id': 'admin-001',
        'email': 'admin@zerotrust.local',
        'full_name': 'Admin User',
        'department': 'IT Security',
        'clearance_level': 'top_secret',
        'realm_access': {'roles': ['admin']}
    },
    'manager-001': {
        'user_id': 'manager-001',
        'email': 'manager@zerotrust.local',
        'full_name': 'Manager User',
        'department': 'Operations',
        'clearance_level': 'secret',
        'realm_access': {'roles': ['manager']}
    },
    'user-001': {
        'user_id': 'user-001',
        'email': 'user@zerotrust.local',
        'full_name': 'Regular User',
        'department': 'Engineering',
        'clearance_level': 'confidential',
        'realm_access': {'roles': ['user']}
    },
    'guest-001': {
        'user_id': 'guest-001',
        'email': 'guest@zerotrust.local',
        'full_name': 'Guest User',
        'department': 'External',
        'clearance_level': 'public',
        'realm_access': {'roles': ['guest']}
    }
}

MOCK_DATA = [
    {'id': 1, 'title': 'Public Info', 'classification': 'public', 'sensitive': False},
    {'id': 2, 'title': 'Internal Memo', 'classification': 'internal', 'sensitive': False},
    {'id': 3, 'title': 'Financial Report', 'classification': 'confidential', 'sensitive': True},
    {'id': 4, 'title': 'Security Audit', 'classification': 'secret', 'sensitive': True},
    {'id': 5, 'title': 'Incident Plan', 'classification': 'top_secret', 'sensitive': True}
]

# ============================================
# FONCTIONS UTILITAIRES
# ============================================
def check_opa(user_info, device_info, method, path):
    """Vérifie les permissions via OPA"""
    try:
        opa_input = {
            "input": {
                "user": user_info,
                "device": device_info,
                "method": method,
                "path": path.strip('/').split('/')
            }
        }
        
        logger.info(f"🔍 Vérification OPA: {opa_input}")
        
        response = requests.post(
            f"{OPA_URL}/v1/data/zerotrust/allow",
            json=opa_input,
            timeout=5
        )
        
        if response.status_code == 200:
            result = response.json().get('result', False)
            logger.info(f"✅ Réponse OPA: {result}")
            return result
        else:
            logger.error(f"❌ Erreur OPA: {response.status_code}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Exception OPA: {e}")
        return False  # Zero Trust: en cas de doute, on refuse

def get_device_info(device_id, user_id):
    """Récupère les infos du device"""
    try:
        response = requests.post(
            f"{DEVICE_POSTURE_URL}/api/check",
            json={"device_id": device_id, "user_id": user_id},
            timeout=5
        )
        
        if response.status_code == 200:
            data = response.json()
            return {
                "trusted": data.get('trusted', False),
                "compliance_score": data.get('compliance_score', 0),
                "trust_level": data.get('trust_level', 'unknown'),
                "device_id": device_id
            }
    except Exception as e:
        logger.error(f"❌ Erreur device posture: {e}")
    
    return {"trusted": False, "compliance_score": 0, "trust_level": "unknown", "device_id": device_id}

# ============================================
# ENDPOINTS
# ============================================
@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        'status': 'healthy',
        'service': 'backend',
        'timestamp': datetime.utcnow().isoformat(),
        'opa_connected': check_opa_connection(),
        'device_posture_connected': check_device_posture_connection()
    })

def check_opa_connection():
    try:
        response = requests.get(f"{OPA_URL}/health", timeout=2)
        return response.status_code == 200
    except:
        return False

def check_device_posture_connection():
    try:
        response = requests.get(f"{DEVICE_POSTURE_URL}/health", timeout=2)
        return response.status_code == 200
    except:
        return False

@app.route('/public/info', methods=['GET'])
def public_info():
    return jsonify({
        'message': 'Zero Trust Demo API',
        'version': '1.0.0',
        'status': 'operational',
        'endpoints': [
            '/public/info',
            '/api/profile',
            '/api/data',
            '/api/admin/users',
            '/api/diagnostic'
        ]
    })

@app.route('/api/profile', methods=['GET'])
def get_profile():
    # Récupérer les headers
    user_id = request.headers.get('X-User-Id')
    device_id = request.headers.get('X-Device-Id')
    
    if not user_id or not device_id:
        return jsonify({'error': 'Missing credentials'}), 401
    
    # Récupérer les infos
    device_info = get_device_info(device_id, user_id)
    user = MOCK_USERS.get(user_id)
    
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    # Vérifier via OPA
    if not check_opa(user, device_info, 'GET', '/api/profile'):
        return jsonify({
            'error': 'Access denied by Zero Trust policy',
            'reason': 'Policy violation',
            'device_trusted': device_info['trusted'],
            'device_score': device_info['compliance_score']
        }), 403
    
    return jsonify({
        'user': user,
        'device': device_info,
        'access_granted': True
    })

@app.route('/api/data', methods=['GET'])
def get_data():
    user_id = request.headers.get('X-User-Id')
    device_id = request.headers.get('X-Device-Id')
    
    if not user_id or not device_id:
        return jsonify({'error': 'Missing credentials'}), 401
    
    device_info = get_device_info(device_id, user_id)
    user = MOCK_USERS.get(user_id)
    
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    if not check_opa(user, device_info, 'GET', '/api/data'):
        return jsonify({'error': 'Access denied'}), 403
    
    # Filtrer les données selon le rôle
    roles = user.get('realm_access', {}).get('roles', [])
    
    if 'admin' in roles:
        accessible_data = MOCK_DATA
    elif 'manager' in roles:
        accessible_data = [d for d in MOCK_DATA if d['classification'] in ['public', 'internal', 'confidential']]
    elif 'user' in roles:
        accessible_data = [d for d in MOCK_DATA if d['classification'] in ['public', 'internal']]
    else:
        accessible_data = [d for d in MOCK_DATA if d['classification'] == 'public']
    
    return jsonify({
        'data': accessible_data,
        'user_role': roles,
        'device_trusted': device_info['trusted'],
        'total': len(accessible_data)
    })

@app.route('/api/admin/users', methods=['GET'])
def admin_get_users():
    user_id = request.headers.get('X-User-Id')
    device_id = request.headers.get('X-Device-Id')
    
    if not user_id or not device_id:
        return jsonify({'error': 'Missing credentials'}), 401
    
    device_info = get_device_info(device_id, user_id)
    user = MOCK_USERS.get(user_id)
    
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    if not check_opa(user, device_info, 'GET', '/api/admin/users'):
        return jsonify({'error': 'Admin access required'}), 403
    
    return jsonify({
        'users': list(MOCK_USERS.values()),
        'total': len(MOCK_USERS)
    })

@app.route('/api/diagnostic', methods=['GET'])
def diagnostic():
    """Endpoint de diagnostic complet"""
    user_id = request.headers.get('X-User-Id', 'unknown')
    device_id = request.headers.get('X-Device-Id', 'unknown')
    
    # Récupérer les infos
    device_info = get_device_info(device_id, user_id)
    user = MOCK_USERS.get(user_id, {})
    
    # Tester OPA
    opa_test = {
        "input": {
            "user": user,
            "device": device_info,
            "method": "GET",
            "path": ["api", "diagnostic"]
        }
    }
    
    opa_result = None
    try:
        response = requests.post(
            f"{OPA_URL}/v1/data/zerotrust/diagnostic",
            json=opa_test,
            timeout=5
        )
        if response.status_code == 200:
            opa_result = response.json()
    except Exception as e:
        opa_result = {"error": str(e)}
    
    return jsonify({
        "timestamp": datetime.utcnow().isoformat(),
        "user": {
            "id": user_id,
            "exists": user_id in MOCK_USERS,
            "roles": user.get('realm_access', {}).get('roles', []) if user else []
        },
        "device": device_info,
        "opa_diagnostic": opa_result,
        "system_status": {
            "opa_connected": check_opa_connection(),
            "device_posture_connected": check_device_posture_connection()
        }
    })

if __name__ == '__main__':
    logger.info("🚀 Zero Trust Backend Starting...")
    logger.info(f"📡 OPA URL: {OPA_URL}")
    logger.info(f"📡 Device Posture URL: {DEVICE_POSTURE_URL}")
    app.run(host='0.0.0.0', port=5000, debug=True)