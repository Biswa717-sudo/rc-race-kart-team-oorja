/*
 * ======================================================================================
 * ESP32 MG90S SERVO BENCH TESTER (POTENTIOMETER ANGLE + COMPUTER SPEED CONTROL)
 * 
 * 🎮 CONTROL INTERFACE:
 * 1. 10k Potentiometer on G34: Controls Servo Target Angle (0° to 180°).
 * 2. Computer (Serial Monitor at 115200 baud): Controls Servo Slew Rate / Speed!
 *    - Type any speed from 10 to 600 (degrees per second), or 'MAX' for instant!
 *    - Examples: 
 *        Type "30"  -> Ultra-slow smooth cinematic sweep (30 deg/sec)
 *        Type "120" -> Realistic scale steering rack speed (120 deg/sec)
 *        Type "300" -> Fast racing steering speed (300 deg/sec)
 *        Type "0" or "MAX" -> Maximum raw servo speed (Instant step response)
 * 
 * 🔌 SINGLE-SIDE HEADER WIRING (Standard Classic ESP32):
 * [ 3V3 | EN | VP | VN | G34 | G35 | G32 | G33 | G25 | G26 | G27 | G14 | G12 | GND | 5V/VIN ]
 * 
 * 1. 10k Potentiometer (3 Pins):
 *    - Leg 1 (Outer)   -> ESP32 "3V3" pin (Top pin on rail)
 *    - Leg 2 (Wiper)   -> ESP32 "G34" pin (Analog ADC input)
 *    - Leg 3 (Outer)   -> ESP32 "GND" pin (Near bottom)
 * 
 * 2. TowerPro MG90S Micro Servo (3 Pins):
 *    - Orange/Yellow (Signal) -> ESP32 "G32" pin (PWM signal)
 *    - Red (VCC +5V)          -> ESP32 "5V" or "VIN" pin (⚠️ MG90S needs 5V for torque!)
 *    - Brown/Black (GND)      -> ESP32 "GND" pin (Shared ground on same rail)
 * ======================================================================================
 */

#include <Arduino.h>
#include <ESP32Servo.h>

// --- PIN DEFINITIONS (ALL ON SAME SIDE) ---
const int PIN_POT_WIPER  = 34; // Pin "G34" (Analog ADC input)
const int PIN_SERVO_SIG  = 32; // Pin "G32" (PWM 50Hz Servo output)
const int PIN_STATUS_LED = 2;  // Onboard Blue LED

// --- MG90S PULSE SPECS ---
const int SERVO_MIN_US   = 500;  // 0 degrees pulse width (~500 - 544 us)
const int SERVO_MAX_US   = 2400; // 180 degrees pulse width (~2400 us)

Servo steeringServo;

// --- DYNAMIC CONTROL STATE ---
float currentAngle = 90.0;    // Current tracked angle (0.0 to 180.0 deg)
float targetAngle  = 90.0;    // Target angle from potentiometer
float speedDegPerSec = 150.0; // Current speed (deg/sec). 0 = Instant/Max.

// Analog Filter State
float filteredADC = 2048.0;
const float FILTER_ALPHA = 0.35; // Responsive smoothing

unsigned long lastUpdateTime = 0;
unsigned long lastTelemetryTime = 0;

void printHelp() {
    Serial.println("\n=======================================================");
    Serial.println("  ESP32 MG90S SERVO TESTER (POT ANGLE + PC SPEED)");
    Serial.println("=======================================================");
    Serial.println("  [Hardware Wiring - All on Same Header Rail]:");
    Serial.println("    * Potentiometer: 3.3V=3V3 | Wiper=G34 | Ground=GND");
    Serial.println("    * MG90S Servo:   Signal=G32 | VCC=5V/VIN | Ground=GND");
    Serial.println("-------------------------------------------------------");
    Serial.println("  [Computer Speed Commands - Type in Serial Monitor]:");
    Serial.println("    * Type '30'   -> 30 deg/sec  (Slow / smooth)");
    Serial.println("    * Type '150'  -> 150 deg/sec (Realistic F1 steering)");
    Serial.println("    * Type '300'  -> 300 deg/sec (High-speed racing)");
    Serial.println("    * Type '0' or 'MAX' -> Instant raw servo speed");
    Serial.println("=======================================================\n");
}

void setup() {
    Serial.begin(115200);

    pinMode(PIN_STATUS_LED, OUTPUT);
    digitalWrite(PIN_STATUS_LED, HIGH);

    // Configure ADC on G34
    analogReadResolution(12);
    analogSetAttenuation(ADC_11db);
    filteredADC = analogRead(PIN_POT_WIPER);

    // Attach MG90S on G32 with standard 50Hz servo refresh
    ESP32PWM::allocateTimer(0);
    steeringServo.setPeriodHertz(50);
    steeringServo.attach(PIN_SERVO_SIG, SERVO_MIN_US, SERVO_MAX_US);

    // Initial center position
    steeringServo.write(90);
    currentAngle = 90.0;

    printHelp();
    Serial.println("POT_RAW | VOLTS | TARGET_ANG | CURRENT_ANG | SPEED (deg/s) | VISUAL GAUGE");
    Serial.println("-------------------------------------------------------------------------");

    lastUpdateTime = micros();
}

