from flask import Flask, request, jsonify
import os

app = Flask(__name__)

PORT = int(os.environ.get('PORT', 5000))

notifications = []

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'notification-service'}), 200

@app.route('/notifications', methods=['GET'])
def get_notifications():
    return jsonify(notifications), 200

@app.route('/notifications', methods=['POST'])
def send_notification():
    data = request.get_json()
    notification = {
        'id': len(notifications) + 1,
        'type': data.get('type', 'email'),
        'recipient': data.get('recipient'),
        'message': data.get('message'),
        'status': 'SENT'
    }
    notifications.append(notification)
    print(f"Notification sent: {notification}")
    return jsonify(notification), 201

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=PORT, debug=False)
