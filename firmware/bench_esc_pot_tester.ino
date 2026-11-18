/*
 * ======================================================================================
 * ESP32-S3 BENCH TEST UTILITY: A2212 BRUSHLESS MOTOR & BLHELI 30A ESC
 * Controlled via 10k Ohm Potentiometer
 * Team Oorja F1 RC Race - Powertrain Bench Calibration
 * ======================================================================================
 * 
 * HARDWARE CONNECTIONS:
 * 
 * 1. 10k Potentiometer:
 *    - Leg 1 (Outer)   -> ESP32 3.3V (⚠️ CRITICAL: DO NOT USE 5V! 5V will damage ADC!)
 *    - Leg 2 (Wiper)   -> ESP32 GPIO 4 (ADC1 Channel 3)
 *    - Leg 3 (Outer)   -> ESP32 GND
 * 
 * 2. BLHeli 30A ESC Signal Lead (3-pin servo wire):
 *    - White or Yellow -> ESP32 GPIO 18 (PWM Output)
 *    - Black or Brown  -> ESP32 GND (Common Ground is MANDATORY)
 *    - Red (+5V BEC)   -> DISCONNECTED! Tape off during USB PC testing!
 * 
 * 3. BLHeli 30A ESC Power & Motor:
 *    - Heavy Red/Black -> 2S LiPo Battery (7.4V / 8.4V Peak) via XT60
 *    - 3 Blue/Black    -> 3 Wires of A2212 Brushless Motor (via 3.5mm bullets)
 * 
 * ⚠️ BENCH SAFETY RULES:
 * - NEVER ATTACH A PROPELLER! The motor shaft must spin completely bare.
 * - Secure the motor securely to a bench vise or weighted base so torque does not flip it.
 * ======================================================================================
 */

#include <Arduino.h>
#include <ESP32Servo.h>

// Pin Configuration
const int PIN_POT_WIPER   = 4;   // ADC1_CH3 on ESP32-S3
const int PIN_ESC_SIGNAL  = 18;  // PWM output to BLHeli ESC
const int PIN_STATUS_LED  = 2;   // Onboard LED (or GPIO 21 / RGB LED)

// ESC Pulse Width Limits (Microseconds)
const int ESC_MIN_US      = 1000; // Zero throttle / Stop / Arming pulse
const int ESC_MAX_US      = 2000; // Full throttle (100%)
const int ESC_DEADBAND_US = 1040; // Below this = guaranteed 0 RPM stop
const int ESC_FULL_US     = 1960; // Above this = 100% full throttle

// Analog ADC Noise Filtering
const int NUM_SAMPLES     = 16;
int sampleBuffer[NUM_SAMPLES];
int sampleIndex = 0;
long sampleSum = 0;

// Object
Servo esc;

// State Flags
bool isArmed = false;
unsigned long lastTelemetryTime = 0;

// Function: Read and filter ADC
int readFilteredADC() {
    sampleSum -= sampleBuffer[sampleIndex];
    int rawValue = analogRead(PIN_POT_WIPER);
    sampleBuffer[sampleIndex] = rawValue;
    sampleSum += rawValue;
    sampleIndex = (sampleIndex + 1) % NUM_SAMPLES;
    return (int)(sampleSum / NUM_SAMPLES);
}

// Function: Draw ASCII bar in Serial Monitor
void printProgressBar(float percent) {
    const int barWidth = 20;
    int pos = (int)((percent / 100.0) * barWidth);
    Serial.print(" [");
    for (int i = 0; i < barWidth; ++i) {
        if (i < pos) Serial.print("=");
        else if (i == pos) Serial.print(">");
        else Serial.print(" ");
    }
    Serial.print("] ");
}

