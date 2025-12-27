/*
 * Relative Inverse Kinematics for Arduino Nano
 * 5-DOF Robotic Arm Control (Base + Shoulder + Elbow + Wrist + Claw)
 *
 * Commands via Serial (9600 baud):
 *   F10    - Move forward 10cm
 *   B5     - Move backward 5cm
 *   U3     - Move up 3cm
 *   D2     - Move down 2cm
 *   G15,20 - Go to absolute position Y=15, Z=20
 *   H      - Go to home position
 *   P      - Print current position
 *   R90    - Rotate base to 90 degrees
 *   W90    - Rotate wrist to 90 degrees
 *   C90    - Set claw to 90 degrees (open/close)
 *
 * Coordinate System (2D planar, ignoring base rotation):
 *   Y = horizontal distance from base (forward/backward)
 *   Z = height from ground (up/down)
 */

#include <Arduino.h>
#include <Servo.h>
#include <SoftwareSerial.h>

// ============== HARDWARE CONFIGURATION ==============
// Pin mappings (calibrated):
// Pin 3 = Gripper (close: 0-40, open: 90)
// Pin 4 = Wrist (home: 85°)
// Pin 5 = Elbow (offset: -15°)
// Pin 6 = Base (offset: +45°)
// Pin 7 = Shoulder (home: 125°)
#define GRIPPER_PIN 3  // Gripper: tight close=0, calm close=40, max open=90
#define WRIST_PIN 4    // Wrist: home at 85°
#define ELBOW_PIN 5    // Elbow: offset -15° (IK 90° -> servo 75°)
#define SHOULDER_PIN 7 // Shoulder: offset +35° (IK 90° -> servo 125°)
#define BASE_PIN 6     // Base: offset +45°

// ============== SERVO OFFSETS ==============
// Offsets convert IK-calculated angles to physical servo positions
const int SHOULDER_OFFSET = 35; // IK=90° -> Servo=125° (add 35°)
const int ELBOW_OFFSET = -15;   // IK=90° -> Servo=75° (subtract 15°)
const int BASE_OFFSET = 45;     // Add 45° to base commands
const int WRIST_HOME = 85;      // Wrist home position (calibrated)
const int GRIPPER_OPEN = 90;  // Gripper fully open
const int GRIPPER_CALM = 40;  // Gripper calm close
const int GRIPPER_TIGHT = 0;  // Gripper tight close

// ============== ARM DIMENSIONS (in cm) ==============
const float L0 = 7.2;  // Base height (from ground to shoulder pivot)
const float L1 = 7.5;  // Upper arm length (shoulder to elbow)
const float L2 = 17.5; // Forearm length (elbow to end effector)

// ============== SERVO LIMITS ==============
const int SERVO_MIN = 0;
const int SERVO_MAX = 180;

// ============== WORKSPACE LIMITS (in cm) ==============
const float Y_MIN = 5.0;
const float Y_MAX = 40.0;
const float Z_MIN = 5.0;
const float Z_MAX = 30.0;

// ============== GLOBAL STATE ==============
Servo shoulderServo;
Servo elbowServo;
Servo wristServo;
Servo gripperServo;
Servo baseServo;

SoftwareSerial robot(10, 11); // RX, TX

// Current end effector position (in cm)
// Measured at home position: Y=17.5cm (horizontal), Z=15cm (height)
float currentY = 17.5; // Initial horizontal distance (measured)
float currentZ = 15.0; // Initial height from ground (measured)

// Current joint angles (in degrees) - these are LOGICAL/IK angles before offsets
// HOME: IK angles 90°,90° -> Servo writes 125°,75° (with offsets +35,-15)
float shoulderAngle = 90;  // IK angle (servo writes 90+35=125°)
float elbowAngle = 90;     // IK angle (servo writes 90-15=75°)
float baseAngle = 90;      // Home at 90° (servo writes 90+45=135°)
float wristAngle = 85;     // Wrist home is 85°
float gripperAngle = 40;   // Start with calm close (40°)

// Movement speed (delay between steps in ms)
int moveDelay = 20;
int moveSteps = 30;

// ============== FUNCTION DECLARATIONS ==============
bool calculateIK(float y, float z, float &shoulder, float &elbow);
void moveRelative(float deltaY, float deltaZ);
void moveToPosition(float targetY, float targetZ);
void goToHome();
void printPosition();
void setBase(float angle);
void setWrist(float angle);
void setGripper(float angle);
void openGripper();
void closeGripper(bool tight = false);
void processSerialCommand(String input);
void processBluetoothCommand(String input);

