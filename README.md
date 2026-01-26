🧅 Allium Vault: Smart Onion Storage Management System

Allium Vault** is an end-to-end IoT and AI-driven solution developed for the **Smart India Hackathon (SIH) 2025**. It addresses the critical national problem of post-harvest onion spoilage by providing farmers with real-time monitoring, predictive risk analysis, and energy-efficient climate control.

📌 Problem Statement

Smart Onion Storage Management System (SIH 2025):** Onions are highly sensitive to environmental fluctuations. Improper ventilation and high humidity levels lead to massive post-harvest losses in India. Allium Vault automates storage monitoring to predict and prevent spoilage before it happens.



 🚀 Key Features

Real-Time Monitoring:** Tracks Temperature, Humidity, and Gas levels (PPM) using an ESP32-based sensor node.
AI-Driven Risk Analysis:** A Python Flask backend classifies storage health into **Healthy**, **Warning**, or **Danger** states based on agricultural safety thresholds.
Instant Alerts:** Leverages **Firebase Cloud Messaging (FCM)** to send immediate push notifications to farmers when high-risk conditions are detected.
Energy Intelligence:** A custom algorithm calculates fan runtime and provides live **electricity cost estimates (INR)**, allowing for better overhead management.
Remote Control:** A Flutter-based mobile dashboard allows users to toggle storage fans between **ON**, **OFF**, and **AUTO** modes from anywhere.


🛠️ Tech Stack

Hardware

Microcontroller:** ESP32.
Sensors:** Temperature (DHT), Humidity (DHT), and Gas (MQ series).

Software

Mobile App:** Flutter (Provider for State Management).
Backend:** Python Flask (RESTful API).
Database:** MongoDB Atlas (NoSQL).
Cloud/Messaging:** Firebase (FCM).

 🏗️ System Architecture

1. Data Acquisition:** The ESP32 node collects environmental data and sends it to the Flask backend via POST requests.
2. Processing & Storage:** The backend analyzes the data, calculates energy usage, and stores records in MongoDB.
3. User Interface:** The Flutter app fetches the latest status and allows for manual fan overrides.
4. Notification Loop:** If thresholds are breached, the backend pushes an alert to the mobile device via Firebase.

---

 ⚡ Energy Calculation Logic

The system estimates costs using the following formula:

> Note: The current implementation assumes a 50W fan and an average cost of ₹5 per kWh.

 🔧 Installation & Setup

Backend

1. Navigate to the `/backend` folder.
2. Install dependencies: `pip install flask pymongo firebase-admin certifi`.
3. Add your `firebase-adminsdk.json` to the root.
4. Run: `python app.py`.

Mobile App

1. Navigate to the `/frontend` folder.
2. Install dependencies: `flutter pub get`.
3. Update `_ipAddress` in `lib/main.dart` with your laptop's local IP.
4. Run: `flutter run`.

