/*
 * ======================================================================================
 * STANDARD ESP32 (ESP32-WROOM-32 / DevKit V1) BENCH TEST UTILITY
 * Target: A2212 Brushless Outrunner Motor + BLHeli 30A ESC
 * Controller: 10k Ohm Linear Potentiometer (Manual Throttle Knob)
 * Team Oorja F1 RC Race - Powertrain Bench Calibration
 * ======================================================================================
 * 
 * 🔌 HARDWARE WIRING (Standard ESP32 30-pin or 38-pin DevKit):
 * 
 * 1. 10k Potentiometer (3 Pins):
 *    - Pin 1 (Outer leg)   -> ESP32 "3V3" pin (⚠️ NEVER 5V! 5V will burn the ESP32 ADC!)
 *    - Pin 2 (Middle leg)  -> ESP32 "GPIO 34" (Clean ADC1 input-only pin)
 *    - Pin 3 (Outer leg)   -> ESP32 "GND" pin
 * 
 * 2. BLHeli 30A ESC (3-pin Servo Signal Lead):
 *    - White or Yellow wire -> ESP32 "GPIO 18" (PWM 50Hz signal)
 *    - Black or Brown wire  -> ESP32 "GND" pin (⚠️ MANDATORY: Common Ground!)
 *    - Red wire (+5V BEC)   -> LEAVE DISCONNECTED & TAPED OFF during PC USB testing!
 * 
 * 3. BLHeli 30A ESC (Heavy Power & Motor Wires):
 *    - Heavy RED / BLACK    -> 2S LiPo Battery (7.4V / 8.4V Peak) via XT60
 *    - 3 Blue/Black wires   -> 3 Wires of A2212 Motor (via 3.5mm bullet connectors)
 * 
 * ⚠️ BENCH SAFETY RULES:
 * 1. NEVER ATTACH A PROPELLER! The motor shaft must spin completely BARE.
 * 2. Clamp or tape the motor down to your table so motor torque doesn't spin it off.
 * ======================================================================================
 */

#include <Arduino.h>
#include <ESP32Servo.h>

// -----------------------------------------------------------------------------
// Pin Configuration for Standard Classic ESP32
// -----------------------------------------------------------------------------
const int PIN_POT_WIPER   = 34;  // GPIO 34 (ADC1_CH6 - Cleanest ADC on standard ESP32)
const int PIN_ESC_SIGNAL  = 18;  // GPIO 18 (Standard 50Hz PWM output)
const int PIN_STATUS_LED  = 2;   // GPIO 2  (Onboard Blue LED on ESP32 DevKit V1)

// ESC Pulse Width Limits (Microseconds)
const int ESC_MIN_US      = 1000; // Zero throttle / Stop / Arming pulse
const int ESC_MAX_US      = 2000; // Full throttle (100%)
const int ESC_DEADBAND_US = 1040; // Below this = guaranteed 0 RPM stop
const int ESC_FULL_US     = 1960; // Above this = 100% full throttle

// 16-Sample Moving Average Filter (Eliminates wiper jitter)
const int NUM_SAMPLES     = 16;
int sampleBuffer[NUM_SAMPLES];
int sampleIndex = 0;
long sampleSum = 0;

Servo esc;
unsigned long lastTelemetryTime = 0;

// Read and filter analog pot input
int readFilteredADC() {
    sampleSum -= sampleBuffer[sampleIndex];
    int rawValue = analogRead(PIN_POT_WIPER);
    sampleBuffer[sampleIndex] = rawValue;
    sampleSum += rawValue;
    sampleIndex = (sampleIndex + 1) % NUM_SAMPLES;
    return (int)(sampleSum / NUM_SAMPLES);
}