// ============== SETUP ==============
void setup()
{
    Serial.begin(9600);
    robot.begin(9600);

    // Attach servos
    shoulderServo.attach(SHOULDER_PIN);
    elbowServo.attach(ELBOW_PIN);
    wristServo.attach(WRIST_PIN);
    gripperServo.attach(GRIPPER_PIN);
    baseServo.attach(BASE_PIN);

    // Move to home position
    goToHome();

    Serial.println(F("=== Relative IK Controller ==="));
    Serial.println(F("Serial Commands (single letter):"));
    Serial.println(F("  F<cm> B<cm> U<cm> D<cm> - Move"));
    Serial.println(F("  G<y>,<z> - Position | R<deg> - Base"));
    Serial.println(F("  W<deg> - Wrist | C<deg> - Gripper"));
    Serial.println(F("  O/X/T - Open/Close/Tight | H/P - Home/Print"));
    Serial.println(F(""));
    Serial.println(F("Bluetooth Commands (colon format):"));
    Serial.println(F("  move:forward|backward|up|down:<cm>"));
    Serial.println(F("  position:<y>,<z> | base:<deg> | wrist:<deg>"));
    Serial.println(F("  gripper:open|close|tight|<deg>"));
    Serial.println(F("  home | status"));
    Serial.println();
    printPosition();
}

// ============== MAIN LOOP ==============
void loop()
{
    // Handle Serial commands (single letter format)
    if (Serial.available())
    {
        String input = Serial.readStringUntil('\n');
        input.trim();

        if (input.length() == 0)
            return;

        // Check if it's a Bluetooth-style command (contains colon)
        if (input.indexOf(':') >= 0 || input.equalsIgnoreCase("home") || input.equalsIgnoreCase("status"))
        {
            processBluetoothCommand(input);
        }
        else
        {
            processSerialCommand(input);
        }
    }

    // Handle Bluetooth commands (colon format)
    if (robot.available())
    {
        String input = robot.readStringUntil('\n');
        input.trim();

        if (input.length() > 0)
        {
            Serial.print(F("BT Received: "));
            Serial.println(input);
            processBluetoothCommand(input);
        }
    }
}

// ============== SERIAL COMMAND PROCESSOR (Single Letter) ==============
void processSerialCommand(String input)
{
    input.toUpperCase();

    char cmd = input.charAt(0);
    float value = 0;

    if (input.length() > 1)
    {
        value = input.substring(1).toFloat();
    }

    switch (cmd)
    {
    case 'F': // Forward
        moveRelative(value, 0);
        break;

    case 'B': // Backward
        moveRelative(-value, 0);
        break;

    case 'U': // Up
        moveRelative(0, value);
        break;

    case 'D': // Down
        moveRelative(0, -value);
        break;

    case 'G': // Go to absolute position
    {
        int commaIdx = input.indexOf(',');
        if (commaIdx > 0)
        {
            float y = input.substring(1, commaIdx).toFloat();
            float z = input.substring(commaIdx + 1).toFloat();
            moveToPosition(y, z);
        }
        else
        {
            Serial.println(F("Error: Use format G<y>,<z>"));
        }
    }
    break;

    case 'H': // Home
        goToHome();
        break;

    case 'P': // Print position
        printPosition();
        break;

    case 'R': // Rotate base
        setBase(value);
        break;

    case 'W': // Wrist angle
        setWrist(value);
        break;

    case 'C': // Gripper angle
        setGripper(value);
        break;

    case 'O': // Open gripper
        openGripper();
        break;

    case 'X': // Close gripper (calm)
        closeGripper(false);
        break;

    case 'T': // Close gripper (tight)
        closeGripper(true);
        break;

    default:
        Serial.println(F("Unknown command"));
        break;
    }
}

