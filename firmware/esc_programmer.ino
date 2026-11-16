/*
 * ESP32-S3 ESC Configuration & Programming Tool
 * Connect ESC Signal pin to GPIO 18, GND to GND.
 * 
 * Commands in Serial Monitor (115200 baud):
 * 'U' -> 2000 us (Full Throttle / Enter menu / Select option)
 * 'M' -> 1500 us (Center / Sub-option select)
 * 'D' -> 1000 us (Zero Throttle / Save & Exit)
 */

#include <Arduino.h>
#include <ESP32Servo.h>

Servo esc;
const int ESC_SIGNAL_PIN = 18;

void setup() {
    Serial.begin(115200);
    delay(1000);

    ESP32PWM::allocateTimer(0);
    esc.setPeriodHertz(50);
    esc.attach(ESC_SIGNAL_PIN, 1000, 2000);

    Serial.println("\n==============================================");
    Serial.println("  ESP32-S3 BRUSHLESS ESC PROGRAMMING UTILITY   ");
    Serial.println("==============================================");
    Serial.println("Instructions:");
    Serial.println("1. Type 'U' (Full Up 2000us) BEFORE plugging in LiPo battery.");
    Serial.println("2. Plug in LiPo battery -> Listen for opening musical chimes.");
    Serial.println("3. Listen for Beep Sequence (1 to 6 beeps).");
    Serial.println("4. Type 'M' (Center 1500us) to enter sub-options.");
    Serial.println("5. Count sub-option beeps, type 'U' (2000us) to save.");
    Serial.println("6. Type 'D' (1000us) to exit programming mode.");
    Serial.println("==============================================\n");
}

void loop() {
    if (Serial.available()) {
        char cmd = Serial.read();
        if (cmd == 'U' || cmd == 'u') {
            esc.writeMicroseconds(2000);
            Serial.println("[THROTTLE] --> 2000 us (FULL UP / ENTER / SELECT)");
        } else if (cmd == 'M' || cmd == 'm') {
            esc.writeMicroseconds(1500);
            Serial.println("[THROTTLE] --> 1500 us (CENTER / SUB-OPTION)");
        } else if (cmd == 'D' || cmd == 'd') {
            esc.writeMicroseconds(1000);
            Serial.println("[THROTTLE] --> 1000 us (FULL DOWN / SAVE & EXIT)");
        }
    }
}
