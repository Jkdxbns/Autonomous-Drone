# 🚁  Voice Controller Autonomous Micro-Delivery Quadcopter

### *A 5-month journey to build a fully autonomous drone that listens, thinks, and delivers.*

---

## 🎯 Project Vision

The **Drone Project** is a five-month Learning project and a R&D challenge to build a
**voice-activated micro-delivery drone** capable of:

* Responding to voice commands from a custom Android app
* Navigating both **indoors and outdoors** using SLAM, GPS, and sensor fusion
* Picking and delivering small objects with a **3D-printed robotic arm**
* Executing automatic safety behaviors like emergency landing, watchdog recovery, link-loss actions and return-to-home

This project aims to merge **embedded systems, edge AI, perception and human-robot interaction**
into one unified, real-world demonstration.

---

## 🧠 System Overview

| Layer                            | Description                                                                                                                  |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| **Android App**                  | Interface for commands and speech-to-text. Sends missions to server over HTTPS via WireGuard VPN.                            |
| **Server (BeagleBone / Laptop)** | Acts as a relay hub handling authentication and command routing to Jetson.                                                   |
| **Jetson Orin Nano**             | Runs ROS 2 Humble, SLAM, object detection and mission control. Converts incoming JSON commands to real-time tasks.           |
| **STM32 Nucleo (FreeRTOS)**      | Handles all low-level control: motor PWM, IMU fusion, watchdog timer, and emergency-landing state machine.                   |
| **Custom Safety WDC**            | Windowed watchdog + PWM multiplexer                                                                                          |
| **3D-Printed Arm**               | 4× 15 kg·cm servos, 2 links, 3 DOF + 4-finger claw, payload ≈ 1 lb.                                                          |
| **Networking**                   | LTE/Wi-Fi with WireGuard overlay for secure telemetry with RF as a redundant connectivity oiption                            |
| **Sensors**                      | IMU (MPU6050/BMI088), Barometer (BMPxxx), Optical Flow (PMW3901/MTS-01P), TFmini/TFLune LiDAR (top & bottom), GPS            |
-------------------------------------------------------------------------------------------------------------------------------------------------------------------

---

## ⚙️ Hardware Architecture

```
Android  →  Server (WireGuard)  →  Jetson Orin Nano  →  STM32 (UART) + Safety PCB (Watchdog / MUX)
                                    |                       │
                                    └── 2x IMX477 cameras   ├── Sensors (IMU, LiDAR, Flow, Baro, GPS)
                                                            └── Robotic Arm (PWM control)
```

Power System:

* 2 × Li-Po 3S 8000 mAh packs
* 1 x Li-Po 3S 2200 mAh pack
* 4 x A2212-2200 KV motors + 30 A SimonK ESCs
* 10″ propellers with prop-guards for safety

---

## 🧩 Core Features

**🎧 Voice Command & Intent Recognition** — wake-word → speech-to-text → intent → mission execution
**🧟‍♂️ GPS Delivery** — ensures delivery to specified cordinate
**🦭 Indoor → Outdoor Autonomy** — VIO + SLAM + GPS fusion + obstacle avoidance
**📦 Pick-and-Place Manipulation** — 3-DOF arm (RPR configuration) for object pickup and drop-off
**🪂 Watchdog Safety Layer** — Jetson or STM32 failure Arduino UNO takeover within < 1s
**📡 Secure Networking** — HTTPS / MQTT over WireGuard for all telemetry and commands

---

## 🗓️ 5-Month Development Roadmap

### **Month 1 — Phase I : Proof of Concept**

> Working prototype of the drone, arm, and Android app.

* Establish Jetson↔STM32 UART communication
* Implement basic flight & arm movements (hover, rotate and land for drone | set-2-positions for arm)
* Android app → server → ~~Jetson → STM~~ Bluetooth | communication chain over HTTP + WireGuard
* Validate IMU / ~~LiDAR / Optical Flow~~ sensor readings

---

### **Month 2 — Phase II : Secure Voice AI Integration**

> Add voice control, AI perception, and ROS 2 integration.