// Draw ASCII progress bar in Serial Monitor
void printProgressBar(float percent) {
    const int barWidth = 18;
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
    Serial.println("  STANDARD ESP32 BENCH TESTER: A2212 + BLHELI 30A ESC");
    Serial.println("=======================================================");

    // Onboard Status LED
    pinMode(PIN_STATUS_LED, OUTPUT);
    digitalWrite(PIN_STATUS_LED, LOW);

    // Configure ESP32 ADC
    analogReadResolution(12);       // 12-bit ADC: 0 to 4095
    analogSetAttenuation(ADC_11db); // Full 0V - 3.3V range

    // Initialize ADC filter buffer
    for (int i = 0; i < NUM_SAMPLES; i++) {
        sampleBuffer[i] = analogRead(PIN_POT_WIPER);
        sampleSum += sampleBuffer[i];
        delay(5);
    }

    // Initialize ESP32 PWM Timer for 50Hz ESC refresh
    ESP32PWM::allocateTimer(0);
    esc.setPeriodHertz(50); // 50 Hz standard servo/ESC frequency
    esc.attach(PIN_ESC_SIGNAL, ESC_MIN_US, ESC_MAX_US);

    // -------------------------------------------------------------
    // SAFETY INTERLOCK: Verify Potentiometer is at ZERO before arming
    // -------------------------------------------------------------
    Serial.println("\n[SAFETY CHECK] Checking throttle knob position...");
    int potVal = readFilteredADC();
    while (potVal > 250) { // If pot is turned up > ~6%
        digitalWrite(PIN_STATUS_LED, !digitalRead(PIN_STATUS_LED)); // Flash LED
        Serial.print("⚠️ [SAFETY WARNING] Potentiometer is NOT at zero! (ADC: ");
        Serial.print(potVal);
        Serial.println(") -> TURN POTENTIOMETER ALL THE WAY DOWN TO ARM!");
        esc.writeMicroseconds(ESC_MIN_US);
        delay(400);
        potVal = readFilteredADC();
    }

    digitalWrite(PIN_STATUS_LED, HIGH); // Solid ON when armed
    Serial.println("✅ Potentiometer confirmed at ZERO position.");

    // -------------------------------------------------------------
    // BLHELI 30A ARMING SEQUENCE
    // -------------------------------------------------------------
    Serial.println("\n[ARMING] Holding 1000 us arming signal for BLHeli ESC...");
    Serial.println("  -> Listen for 3 beeps (2S LiPo cell detection)");
    Serial.println("  -> Followed by 1 long arming confirmation chime!");

    for (int i = 0; i < 25; i++) {
        esc.writeMicroseconds(ESC_MIN_US);
        delay(100);
        Serial.print(".");
    }

    Serial.println("\n\n🎉 [ARMED] BLHeli ESC is ARMED and live!");
    Serial.println("Turn the 10k knob slowly clockwise to spin the motor.\n");
    Serial.println("ADC_RAW | VOLTS  | PULSE (us) | THROTTLE % | GRAPHICAL MONITOR");
    Serial.println("----------------------------------------------------------------");
}

void loop() {
    int filteredADC = readFilteredADC();
    float potVolts = (filteredADC / 4095.0) * 3.3;

    // Map ADC (0 - 4095) to ESC pulse (1000 - 2000 us) with deadband
    int targetUs;
    if (filteredADC < 80) {
        // Bottom deadband: crisp zero-RPM stop
        targetUs = ESC_MIN_US;
    } else if (filteredADC > 4000) {
        // Top deadband: 100% full throttle reached easily
        targetUs = ESC_MAX_US;
    } else {
        targetUs = map(filteredADC, 80, 4000, ESC_MIN_US, ESC_MAX_US);
        targetUs = constrain(targetUs, ESC_MIN_US, ESC_MAX_US);
    }

    // Enforce deadband clamp
    if (targetUs < ESC_DEADBAND_US) {
        targetUs = ESC_MIN_US;
    }

    // Send PWM pulse to BLHeli ESC
    esc.writeMicroseconds(targetUs);

    // Calculate throttle percentage
    float throttlePct = 0.0;
    if (targetUs > ESC_MIN_US) {
        throttlePct = ((float)(targetUs - ESC_MIN_US) / (float)(ESC_MAX_US - ESC_MIN_US)) * 100.0;
    }

    // Telemetry output at 10 Hz (every 100ms)
    if (millis() - lastTelemetryTime >= 100) {
        lastTelemetryTime = millis();

        char buffer[80];
        snprintf(buffer, sizeof(buffer), " %4d   | %4.2fV  |  %4d us   |   %5.1f%%   |", 
                 filteredADC, potVolts, targetUs, throttlePct);
        Serial.print(buffer);

        printProgressBar(throttlePct);

        if (targetUs == ESC_MIN_US) {
            Serial.println(" [0 RPM IDLE]");
        } else if (targetUs == ESC_MAX_US) {
            Serial.println(" [100% WOT]");
        } else {
            Serial.println(" [SPINNING]");
        }
    }

    delay(10);
}
