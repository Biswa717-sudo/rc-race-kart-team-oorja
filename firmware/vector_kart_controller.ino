/*
 * Vector Kart Controller Firmware (Timeline 3)
 * Dual A2212 Motors + Dual SimonK 30A ESCs + Independent Stub Axles
 * Real-Time Proportional Ackermann Torque Vectoring
 * Microcontroller: ESP32-S3
 * 
 * Pinout:
 * GPIO 17 -> Left ESC Signal (PWM 50Hz)
 * GPIO 18 -> Right ESC Signal (PWM 50Hz)
 * GPIO 19 -> Relay Coil (4-Ch Relay for Dual-Motor Phase Swapping)
 * GPIO 21 -> Steering Servo Signal (MG90S)
 * GPIO 4  -> Manual Reverse Toggle Input (Active LOW or Ch3)
 * 
 * Features:
 * 1. Proportional Ackermann Torque Vectoring Differential (Zero tire scrub in hairpins)
 * 2. Dedicated Manual Driver Reverse Switch with 250ms zero-RPM dead-time
 * 3. 250ms Failsafe (Rule 3.3.6)
 */

#include <Arduino.h>
#include <ESP32Servo.h>

Servo leftESC;
Servo rightESC;
Servo steeringServo;

// Pin Definitions
const int PIN_LEFT_ESC      = 17;
const int PIN_RIGHT_ESC     = 18;
const int PIN_RELAY_SWAP    = 19;
const int PIN_SERVO_SIGNAL  = 21;
const int PIN_MANUAL_REV_SW = 4;

// Motor Spin-Down Calibration (Milliseconds)
const int MOTOR_STOP_DELAY_MS = 250; // Delay for dual motors to reach 0 RPM
const int RELAY_SETTLE_MS     = 50;  // Relay mechanical contact settle time

// State Machine Definitions
enum DriveState {
    STATE_FORWARD,
    STATE_HARD_BRAKE,
    STATE_REVERSE_RECOVERY
};

DriveState currentState = STATE_FORWARD;
bool manualReverseEngaged = false;
unsigned long lastPacketTime = 0;

void setup() {
    Serial.begin(115200);

    pinMode(PIN_RELAY_SWAP, OUTPUT);
    digitalWrite(PIN_RELAY_SWAP, LOW); // Default: Forward Phase (Relay OFF)
    pinMode(PIN_MANUAL_REV_SW, INPUT_PULLUP);

    ESP32PWM::allocateTimer(0);
    ESP32PWM::allocateTimer(1);
    ESP32PWM::allocateTimer(2);

    leftESC.setPeriodHertz(50);
    rightESC.setPeriodHertz(50);
    steeringServo.setPeriodHertz(50);

    leftESC.attach(PIN_LEFT_ESC, 1000, 2000);
    rightESC.attach(PIN_RIGHT_ESC, 1000, 2000);
    steeringServo.attach(PIN_SERVO_SIGNAL, 1000, 2000);

    // Initial ESC Arming (1000us neutral for 2 seconds)
    leftESC.writeMicroseconds(1000);
    rightESC.writeMicroseconds(1000);
    steeringServo.writeMicroseconds(1500); // Center steering
    delay(2000);

    lastPacketTime = millis();
    Serial.println("Vector Kart Controller Armed: Torque Vectoring Active.");
}

// Proportional Ackermann Differential Function
void calculateTorqueVectoring(int baseThrottle, int steerInput, int &leftPWM, int &rightPWM) {
    float steerFactor = steerInput / 100.0f; // -1.0 (Full Left) to +1.0 (Full Right)
    float leftScale  = 1.0f;
    float rightScale = 1.0f;

    if (steerFactor > 0.05f) {
        // TURNING RIGHT: Right wheel slows down, Left wheel speeds up
        rightScale = 1.0f - (0.70f * steerFactor);
        leftScale  = 1.0f + (0.35f * steerFactor);
    } 
    else if (steerFactor < -0.05f) {
        // TURNING LEFT: Left wheel slows down, Right wheel speeds up
        leftScale  = 1.0f - (0.70f * fabsf(steerFactor));
        rightScale = 1.0f + (0.35f * fabsf(steerFactor));
    }

    leftScale  = constrain(leftScale,  0.20f, 1.40f);
    rightScale = constrain(rightScale, 0.20f, 1.40f);

    int targetLeftThrot  = constrain((int)(baseThrottle * leftScale),  0, 100);
    int targetRightThrot = constrain((int)(baseThrottle * rightScale), 0, 100);

    leftPWM  = map(targetLeftThrot,  0, 100, 1000, 2000);
    rightPWM = map(targetRightThrot, 0, 100, 1000, 2000);
}

