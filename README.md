
# 🧅 Allium Vault: Smart Onion Storage Management System

![SIH 2025](https://img.shields.io/badge/Event-Smart%20India%20Hackathon%202025-blueviolet)
![Status](https://img.shields.io/badge/Status-Functional-success)
![Python](https://img.shields.io/badge/Python-Flask-blue)
![Flutter](https://img.shields.io/badge/Flutter-Cross--Platform-teal)
![Database](https://img.shields.io/badge/Database-MongoDB%20Atlas-green)
![Cloud Messaging](https://img.shields.io/badge/FCM-Push%20Notifications-orange)

## 📌 Problem Statement
Developed for the **Smart India Hackathon (SIH) 2025**, **Allium Vault** is an end-to-end IoT and AI-driven solution designed to combat the critical national problem of post-harvest onion spoilage in agricultural godowns and warehouses. Onions are highly sensitive to environmental fluctuations; improper ventilation and high humidity lead to massive agricultural losses. Allium Vault automates storage monitoring, predicts spoilage risks, and triggers automated climate control and instant alerts.

---

## 🚀 Key Features
* **Real-Time Telemetry:** Continuously tracks Temperature, Humidity, and Gas levels (PPM) via sensor nodes or API telemetry.
* **Intelligent Risk Analysis:** A Python Flask backend evaluates storage health across a three-tier condition model: **Healthy**, **Warning**, and **Danger**.
* **Instant Cloud Push Notifications:** Leverages **Firebase Cloud Messaging (FCM)** and the Firebase Admin SDK to send immediate push alerts to managers when high-risk conditions are detected.
* **Energy Intelligence & Cost Tracking:** Calculates equipment runtime and provides live electricity cost estimates (INR) over a 30-day reporting window.
* **Remote Fan Control:** A Flutter mobile dashboard enables users to toggle storage fans between **ON**, **OFF**, and **AUTO** modes from anywhere.
* **Stock Inventory Management:** Tracks onion storage quantities and arrival timestamps with secure cloud database synchronization.

---

## 🛠️ Tech Stack

### **Hardware**
* **Microcontroller:** ESP32
* **Sensors:** Temperature (DHT), Humidity (DHT), and Gas (MQ series for spoilage gas detection)

### **Software**
* **Mobile App:** Flutter (State management via `Provider`)
* **Backend:** Python Flask (RESTful microservice API)
* **Database:** MongoDB Atlas (Cloud NoSQL document store with TLS enabled)
* **Cloud & Messaging:** Firebase Cloud Messaging (FCM) & Firebase Admin SDK

---

## 🏗️ System Architecture Flow
1. **Data Acquisition:** The ESP32 sensor node (or testing script) pushes real-time telemetry data to the Flask REST API via HTTP POST requests.
2. **Processing & Storage:** The backend analyzes environmental parameters, calculates energy metrics, and securely logs timestamped records into MongoDB Atlas.
3. **Alert Dispatch:** If conditions exceed safety thresholds, the Flask backend invokes the Firebase Admin SDK to broadcast an FCM multicast notification.
4. **Mobile Client Sync:** The Flutter mobile app periodically polls telemetry data, handles foreground/background push notifications, and presents real-time alerts via custom UI components.

---

## ⚡ Energy Calculation Logic
The system tracks fan runtime and estimates electricity costs assuming a standard 50W ventilation load and configurable tariff rates (e.g., ₹5 per kWh).

---

## 🔧 Installation & Setup

### **1. Backend Setup (Flask)**
```bash
# Clone the repository
git clone [https://github.com/your-username/Allium_Vault.git](https://github.com/your-username/Allium_Vault.git)
cd Allium_Vault/allium_vault_final

# Create and activate a virtual environment
python -m venv venv
source venv/bin/activate  # On Windows use: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run the Flask development server
python app.py

```

### **2. Frontend Setup (Flutter)**

```bash
cd ../allium_vault_frontend

# Install dependencies
flutter pub get

# Update the IP address or API endpoint in lib/main.dart, then run:
flutter run

```

---

## 📱 Testing API Endpoints via `curl`

You can test the real-time threshold analysis and notification triggers using the following `curl` commands:

* **Danger State (Triggers Push Notification):**
```bash
curl -X POST [http://127.0.0.1:5000/api/data](http://127.0.0.1:5000/api/data) \
-H "Content-Type: application/json" \
-d '{"temperature": 38.5, "humidity": 88.0}'

```


* **Warning State:**
```bash
curl -X POST [http://127.0.0.1:5000/api/data](http://127.0.0.1:5000/api/data) \
-H "Content-Type: application/json" \
-d '{"temperature": 32.0, "humidity": 78.0}'

```


* **Healthy State:**
```bash
curl -X POST [http://127.0.0.1:5000/api/data](http://127.0.0.1:5000/api/data) \
-H "Content-Type: application/json" \
-d '{"temperature": 25.0, "humidity": 60.0}'

```