// ============== BLUETOOTH COMMAND PROCESSOR (Colon Format) ==============
// Handles commands like: move:forward:10, gripper:open, position:15,20, home, status
void processBluetoothCommand(String input)
{
    input.toLowerCase();

    Serial.print(F("Processing: "));
    Serial.println(input);

    // Handle simple commands without colons
    if (input == "home")
    {
        goToHome();
        robot.println(F("OK:home"));
        return;
    }
    if (input == "status")
    {
        printPosition();
        robot.println(F("OK:status"));
        return;
    }

    // Parse colon-separated command
    int firstColon = input.indexOf(':');
    if (firstColon < 0)
    {
        Serial.println(F("Error: Invalid command format"));
        robot.println(F("ERROR:INVALID_FORMAT"));
        return;
    }

    String command = input.substring(0, firstColon);
    String remainder = input.substring(firstColon + 1);

    // Handle MOVE commands: move:forward:10, move:up:5, etc.
    if (command == "move")
    {
        int secondColon = remainder.indexOf(':');
        String direction = (secondColon >= 0) ? remainder.substring(0, secondColon) : remainder;
        float value = (secondColon >= 0) ? remainder.substring(secondColon + 1).toFloat() : 5.0; // Default 5cm

        if (direction == "forward")
        {
            moveRelative(value, 0);
            robot.println(F("OK:move:forward"));
        }
        else if (direction == "backward")
        {
            moveRelative(-value, 0);
            robot.println(F("OK:move:backward"));
        }
        else if (direction == "up")
        {
            moveRelative(0, value);
            robot.println(F("OK:move:up"));
        }
        else if (direction == "down")
        {
            moveRelative(0, -value);
            robot.println(F("OK:move:down"));
        }
        else
        {
            Serial.println(F("Error: Unknown direction"));
            robot.println(F("ERROR:UNKNOWN_DIRECTION"));
        }
        return;
    }

    // Handle POSITION command: position:15,20
    if (command == "position")
    {
        int commaIdx = remainder.indexOf(',');
        if (commaIdx > 0)
        {
            float y = remainder.substring(0, commaIdx).toFloat();
            float z = remainder.substring(commaIdx + 1).toFloat();
            moveToPosition(y, z);
            robot.println(F("OK:position"));
        }
        else
        {
            Serial.println(F("Error: Use format position:y,z"));
            robot.println(F("ERROR:INVALID_POSITION"));
        }
        return;
    }

    // Handle BASE command: base:90
    if (command == "base")
    {
        float angle = remainder.toFloat();
        setBase(angle);
        robot.println(F("OK:base"));
        return;
    }

    // Handle WRIST command: wrist:90
    if (command == "wrist")
    {
        float angle = remainder.toFloat();
        setWrist(angle);
        robot.println(F("OK:wrist"));
        return;
    }

    // Handle GRIPPER commands: gripper:open, gripper:close, gripper:tight, gripper:45
    if (command == "gripper")
    {
        if (remainder == "open")
        {
            openGripper();
            robot.println(F("OK:gripper:open"));
        }
        else if (remainder == "close")
        {
            closeGripper(false);
            robot.println(F("OK:gripper:close"));
        }
        else if (remainder == "tight")
        {
            closeGripper(true);
            robot.println(F("OK:gripper:tight"));
        }
        else
        {
            // Assume it's an angle
            float angle = remainder.toFloat();
            setGripper(angle);
            robot.println(F("OK:gripper"));
        }
        return;
    }

    Serial.println(F("Error: Unknown command"));
    robot.println(F("ERROR:UNKNOWN_COMMAND"));
}

// ============== INVERSE KINEMATICS ==============
// Calculates shoulder and elbow angles for given Y,Z position
// Returns true if position is reachable, false otherwise
bool calculateIK(float y, float z, float &shoulder, float &elbow)
{
    // Adjust Z relative to shoulder height
    float zAdj = z - L0;

    // Distance from shoulder to target point
    float dist = sqrt(y * y + zAdj * zAdj);

    // Check if position is reachable
    float maxReach = L1 + L2 - 0.5;      // Slightly less than full extension
    float minReach = abs(L1 - L2) + 0.5; // Slightly more than minimum

    if (dist > maxReach || dist < minReach)
    {
        Serial.print(F("Error: Position out of reach. Distance: "));
        Serial.print(dist);
        Serial.print(F(" cm. Valid range: "));
        Serial.print(minReach);
        Serial.print(F(" - "));
        Serial.print(maxReach);
        Serial.println(F(" cm"));
        return false;
    }

    // Law of cosines to find elbow angle
    // c² = a² + b² - 2ab*cos(C)
    // cos(elbow) = (L1² + L2² - dist²) / (2 * L1 * L2)
    float cosElbow = (L1 * L1 + L2 * L2 - dist * dist) / (2.0 * L1 * L2);

    // Clamp to valid range to handle floating point errors
    cosElbow = constrain(cosElbow, -1.0, 1.0);

    // Elbow angle (interior angle)
    float elbowRad = acos(cosElbow);
    elbow = 180.0 - (elbowRad * 180.0 / PI); // Convert to servo angle

    // Angle from horizontal to target point
    float angleToTarget = atan2(zAdj, y);

    // Angle from upper arm to target point (using law of cosines)
    float cosBeta = (L1 * L1 + dist * dist - L2 * L2) / (2.0 * L1 * dist);
    cosBeta = constrain(cosBeta, -1.0, 1.0);
    float beta = acos(cosBeta);

    // Shoulder angle
    float shoulderRad = angleToTarget + beta;
    shoulder = shoulderRad * 180.0 / PI;

    // Ensure angles are within servo limits
    if (shoulder < SERVO_MIN || shoulder > SERVO_MAX ||
        elbow < SERVO_MIN || elbow > SERVO_MAX)
    {
        Serial.println(F("Error: Calculated angles exceed servo limits"));
        return false;
    }

    return true;
}

