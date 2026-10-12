from flask import Flask, jsonify, request
from pymongo import MongoClient, DESCENDING
from datetime import datetime, timedelta
import certifi
import firebase_admin
from firebase_admin import credentials, messaging
import os
import json

# --- Configuration ---
app = Flask(__name__)
connection_string = "mongodb+srv://jp7737_db_user:janar29@cluster0.5umvusl.mongodb.net/?appName=Cluster0"
client = MongoClient(connection_string,tls=True, tlsCAFile=certifi.where())
db = client.allium_vault_db

readings_collection = db.readings
stock_history_collection = db.stock_history
device_tokens_collection = db.device_tokens

# --- NEW: Fan Mode State ---
# This keeps track of what mode the user selected (ON, OFF, or AUTO)
control_state = {"fan_mode": "AUTO"} 

# --- Firebase Setup ---
# Check for Environment Variable first (for Render)
firebase_json_env = os.environ.get("FIREBASE_CREDENTIALS_JSON")

try:
    if firebase_json_env:
        cred_dict = json.loads(firebase_json_env)
        cred = credentials.Certificate(cred_dict)
        firebase_admin.initialize_app(cred)
        print("Firebase initialized from environment variable!")
    elif os.path.exists("firebase-adminsdk.json"):
        cred = credentials.Certificate("firebase-adminsdk.json")
        firebase_admin.initialize_app(cred)
        print("Firebase initialized from local file!")
    else:
        print("WARNING: Firebase credentials not found.")
except Exception as e:
    print(f"Error initializing Firebase: {e}")
# --- Helper Functions ---

def send_fcm_notification(title, body, status):
    tokens = [doc['token'] for doc in device_tokens_collection.find()]
    # Deduplicate tokens
    tokens = list(set(tokens))
    if not tokens:
        print("DEBUG: No device tokens found in database.")
        return
    
    print(f"DEBUG: Sending FCM notification to {len(tokens)} token(s)...")
    try:
        message = messaging.MulticastMessage(
            notification=messaging.Notification(title=title, body=body),
            data={'status': status},
            tokens=tokens
        )
        response = messaging.send_each_for_multicast(message)
        print(f"DEBUG: FCM Response -> Success: {response.success_count}, Failure: {response.failure_count}")
        
        for idx, resp in enumerate(response.responses):
            if not resp.success:
                print(f"DEBUG: Token {tokens[idx]} failed: {resp.exception}")
                # Optional: remove dead tokens from DB
                if resp.exception.code in ['not-registered', 'invalid-argument']:
                    device_tokens_collection.delete_one({"token": tokens[idx]})
    except Exception as e:
        print(f"ERROR: Failed to send multicast message: {e}")
# --- Storage condition thresholds (ambient onion storage in godowns / warehouses) ---
TEMP_WARNING_C = 30      # above this: Warning
TEMP_DANGER_C = 35       # above this: Danger
HUMIDITY_WARNING = 75    # above this: Warning
HUMIDITY_DANGER = 85     # above this: Danger


def run_realtime_sensor_analysis(current_data):
    """
    Analyzes a single, real-time sensor reading and sends an alert if needed.

    Healthy : temperature <= 30 C and humidity <= 75 %
    Warning : temperature > 30 C or humidity > 75 %
    Danger  : temperature > 35 C or humidity > 85 %
    """
    try:
        temp = current_data.get('temperature')
        humidity = current_data.get('humidity')

        # A missing reading is a sensor/data problem, not a "healthy" reading
        if temp is None or humidity is None:
            print("DEBUG: Missing temperature or humidity in reading")
            return "Error"

        temp = float(temp)
        humidity = float(humidity)

        status = "Healthy"
        if temp > TEMP_DANGER_C or humidity > HUMIDITY_DANGER:
            status = "Danger"
        elif temp > TEMP_WARNING_C or humidity > HUMIDITY_WARNING:
            status = "Warning"

        print(f"DEBUG: Real-time sensor analysis -> Temp: {temp}, Humidity: {humidity}, Status: {status}")

        if status != "Healthy":
            send_fcm_notification(
                f"{'🔴' if status == 'Danger' else '🟡'} Storage Alert: {status} Condition!",
                f"Humidity: {humidity}%, Temperature: {temp}°C. Please check your stock.",
                status
            )
        return status
    except Exception as e:
        print(f"Error during real-time analysis: {e}")
        return "Error"

