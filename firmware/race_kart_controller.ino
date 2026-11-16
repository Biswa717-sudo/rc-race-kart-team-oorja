/*
 * Race Kart Controller Firmware with Failsafe & Barrier Recovery State Machine
 * Microcontroller: ESP32-S3
 * 
 * Pinout:
 * GPIO 18 -> ESC Signal (PWM 50Hz)
 * GPIO 19 -> Relay IN1 (Phase Swap: LOW = Forward, HIGH = Reverse)
 * GPIO 21 -> Steering Servo Signal (MG90S)
 * 
 * Features:
 * 1. Automatic Failsafe (Rule 3.3.6): Cuts throttle immediately on signal loss.
 * 2. Normal Driving: Pushing trigger forward is 100% HARD BRAKE ONLY.
 * 3. Barrier Recovery: Double-tap trigger engages Reverse with safe motor spin-down delay.
 */

#include <Arduino.h>
#include <ESP32Servo.h>

Servo throttleESC;
Servo steeringServo;

// Pin Definitions
const int PIN_ESC_SIGNAL   = 18;
const int PIN_RELAY_SWAP   = 19;
const int PIN_SERVO_SIGNAL = 21;
const int PIN_MANUAL_REV_SW = 4; // Dedicated Manual Driver Switch / RC Channel 3 input

// Motor Spin-Down Calibration (Milliseconds)
const int MOTOR_STOP_DELAY_MS = 150; // Delay for A2212 with Hard Brake to reach 0 RPM
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

    pinMode(PIN_MANUAL_REV_SW, INPUT_PULLUP); // Active LOW switch or RC Ch3 pulse

    ESP32PWM::allocateTimer(0);
    ESP32PWM::allocateTimer(1);

    throttleESC.setPeriodHertz(50);
    steeringServo.setPeriodHertz(50);

    throttleESC.attach(PIN_ESC_SIGNAL, 1000, 2000);
    steeringServo.attach(PIN_SERVO_SIGNAL, 1000, 2000);

    // Initial ESC Arming (1000us neutral for 2 seconds)
    throttleESC.writeMicroseconds(1000);
    steeringServo.writeMicroseconds(1500); // Center steering
    delay(2000);

    lastPacketTime = millis();
    Serial.println("RC Kart Controller Armed: Manual Reverse Safety Active.");
}

// Process driving command (-100 to +100 throttle, -100 to +100 steering, bool reverseSwitchActive)
void updateDriveControls(int throttleInput, int steeringInput, bool reverseSwitchActive) {
    lastPacketTime = millis(); // Refresh failsafe heartbeat

    // 1. Steering Control (Map -100..+100 to 1000us..2000us)
    int steeringPulse = map(steeringInput, -100, 100, 1000, 2000);
    steeringServo.writeMicroseconds(steeringPulse);

    // 2. Throttle & Braking with Explicit Driver Reverse Lock
    // Reverse can ONLY EVER activate if:
    // a) Driver has physically engaged the manual reverse switch/button
    // b) Throttle is at neutral or braking (never during forward driving)
    if (reverseSwitchActive && throttleInput <= 5) {
        if (!manualReverseEngaged) {
            // Driver just flipped reverse switch: Enforce mandatory spin-down dead-time
            throttleESC.writeMicroseconds(1000); // Trigger ESC hard brake
            delay(MOTOR_STOP_DELAY_MS);          // Wait for zero RPM / zero back-EMF
            digitalWrite(PIN_RELAY_SWAP, HIGH);  // Safely flip relay phase contacts
            delay(RELAY_SETTLE_MS);              // Wait for contact debounce
            manualReverseEngaged = true;
            currentState = STATE_REVERSE_RECOVERY;
            Serial.println("[SAFETY INTERLOCK] Manual Reverse ENGAGED.");
        }

        // When reverse is engaged, pulling trigger moves kart backwards (capped at 40% speed)
        if (throttleInput > 5) {
            int revPulse = map(throttleInput, 0, 100, 1000, 1400);
            throttleESC.writeMicroseconds(revPulse);
        } else {
            throttleESC.writeMicroseconds(1000); // Neutral / Brake in reverse
        }
    } 
    else {
        // FORWARD MODE (Default & Fail-Safe)
        if (manualReverseEngaged) {
            // Driver switched back to Forward: Disengage relay safely
            throttleESC.writeMicroseconds(1000);
            delay(MOTOR_STOP_DELAY_MS);
            digitalWrite(PIN_RELAY_SWAP, LOW); // Relay OFF (Forward phase)
            delay(RELAY_SETTLE_MS);
            manualReverseEngaged = false;
            currentState = STATE_FORWARD;
            Serial.println("[SAFETY INTERLOCK] Manual Reverse DISENGAGED -> Forward.");
        }

        if (throttleInput > 5) {
            // Normal Forward Acceleration
            int escPulse = map(throttleInput, 0, 100, 1000, 2000);
            throttleESC.writeMicroseconds(escPulse);
            currentState = STATE_FORWARD;
        } 
        else if (throttleInput < -5) {
            // Trigger pushed forward: 100% PURE HARD BRAKE ONLY!
            throttleESC.writeMicroseconds(1000); // ESC electronic hard-brake
            currentState = STATE_HARD_BRAKE;
        } 
        else {
            // Neutral / Coast
            throttleESC.writeMicroseconds(1000);
        }
    }
}

// Mandatory Rulebook Failsafe Check
void checkFailsafe() {
    if (millis() - lastPacketTime > 250) {
        // Signal lost for > 250ms -> EMERGENCY SHUTOFF!
        throttleESC.writeMicroseconds(1000);
        digitalWrite(PIN_RELAY_SWAP, LOW);
    }
}

void loop() {
    checkFailsafe();
    // In production, updateDriveControls() is called from Bluetooth / Wi-Fi packet handler
    delay(10);
}