void loop() {
    // -------------------------------------------------------------
    // 1. READ SERIAL COMMANDS FROM COMPUTER (SET SPEED)
    // -------------------------------------------------------------
    if (Serial.available() > 0) {
        String input = Serial.readStringUntil('\n');
        input.trim();
        input.toUpperCase();

        if (input == "MAX" || input == "INSTANT" || input == "FAST") {
            speedDegPerSec = 0.0;
            Serial.println("\n⚡ [SPEED UPDATE] Servo Speed set to: MAXIMUM / INSTANT (No rate limit)!\n");
        } else {
            float val = input.toFloat();
            if (val >= 0.0) {
                speedDegPerSec = val;
                Serial.print("\n🎯 [SPEED UPDATE] Servo Speed set to: ");
                if (speedDegPerSec == 0.0) {
                    Serial.println("MAXIMUM / INSTANT (0 deg/sec delay)\n");
                } else {
                    Serial.print(speedDegPerSec, 1);
                    Serial.println(" deg/sec\n");
                }
            } else {
                Serial.println("\n⚠️ [INVALID] Enter a positive number (e.g. 50, 150, 300) or 'MAX'!\n");
            }
        }
    }

    // -------------------------------------------------------------
    // 2. READ POTENTIOMETER & COMPUTE TARGET ANGLE
    // -------------------------------------------------------------
    int rawADC = analogRead(PIN_POT_WIPER);
    filteredADC = (FILTER_ALPHA * rawADC) + ((1.0 - FILTER_ALPHA) * filteredADC);

    // Map 12-bit ADC (60 to 4030) to Servo Angle (0° to 180°)
    if (filteredADC < 60) {
        targetAngle = 0.0;
    } else if (filteredADC > 4030) {
        targetAngle = 180.0;
    } else {
        targetAngle = (filteredADC - 60.0) * (180.0 / (4030.0 - 60.0));
        targetAngle = constrain(targetAngle, 0.0, 180.0);
    }

    // Optional 3° center deadband around 90° for steering centering
    if (fabs(targetAngle - 90.0) < 1.5) {
        targetAngle = 90.0;
    }

    // -------------------------------------------------------------
    // 3. APPLY SPEED SLEW RATE TOWARDS TARGET ANGLE
    // -------------------------------------------------------------
    unsigned long nowMicros = micros();
    float dt = (nowMicros - lastUpdateTime) / 1000000.0; // Seconds elapsed
    lastUpdateTime = nowMicros;

    if (dt > 0.1) dt = 0.1; // Clamp on overflow

    if (speedDegPerSec <= 0.0) {
        // Instant speed (No slew limit)
        currentAngle = targetAngle;
    } else {
        // Smoothly step towards target angle at speedDegPerSec
        float maxStep = speedDegPerSec * dt;
        float error = targetAngle - currentAngle;

        if (fabs(error) <= maxStep) {
            currentAngle = targetAngle;
        } else {
            currentAngle += (error > 0 ? maxStep : -maxStep);
        }
    }

    // Write angle to MG90S servo
    steeringServo.write((int)round(currentAngle));

    // -------------------------------------------------------------
    // 4. LIVE TELEMETRY OUTPUT (10 Hz)
    // -------------------------------------------------------------
    if (millis() - lastTelemetryTime >= 100) {
        lastTelemetryTime = millis();

        float potVolts = (filteredADC / 4095.0) * 3.3;
        
        char buffer[90];
        snprintf(buffer, sizeof(buffer), " %4d   | %4.2fV |   %5.1f°   |   %5.1f°    |   %5.1f deg/s | [",
                 (int)filteredADC, potVolts, targetAngle, currentAngle, speedDegPerSec);
        Serial.print(buffer);

        // Visual Angular Position Needle (0° Left | 90° Center | 180° Right)
        const int gaugeWidth = 19;
        int needlePos = (int)map((int)currentAngle, 0, 180, 0, gaugeWidth - 1);
        needlePos = constrain(needlePos, 0, gaugeWidth - 1);

        for (int i = 0; i < gaugeWidth; ++i) {
            if (i == needlePos) Serial.print("▲");
            else if (i == gaugeWidth / 2) Serial.print("|");
            else Serial.print("-");
        }

        if (fabs(currentAngle - 90.0) < 1.0) {
            Serial.println("] [CENTER]");
        } else if (currentAngle < 45.0) {
            Serial.println("] [FULL LEFT]");
        } else if (currentAngle > 135.0) {
            Serial.println("] [FULL RIGHT]");
        } else {
            Serial.println("] [STEERING]");
        }
    }

    delay(5); // 200 Hz update loop
}
