from flask import Flask, jsonify, request
from pymongo import MongoClient, DESCENDING
from datetime import datetime, timedelta
import certifi
import firebase_admin
from firebase_admin import credentials, messaging

# --- Configuration ---
app = Flask(__name__)
connection_string = "mongodb+srv://jp7737_db_user:Simbajuly22@cluster0.5umvusl.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0"
client = MongoClient(connection_string, tlsCAFile=certifi.where())
db = client.allium_vault_db

readings_collection = db.readings
stock_history_collection = db.stock_history
device_tokens_collection = db.device_tokens

# --- NEW: Fan Mode State ---
# This keeps track of what mode the user selected (ON, OFF, or AUTO)
control_state = {"fan_mode": "AUTO"} 

# --- Firebase Setup ---
try:
    cred = credentials.Certificate("firebase-adminsdk.json")
    firebase_admin.initialize_app(cred)
    print("Firebase Admin SDK initialized successfully.")
except Exception as e:
    print(f"WARNING: Firebase not initialized. Error: {e}")

# --- Helper Functions ---

def send_fcm_notification(title, body, status):
    tokens = [doc['token'] for doc in device_tokens_collection.find()]
    if not tokens: return
    message = messaging.MulticastMessage(
        notification=messaging.Notification(title=title, body=body),
        data={'status': status}, tokens=tokens)
    messaging.send_each_for_multicast(message)

def run_realtime_sensor_analysis(current_data):
    try:
        temp = current_data.get('temperature', 0)
        humidity = current_data.get('humidity', 0)
        status = "Healthy"
        if humidity > 85 and temp > 32: status = "Danger"
        elif humidity > 80 and temp > 30: status = "Warning"
        
        if status != "Healthy":
            send_fcm_notification(
                f"AI Alert: {status}!",
                f"Hum: {humidity}%, Temp: {temp}°C. Check your onions.",
                status
            )
        return status
    except Exception as e: return "Error"

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
def register_device():
    token = request.get_json().get('token')
    if token:
        device_tokens_collection.update_one({'token': token}, {'$set': {'timestamp': datetime.now()}}, upsert=True)
        return jsonify({"status": "success"}), 200
    return jsonify({"error": "Token missing"}), 400

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