* On-device wake-word + 2FA confirmation
* Multi-device server connections (phone / laptop / Jetson)
* VIO SLAM + object detection pipelines
* STM32 + Arduino UNO watchdog co-testing
* ROS 2 Humble stack setup for telemetry and visualization

---

### **Month 3 — Phase III : Object Pick & Outdoor Navigation**

> Extend autonomy and begin real pick-and-place trials.

* Indoor → outdoor navigation with GPS + magnetometer + SLAM
* Target detection → grasp → deliver
* Google Maps API for path planning & auto-rerouting
* Drift correction via Nano controller
* Speed range validation 30 cm/s → 5 m/s

---

### **Month 4 — Phase IV : Full Autonomy & Dataset Build**

> Achieve reliable end-to-end autonomy.

* Complete indoor ↔ outdoor transition
* Object delivery + return-to-home sequence
* Dataset collection for model training
* Watchdog and safety system stress tests

---

### **Month 5 — Phase V : “Coffin” → Final Build and Launch**

> Replace all models with custom, locally-trained networks.

* Self-trained models for STT, Intent, Object Recognition
* Auto rerouting with GMap API integration
* Fully functional delivery demo with local models
* YouTube / Instagram launch and documentation release

---

## 🧮 Current Targets & Metrics
### Will be updated as per progress

|          Category        |             Target              |           Status               |
| ------------------------ | ------------------------------- | ------------------------------ |
| ----------------------------------- [MONTH - 1] ------------------------------------------- |
|    Flutter App           | - connect with HM-10            |           SUCCESS              |
|                          | - convert audio commadands to exeecutable commands   |           |
|    Flask Server          | - run STT (whisper) locally     |           SUCCESS              |
|                          | - use LM (api) to obtain text categorization and executable  |   |
|                          |   command                       |                                |
|     Robotic Arm          | - Control arm to given end point using IK equations|  Not Started|
|                          | - Identify stated object and locate   |                          | 
|     Drone                | - Get drone to hover stabolly   |          Not Started           |
|                          | - Perform basic movements       |                                |
|     Vision & AI          | - Get Object detection working on Jetson locally | Not Started   |
|                          | - Implement depth estimation using stereo-camera setup   |       |
|                          |                                 |                                |
---

## 🔒 Safety Architecture

* **Dual-MCU Control:** Jetson (AI brain) + STM32 (real-time failsafe)
* **Windowed Watchdog:** detects Jetson hang → PWM MUX → ramp-down PWM to ESCs
* **Supervisor FSM:** Healthy → Request_Land → Takeover → Power_Cut → Emergency
* **E-Stop:** physical button + software interrupt with ≤ 2s response
* **Battery & Power Protection:** current sensors + ...
* **Safety SOPs:** pre-flight checklist, geofence limits, post-flight logs
* **POST:** Power-On-Self-Test + resource/feasibility check

---

## 🛠️ Software Stack

* **Languages:** C (bare-metal STM32), Python (ROS nodes), C++ (rclcpp), Java (Android) + ...
* **Frameworks:** ROS 2 Humble, TensorRT, OpenCV, PyTorch (Light)
* **Simulation:** AirSim + Gazebo or RViz
* **Networking:** WireGuard VPN, HTTPS/MQTT, RF
* **CI & Reproducibility:** Docker Devcontainers (Optional), GitHub 

---

## 🎥 Follow the Build Journey

📸 Instagram → [@jm3innovations](https://www.instagram.com/jm3innovations)
🎥 YouTube → [JM3 Innovations](https://www.youtube.com/@jm3innovations)
🐙 GitHub → [This Repository](https://github.com/Jkdxbns/Autonomous-Drone)

> *Daily-Weekly posts from Oct 2025 to Mar 2026 documenting each milestone, hardware build, and flight demo.*

---

### ✨ Keywords

`ROS2`  `Jetson Orin Nano`  `STM32`  `Autonomous Drone`  `Computer Vision`  `Voice AI`  `Safety Engineering` `Drone with Arm`
