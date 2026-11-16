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
unsigned long lastBrakeTime = 0;
unsigned long lastPacketTime = 0;

void setup() {
    Serial.begin(115200);

    pinMode(PIN_RELAY_SWAP, OUTPUT);
    digitalWrite(PIN_RELAY_SWAP, LOW); // Default: Forward Phase (Relay OFF)

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
    Serial.println("RC Kart Controller Armed and Ready.");
}

// Process driving command (-100 to +100 throttle, -100 to +100 steering)
void updateDriveControls(int throttleInput, int steeringInput) {
    lastPacketTime = millis(); // Refresh failsafe heartbeat

    // 1. Steering Control (Map -100..+100 to 1000us..2000us)
    int steeringPulse = map(steeringInput, -100, 100, 1000, 2000);
    steeringServo.writeMicroseconds(steeringPulse);

    // 2. Throttle & Braking State Machine
    if (throttleInput > 5) {
        // FORWARD ACCELERATION
        if (currentState == STATE_REVERSE_RECOVERY) {
            // Returning from reverse to forward
            throttleESC.writeMicroseconds(1000);
            delay(MOTOR_STOP_DELAY_MS);
            digitalWrite(PIN_RELAY_SWAP, LOW); // Relay OFF
            delay(RELAY_SETTLE_MS);
        }
        digitalWrite(PIN_RELAY_SWAP, LOW);
        int escPulse = map(throttleInput, 0, 100, 1000, 2000);
        throttleESC.writeMicroseconds(escPulse);
        currentState = STATE_FORWARD;
    } 
    else if (throttleInput < -5) {
        // PUSHING TRIGGER FORWARD: BRAKE OR BARRIER UNSTICK
        if (currentState == STATE_FORWARD) {
            // First Tap: HARD BRAKE ONLY!
            throttleESC.writeMicroseconds(1000); // Triggers ESC Hard Brake
            lastBrakeTime = millis();
            currentState = STATE_HARD_BRAKE;
        } 
        else if (currentState == STATE_HARD_BRAKE && (millis() - lastBrakeTime > 200)) {
            // Second Tap (Double-Tap while stopped against wall): ENGAGE REVERSE!
            throttleESC.writeMicroseconds(1000); // Ensure 0% power
            delay(MOTOR_STOP_DELAY_MS);          // Wait for motor to fully stop
            digitalWrite(PIN_RELAY_SWAP, HIGH);  // Energize Relay (Swap Phases)
            delay(RELAY_SETTLE_MS);              // Wait for contacts to settle
            
            // Apply controlled 40% reverse power to back away safely
            throttleESC.writeMicroseconds(1400);
            currentState = STATE_REVERSE_RECOVERY;
        }
    } 
    else {
        // NEUTRAL (Coast)
        throttleESC.writeMicroseconds(1000);
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