// ============== MOVEMENT FUNCTIONS ==============

// Move relative to current position
void moveRelative(float deltaY, float deltaZ)
{
    float newY = currentY + deltaY;
    float newZ = currentZ + deltaZ;

    Serial.print(F("Moving: "));
    if (deltaY != 0)
    {
        Serial.print(deltaY > 0 ? F("Forward ") : F("Backward "));
        Serial.print(abs(deltaY));
        Serial.print(F("cm "));
    }
    if (deltaZ != 0)
    {
        Serial.print(deltaZ > 0 ? F("Up ") : F("Down "));
        Serial.print(abs(deltaZ));
        Serial.print(F("cm"));
    }
    Serial.println();

    moveToPosition(newY, newZ);
}

// Move to absolute position with smooth interpolation
void moveToPosition(float targetY, float targetZ)
{
    // Clamp to workspace limits
    targetY = constrain(targetY, Y_MIN, Y_MAX);
    targetZ = constrain(targetZ, Z_MIN, Z_MAX);

    // Calculate target angles
    float targetShoulder, targetElbow;
    if (!calculateIK(targetY, targetZ, targetShoulder, targetElbow))
    {
        Serial.println(F("Movement cancelled - position unreachable"));
        return;
    }

    Serial.print(F("Target: Y="));
    Serial.print(targetY);
    Serial.print(F("cm, Z="));
    Serial.print(targetZ);
    Serial.println(F("cm"));

    Serial.print(F("Angles: Shoulder="));
    Serial.print(targetShoulder, 1);
    Serial.print(F("°, Elbow="));
    Serial.print(targetElbow, 1);
    Serial.println(F("°"));

    // Smooth movement - interpolate between current and target angles
    float startShoulder = shoulderAngle;
    float startElbow = elbowAngle;

    for (int i = 1; i <= moveSteps; i++)
    {
        float t = (float)i / moveSteps;

        // Linear interpolation
        float newShoulder = startShoulder + (targetShoulder - startShoulder) * t;
        float newElbow = startElbow + (targetElbow - startElbow) * t;

        // Write to servos (apply offsets to convert IK angles to servo positions)
        shoulderServo.write((int)(newShoulder + SHOULDER_OFFSET)); // IK -> servo
        elbowServo.write((int)(newElbow + ELBOW_OFFSET));          // IK -> servo

        delay(moveDelay);
    }

    // Update current state
    shoulderAngle = targetShoulder;
    elbowAngle = targetElbow;
    currentY = targetY;
    currentZ = targetZ;

    Serial.println(F("Movement complete"));
    printPosition();
}

// Move to home position
void goToHome()
{
    Serial.println(F("Moving to home position..."));

    // Set auxiliary servos to home first
    setBase(90);              // Base centered (servo writes 135°)
    setWrist(WRIST_HOME);     // Wrist at 85°
    setGripper(GRIPPER_CALM); // Gripper calm close (40°)

    // Home positions (IK logical angles)
    const float SHOULDER_HOME = 90.0;  // IK angle (servo: 90+35=125°)
    const float ELBOW_HOME = 90.0;     // IK angle (servo: 90-15=75°)

    Serial.println(F("IK: Shoulder=90°, Elbow=90° -> Servo: 125°, 75°"));

    // Smooth movement to home
    float startShoulder = shoulderAngle;
    float startElbow = elbowAngle;

    for (int i = 1; i <= moveSteps; i++)
    {
        float t = (float)i / moveSteps;

        float newShoulder = startShoulder + (SHOULDER_HOME - startShoulder) * t;
        float newElbow = startElbow + (ELBOW_HOME - startElbow) * t;

        // Apply offsets to convert IK angles to servo positions
        shoulderServo.write((int)(newShoulder + SHOULDER_OFFSET));
        elbowServo.write((int)(newElbow + ELBOW_OFFSET));

        delay(moveDelay);
    }

    // Update state (IK angles)
    shoulderAngle = SHOULDER_HOME;
    elbowAngle = ELBOW_HOME;
    // Measured position at home angles
    currentY = 17.5;
    currentZ = 15.0;

    Serial.println(F("Home position reached"));
    printPosition();
}