void setup() {
    Serial.begin(115200);
    delay(1000);

    Serial.println("\n=======================================================");
    Serial.println("  ESP32-S3 BENCH TESTER: A2212 + BLHELI 30A ESC");
    Serial.println("=======================================================");

    // Configure Status LED
    pinMode(PIN_STATUS_LED, OUTPUT);
    digitalWrite(PIN_STATUS_LED, LOW);

    // Configure ADC
    analogReadResolution(12); // 12-bit (0 - 4095)
    analogSetAttenuation(ADC_11db); // Full scale 0V - 3.3V

    // Pre-fill filter buffer
    for (int i = 0; i < NUM_SAMPLES; i++) {
        sampleBuffer[i] = analogRead(PIN_POT_WIPER);
        sampleSum += sampleBuffer[i];
        delay(5);
    }

    // Attach ESC with 50Hz servo timing
    ESP32PWM::allocateTimer(0);
    esc.setPeriodHertz(50); // Standard 50Hz ESC refresh rate
    esc.attach(PIN_ESC_SIGNAL, ESC_MIN_US, ESC_MAX_US);

    // -------------------------------------------------------------
    // SAFETY INTERLOCK: Verify Potentiometer is at ZERO before arming
    // -------------------------------------------------------------
    Serial.println("\n[SAFETY CHECK] Checking throttle knob position...");
    int potVal = readFilteredADC();
    while (potVal > 250) { // If pot is turned up more than ~6%
        digitalWrite(PIN_STATUS_LED, !digitalRead(PIN_STATUS_LED));
        Serial.print("⚠️ [SAFETY WARNING] Potentiometer is NOT at zero! Raw ADC: ");
        Serial.print(potVal);
        Serial.println(" -> TURN KNOB ALL THE WAY DOWN TO ZERO TO ARM!");
        esc.writeMicroseconds(ESC_MIN_US); // Hold safe pulse
        delay(400);
        potVal = readFilteredADC();
    }

    digitalWrite(PIN_STATUS_LED, HIGH);
    Serial.println("✅ Potentiometer confirmed at ZERO position.");

    // -------------------------------------------------------------
    // BLHELI 30A ARMING SEQUENCE
    // -------------------------------------------------------------
    Serial.println("\n[ARMING] Sending 1000 us arming signal to BLHeli ESC...");
    Serial.println("  -> Listen for 3 beeps (2S LiPo cell detection)");
    Serial.println("  -> Followed by 1 long arming confirmation beep!");

    for (int i = 0; i < 25; i++) {
        esc.writeMicroseconds(ESC_MIN_US);
        delay(100);
        Serial.print(".");
    }
    Serial.println("\n🎉 [ARMED] BLHeli ESC is ARMED and ready! Turn knob smoothly to spin motor.\n");
    Serial.println("ADC_RAW | VOLTS  | PULSE (us) | THROTTLE % | GRAPHICAL BAR");
    Serial.println("---------------------------------------------------------------");
    isArmed = true;
}

void loop() {
    int filteredADC = readFilteredADC();
    float potVolts = (filteredADC / 4095.0) * 3.3;

    // Map ADC (0 - 4095) to ESC Microseconds (1000 - 2000 us)
    int targetUs;
    if (filteredADC < 80) {
        // Crisp bottom deadband (Guaranteed 0 RPM stop)
        targetUs = ESC_MIN_US;
    } else if (filteredADC > 4000) {
        // Top deadband (Guaranteed 100% full throttle)
        targetUs = ESC_MAX_US;
    } else {
        targetUs = map(filteredADC, 80, 4000, ESC_MIN_US, ESC_MAX_US);
        targetUs = constrain(targetUs, ESC_MIN_US, ESC_MAX_US);
    }

    // Apply Deadband Clamp
    if (targetUs < ESC_DEADBAND_US) {
        targetUs = ESC_MIN_US;
    }

    // Send PWM pulse to BLHeli ESC
    esc.writeMicroseconds(targetUs);

    // Calculate Throttle Percentage
    float throttlePct = 0.0;
    if (targetUs > ESC_MIN_US) {
        throttlePct = ((float)(targetUs - ESC_MIN_US) / (float)(ESC_MAX_US - ESC_MIN_US)) * 100.0;
    }

    // Live Telemetry Output every 100ms
    if (millis() - lastTelemetryTime >= 100) {
        lastTelemetryTime = millis();

        // Format telemetry row
        char buffer[80];
        snprintf(buffer, sizeof(buffer), " %4d   | %4.2fV  |  %4d us   |   %5.1f%%   |", 
                 filteredADC, potVolts, targetUs, throttlePct);
        Serial.print(buffer);

        // Graphical Visual Bar
        printProgressBar(throttlePct);

        // Motor State Note
        if (targetUs == ESC_MIN_US) {
            Serial.println(" [MOTOR STOP]");
        } else if (targetUs == ESC_MAX_US) {
            Serial.println(" [100% MAX]");
        } else {
            Serial.println(" [RUNNING]");
        }
    }

    delay(10); // 100Hz loop rate
}