# --- API Endpoints ---

@app.route('/api/data', methods=['POST'])
def receive_data():
    """Receives sensor data and calculates fan runtime if fan is ON."""
    try:
        data = request.get_json()
        now = datetime.now()
        
        # --- CALCULATION FOR ENERGY MONITORING ---
        if control_state.get("fan_mode") == "ON":
            last_reading = readings_collection.find_one(sort=[("timestamp", DESCENDING)])
            if last_reading and 'timestamp' in last_reading:
                # Calculate time difference between this reading and the last one
                duration = (now - last_reading['timestamp']).total_seconds()
                data['fan_run_duration_s'] = duration

        data['timestamp'] = now
        status = run_realtime_sensor_analysis(data)
        data['status'] = status
        readings_collection.insert_one(data)
        return jsonify({"status": "success"}), 201
    except Exception as e: return jsonify({"error": str(e)}), 400

# NEW: Endpoint to change Fan mode from the Flutter App
@app.route('/api/fan-control', methods=['POST'])
def fan_control():
    try:
        mode = request.get_json().get('mode')
        if mode in ["ON", "OFF", "AUTO"]:
            control_state["fan_mode"] = mode
            return jsonify({"status": "success", "fan_mode": mode})
        return jsonify({"error": "Invalid mode"}), 400
    except Exception as e: return jsonify({"error": str(e)}), 400

# NEW: Endpoint to provide Energy data for the Dashboard
@app.route('/api/energy-report', methods=['GET'])
def get_energy_report():
    try:
        thirty_days_ago = datetime.now() - timedelta(days=30)
        pipeline = [
            {"$match": {"timestamp": {"$gte": thirty_days_ago}, "fan_run_duration_s": {"$exists": True}}},
            {"$group": {"_id": None, "total_seconds": {"$sum": "$fan_run_duration_s"}}}
        ]
        result = list(readings_collection.aggregate(pipeline))
        total_seconds = result[0]['total_seconds'] if result else 0
        total_hours = round(total_seconds / 3600, 2)
        
        # Calculation: (Total Hours * 0.050 kW per fan) * Rs. 5 per unit
        estimated_cost = round((total_hours * 0.050) * 5, 2)
        return jsonify({"total_hours": total_hours, "estimated_cost_inr": estimated_cost})
    except Exception as e: return jsonify({"error": str(e)}), 500

@app.route('/api/latest-data', methods=['GET'])
def get_latest_data():
    latest = readings_collection.find_one(sort=[("timestamp", DESCENDING)])
    if latest:
        latest.pop('_id', None)
        return jsonify(latest)
    return jsonify({"status": "No Data", "temperature": 0, "humidity": 0})

@app.route('/api/register-device', methods=['POST'])
@app.route('/api/register-device', methods=['POST'])
def register_device():
    try:
        data = request.get_json()
        token = data.get('token')
        if not token:
            return jsonify({"error": "No token provided"}), 400
        
        # Check if token already exists, if not insert it
        existing = device_tokens_collection.find_one({"token": token})
        if not existing:
            device_tokens_collection.insert_one({
                "token": token,
                "timestamp": datetime.now()
            })
            print(f"DEBUG: Registered new device token -> {token}")
        
        return jsonify({"status": "success"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 400
@app.route('/api/stock', methods=['POST'])
def add_stock():
    data = request.get_json()
    data['timestamp'] = datetime.now()
    stock_history_collection.insert_one(data)
    return jsonify({"status": "success"}), 201

@app.route('/api/stock-history', methods=['GET'])
def get_stock_history():
    history = list(stock_history_collection.find({}, {'_id': 0}).sort("arrival_date", DESCENDING))
    return jsonify(history)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)