// Print current position and angles
void printPosition()
{
    Serial.println(F("--- Current State ---"));
    Serial.print(F("Position: Y="));
    Serial.print(currentY, 1);
    Serial.print(F("cm, Z="));
    Serial.print(currentZ, 1);
    Serial.println(F("cm"));
    Serial.print(F("IK Angles: Shoulder="));
    Serial.print(shoulderAngle, 1);
    Serial.print(F("° (+"));
    Serial.print(SHOULDER_OFFSET);
    Serial.print(F("°), Elbow="));
    Serial.print(elbowAngle, 1);
    Serial.print(F("° ("));
    Serial.print(ELBOW_OFFSET);
    Serial.println(F("°)"));
    Serial.print(F("Base="));
    Serial.print(baseAngle, 1);
    Serial.print(F("° (+"));
    Serial.print(BASE_OFFSET);
    Serial.print(F("° offset), Wrist="));
    Serial.print(wristAngle, 1);
    Serial.print(F("°, Gripper="));
    Serial.print(gripperAngle, 1);
    Serial.println(F("°"));
    Serial.println(F("---------------------"));
}

// ============== ADDITIONAL SERVO CONTROLS ==============

// Set base rotation angle (applies offset automatically)
void setBase(float angle)
{
    angle = constrain(angle, SERVO_MIN, SERVO_MAX - BASE_OFFSET); // Account for offset
    Serial.print(F("Base rotating to: "));
    Serial.print(angle, 1);
    Serial.print(F("° (servo: "));
    Serial.print(angle + BASE_OFFSET, 1);
    Serial.println(F("°)"));

    // Smooth movement
    float startAngle = baseAngle;
    for (int i = 1; i <= moveSteps; i++)
    {
        float t = (float)i / moveSteps;
        float newAngle = startAngle + (angle - startAngle) * t;
        baseServo.write((int)(newAngle + BASE_OFFSET)); // Apply offset
        delay(moveDelay);
    }

    baseAngle = angle;
}

// Set wrist rotation angle
void setWrist(float angle)
{
    angle = constrain(angle, SERVO_MIN, SERVO_MAX);
    Serial.print(F("Wrist rotating to: "));
    Serial.print(angle, 1);
    Serial.println(F("°"));

    // Smooth movement
    float startAngle = wristAngle;
    for (int i = 1; i <= moveSteps; i++)
    {
        float t = (float)i / moveSteps;
        float newAngle = startAngle + (angle - startAngle) * t;
        wristServo.write((int)newAngle);
        delay(moveDelay);
    }

    wristAngle = angle;
}

// Set gripper angle (0=tight close, 40=calm close, 90=open)
void setGripper(float angle)
{
    angle = constrain(angle, GRIPPER_TIGHT, GRIPPER_OPEN); // 0-90 range
    Serial.print(F("Gripper set to: "));
    Serial.print(angle, 1);
    Serial.println(F("°"));

    // Smooth movement
    float startAngle = gripperAngle;
    for (int i = 1; i <= moveSteps; i++)
    {
        float t = (float)i / moveSteps;
        float newAngle = startAngle + (angle - startAngle) * t;
        gripperServo.write((int)newAngle);
        delay(moveDelay);
    }

    gripperAngle = angle;
}

// Open gripper fully
void openGripper()
{
    Serial.println(F("Opening gripper..."));
    setGripper(GRIPPER_OPEN);
}

// Close gripper
void closeGripper(bool tight)
{
    if (tight)
    {
        Serial.println(F("Closing gripper (tight)..."));
        setGripper(GRIPPER_TIGHT);
    }
    else
    {
        Serial.println(F("Closing gripper (calm)..."));
        setGripper(GRIPPER_CALM);
    }
}