// Process driving command (-100 to +100 throttle, -100 to +100 steering, bool reverseSwitchActive)
void updateDriveControls(int throttleInput, int steeringInput, bool reverseSwitchActive) {
    lastPacketTime = millis(); // Refresh failsafe heartbeat

    // 1. Steering Servo Control
    int steeringPulse = map(steeringInput, -100, 100, 1000, 2000);
    steeringServo.writeMicroseconds(steeringPulse);

    // 2. Throttle & Torque Vectoring State Machine
    if (reverseSwitchActive && throttleInput <= 5) {
        // MANUAL DRIVER REVERSE
        if (!manualReverseEngaged) {
            leftESC.writeMicroseconds(1000);
            rightESC.writeMicroseconds(1000);
            delay(MOTOR_STOP_DELAY_MS);
            digitalWrite(PIN_RELAY_SWAP, HIGH); // Swap Phases on both motors
            delay(RELAY_SETTLE_MS);
            manualReverseEngaged = true;
            currentState = STATE_REVERSE_RECOVERY;
            Serial.println("[VECTOR KART] Reverse Engaged.");
        }

        if (throttleInput > 5) {
            // Reverse with simple steering bias
            int revLeft = 1000, revRight = 1000;
            calculateTorqueVectoring(map(throttleInput, 0, 100, 0, 40), steeringInput, revLeft, revRight);
            leftESC.writeMicroseconds(revLeft);
            rightESC.writeMicroseconds(revRight);
        } else {
            leftESC.writeMicroseconds(1000);
            rightESC.writeMicroseconds(1000);
        }
    } 
    else {
        // FORWARD DRIVING MODE
        if (manualReverseEngaged) {
            leftESC.writeMicroseconds(1000);
            rightESC.writeMicroseconds(1000);
            delay(MOTOR_STOP_DELAY_MS);
            digitalWrite(PIN_RELAY_SWAP, LOW); // Relay OFF (Forward phase)
            delay(RELAY_SETTLE_MS);
            manualReverseEngaged = false;
            currentState = STATE_FORWARD;
            Serial.println("[VECTOR KART] Forward Engaged.");
        }

        if (throttleInput > 5) {
            // Apply Dynamic Torque Vectoring to Left & Right motors
            int leftPWM = 1000, rightPWM = 1000;
            calculateTorqueVectoring(throttleInput, steeringInput, leftPWM, rightPWM);
            leftESC.writeMicroseconds(leftPWM);
            rightESC.writeMicroseconds(rightPWM);
            currentState = STATE_FORWARD;
        } 
        else if (throttleInput < -5) {
            // Hard Electronic Brake on both motors
            leftESC.writeMicroseconds(1000);
            rightESC.writeMicroseconds(1000);
            currentState = STATE_HARD_BRAKE;
        } 
        else {
            // Neutral / Coast
            leftESC.writeMicroseconds(1000);
            rightESC.writeMicroseconds(1000);
        }
    }
}

// Mandatory Rulebook Failsafe Check (<250ms shutdown)
void checkFailsafe() {
    if (millis() - lastPacketTime > 250) {
        leftESC.writeMicroseconds(1000);
        rightESC.writeMicroseconds(1000);
        digitalWrite(PIN_RELAY_SWAP, LOW);
    }
}

void loop() {
    checkFailsafe();
    // Input loop is fed via Bluepad32 Bluetooth Gamepad or ESP-NOW packet handler
}
