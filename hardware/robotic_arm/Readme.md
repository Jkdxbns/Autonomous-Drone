# 5-DOF Robotic Arm with Inverse Kinematics

A programmable 3 degree-of-freedom robotic arm featuring inverse kinematics control, dual command interfaces (Serial & Bluetooth), and smooth servo interpolation for precise positioning.

> 📺 **Demo Video**: *Coming soon on [YouTube](#) and [Instagram](#)*

---

## 🤖 Overview

This project implements advanced control for a 3-DOF robotic arm using Arduino Nano, featuring:
- **Inverse Kinematics** - Calculate joint angles from desired end-effector positions
- **Dual Control Interfaces** - Serial terminal commands and Bluetooth wireless control
- **Smooth Motion** - Interpolated servo movements for fluid motion
- **2D Planar Workspace** - Y-Z coordinate system with base rotation
- **Real-time Position Tracking** - Current position and joint angle monitoring

### Hardware Specifications

**Arm Configuration:**
- 5 Degrees of Freedom (Base, Shoulder, Elbow, Wrist, Gripper)
- Total reach: ~10-25cm horizontal range
- Vertical workspace: ~ 5-30cm height
- Servo-powered joints with calibrated offsets

**Dimensions:**
- Base Height (L0): 7.2 cm
- Upper Arm (L1): 7.5 cm  
- Forearm (L2): 17.5 cm

---

## 🛒 Hardware

### Robotic Arm Kit

**Product**: ACEBOTT 6 DOF Robot Arm Kit  
**Purchase Link**: https://www.amazon.com/ACEBOTT-Functions-Coding-Expansion-Without/dp/B0DHS8K42H

> ⚠️ **Disclaimer**: This is NOT a sponsored or affiliate link. This is the actual product I purchased and used for this project.

### Required Components

- Arduino Nano (or compatible)
- 5x Servo Motors (included with kit)
- HC-05/HC-06 Bluetooth Module for wireless control
- Power Supply (5V, 2A recommended)
- USB Cable for programming

### Pin Configuration

```cpp
Pin 3  → Gripper Servo
Pin 4  → Wrist Servo
Pin 5  → Elbow Servo
Pin 6  → Base Servo
Pin 7  → Shoulder Servo
Pin 10 → Bluetooth RX (optional)
Pin 11 → Bluetooth TX (optional)
```

---

## 🚀 Getting Started

### 1. Software Setup

#### Install PlatformIO
```bash
# Using pip
pip install platformio

# Or install VS Code extension
# Search "PlatformIO IDE" in VS Code extensions
```

#### Build & Upload
```bash
# Clone repository
cd hardware/robotic_arm

# Build firmware
pio run

# Upload to Arduino
pio run --target upload

# Open serial monitor
pio device monitor
```

### 2. Hardware Assembly

1. **Assemble the arm** following the manufacturer's instructions
2. **Power supply**: Connect external 5V power to servo power rails
3. **Bluetooth**: Connect HC-05 module to pins 10 (RX) and 11 (TX)

### 3. Calibration

The code includes pre-calibrated servo offsets, but you may need to adjust:

```cpp
// In main.cpp, modify these constants if needed:
const int SHOULDER_OFFSET = 35;  // Adjust if shoulder home is off
const int ELBOW_OFFSET = -15;    // Adjust if elbow home is off
const int BASE_OFFSET = 45;      // Adjust if base center is off
const int WRIST_HOME = 85;       // Wrist home position
```

**Calibration Procedure:**
1. Send `H` command to move to home position
2. Visually inspect if arm is at 90° angles
3. Adjust offsets and re-upload if needed

---

## 📡 Control Commands

### Serial Commands (Single Letter Format)

Connect via USB at **9600 baud** and send these commands:

#### Movement Commands
```
F10    → Move forward 10cm
B5     → Move backward 5cm
U3     → Move up 3cm
D2     → Move down 2cm
G15,20 → Go to absolute position Y=15cm, Z=20cm
```

#### Joint Control
```
R90    → Rotate base to 90 degrees
W85    → Set wrist to 85 degrees
C45    → Set gripper to 45 degrees
```

#### Gripper Control
```
O      → Open gripper fully (90°)
X      → Close gripper gently (40°)
T      → Close gripper tightly (0°)
```

#### System Commands
```
H      → Return to home position
P      → Print current position and angles
```

### Bluetooth Commands (Colon Format)

Send commands wirelessly via Bluetooth module:

#### Movement
```
move:forward:10     → Move forward 10cm
move:backward:5     → Move backward 5cm
move:up:3           → Move up 3cm
move:down:2         → Move down 2cm
position:15,20      → Go to Y=15cm, Z=20cm
```

#### Joints
```
base:90             → Rotate base to 90°
wrist:85            → Set wrist to 85°
```

#### Gripper
```
gripper:open        → Open gripper
gripper:close       → Close gripper gently
gripper:tight       → Close gripper tightly
gripper:45          → Set gripper to 45°
```

#### System
```
home                → Return to home position
status              → Print current state
```

---

## 🎮 Usage Examples

### Example 1: Pick and Place Sequence
```cpp
// Via Serial Monitor
H           // Start at home
G10,15      // Move to object
X           // Close gripper (grab)
U5          // Lift up 5cm
R135        // Rotate base to 135°
D5          // Lower down 5cm
O           // Open gripper (release)
H           // Return home
```

### Example 2: Bluetooth Control
```cpp
// Via Bluetooth terminal app
home                  // Start at home
move:forward:10       // Approach object
gripper:close         // Grab object
move:up:5            // Lift
base:45              // Rotate
move:down:5          // Lower
gripper:open         // Release
home                 // Return
```

### Example 3: Workspace Exploration
```cpp
// Trace rectangular path
G10,10      // Bottom-left
G10,25      // Top-left
G20,25      // Top-right
G20,10      // Bottom-right
G15,15      // Center
H           // Home
```

---

## 🧮 Inverse Kinematics Algorithm

The controller uses **2D planar inverse kinematics** with the following approach:

### Mathematical Model

Given target position `(Y, Z)`:

1. **Calculate distance** from shoulder to target:
   ```
   dist = √(Y² + (Z-L0)²)
   ```

2. **Compute elbow angle** using law of cosines:
   ```
   cos(θ_elbow) = (L1² + L2² - dist²) / (2·L1·L2)
   θ_elbow = 180° - arccos(cos(θ_elbow))
   ```

3. **Compute shoulder angle**:
   ```
   α = atan2(Z-L0, Y)  // Angle to target
   β = arccos((L1² + dist² - L2²) / (2·L1·dist))
   θ_shoulder = α + β
   ```

### Workspace Limits
```cpp
Y range: 5cm - 40cm (horizontal)
Z range: 5cm - 30cm (vertical)
Reach: ~5cm (minimum) to ~25cm (maximum)
```

### Servo Offset System

The code separates **IK logical angles** from **physical servo positions**:

```cpp
// Example: Home position
IK Angles:    Shoulder = 90°,  Elbow = 90°
Servo Writes: Shoulder = 125°, Elbow = 75°
Offsets:      +35°,            -15°
```

This abstraction allows clean IK calculations while accounting for mechanical alignment.

---

## 📚 Code Structure

```
src/main.cpp
├── Hardware Configuration     // Pin definitions, servo offsets
├── Global State              // Current position and angles
├── Inverse Kinematics        // calculateIK() function
├── Movement Functions        // moveRelative(), moveToPosition()
├── Command Processors        // Serial & Bluetooth parsers
└── Auxiliary Controls        // Base, wrist, gripper functions
```

### Key Functions

- `calculateIK(y, z, &shoulder, &elbow)` - Compute joint angles for position
- `moveToPosition(y, z)` - Move to absolute coordinate with smooth interpolation
- `moveRelative(deltaY, deltaZ)` - Relative movement from current position
- `goToHome()` - Return to calibrated home position
- `processSerialCommand()` - Parse single-letter commands
- `processBluetoothCommand()` - Parse colon-format commands

---

## 🎓 Project Background

This robotic arm controller was developed as part of the **EEEE685 course project**, focusing on:
- Embedded systems programming
- Kinematic modeling and control
- Real-time servo control algorithms
- Dual-interface communication protocols

The project demonstrates practical applications of:
- Inverse kinematics for robotics
- Arduino embedded programming
- Bluetooth wireless communication
- Real-time motion control

---

## 📄 Documentation

- **Presentation**: [Robotic_Arm_Presentation.pptx](docs/Robotic_Arm_Presentation.pptx)
- **Source Code**: [src/main.cpp](src/main.cpp)
- **Configuration**: [platformio.ini](platformio.ini)

---

## 🚀 Future Enhancements

Potential improvements:
- [ ] 3D kinematics (full 3D workspace utilization)
- [ ] Trajectory planning (smooth curves, not just straight lines)
- [ ] Obstacle avoidance
- [ ] Vision system integration
- [ ] Machine learning for pick-and-place optimization

---

## 📧 Contact

For questions or collaboration:
- **GitHub**: [Your GitHub Profile]
- **Project Repository**: https://github.com/Jkdxbns/Voice-Controlled-Delivery-Drone

---

**Made with ❤️ for robotics and embedded systems**
