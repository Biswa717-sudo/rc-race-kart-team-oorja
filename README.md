# 🏎️ Scratch-Built 1/10 RWD RC Race Kart (Team Oorja F1 RC Race)

[![Rulebook Compliant](https://img.shields.io/badge/Rulebook-Team%20Oorja%20Division%20B-success?style=for-the-badge&logo=formula1)](F1%20RC%20Rulebook1.pdf)
[![Voltage Limit](https://img.shields.io/badge/Battery%20Voltage-%E2%89%A4%208.4V%20(2S%20LiPo)-brightgreen?style=for-the-badge)](docs/MASTER_TIMELINE_COMPARISON.md)
[![Drivetrain](https://img.shields.io/badge/Drivetrain-RWD%20Live%20Axle-orange?style=for-the-badge)](#mechanical-architecture)
[![Microcontroller](https://img.shields.io/badge/Brain-ESP32--S3-blue?style=for-the-badge&logo=espressif)](#electronics--control)
[![Currency](https://img.shields.io/badge/Budget%20Currency-%E2%82%B9%20INR-blueviolet?style=for-the-badge)](#master-budget-in--inr)

Comprehensive engineering specifications, 3D CAD renders, vector blueprints, firmware code, and three complete build timelines for a scratch-built 1/10 scale competition electric racing go-kart competing in **Team Oorja's F1 RC Race (Division B: Build Your Own RC Cars)**.

---

## 📚 Complete Engineering Documentation & Plans

Detailed step-by-step engineering build guides and subsystem trade-off studies have been authored for each configuration:

* 🥇 **[Timeline 1: "The Rapid Racer" Full Plan](docs/TIMELINE_1_RAPID_RACER.md)**  
  *1x A2212 1400KV + 1x 80A Airplane ESC + 2-Channel Relay + Solid Live Axle.*  
  **3–5 Days • ₹1,880 incremental hardware spend • ~585g featherweight.**  
  *Uses the exact parts confirmed on the vendor's shelf today!*

* 🚀 **[Timeline 2: "The Twin-Engine Brute" Full Plan](docs/TIMELINE_2_TWIN_BRUTE.md)**  
  *2x A2212 1400KV + 2x SimonK 30A ESCs + 4-Channel Relay + Common Solid Live Axle.*  
  **7–9 Days • ₹4,110 incremental spend • ~360W peak drag-strip power.**

* ⚡ **[Timeline 3: "The Vector Kart" Full Plan](docs/TIMELINE_3_VECTOR_KART.md)**  
  *2x A2212 1400KV + 2x SimonK 30A ESCs + Split Stub Axles + ESP32-S3 Torque Vectoring.*  
  **10–14 Days • ₹4,325 incremental spend • Active electronic differential & zero-radius barrier tank spin.**

* 🔬 **[Subsystem Options & Trade-Off Study (Pros & Cons)](docs/SUBSYSTEM_OPTIONS_PROS_CONS.md)**  
  *Deep-dive analysis of chassis materials (Aluminum vs FR4 vs PETG), transmissions (GT2 belt vs spur gears), axles, reverse relays, and front caster jacking.*

* 📊 **[Master Comparison Matrix & Strategy Guide](docs/MASTER_TIMELINE_COMPARISON.md)**  
  *Side-by-side engineering matrix, full financial breakdown in ₹ INR, and race strategy verdict.*

---

## 📸 3D CAD Renders & Visual Blueprints

### 1. Pure Competition Go-Kart Architecture
*Authentic perimeter tubular frame, side nerf bars, side-mounted motor, central bucket seat, and 8mm exposed live axle.*

![Pure Kart 3D Render](pure_kart_render.jpg)
*Vector Blueprint available at: [`pure_kart_blueprint.svg`](pure_kart_blueprint.svg)*

### 2. Alternative F1 Floating Pod Suspension
*T-Bar flex pivot with central 55mm coil-over pitch damper.*

![F1 Pod 3D Render](rc_chassis_render.jpg)
*Vector Blueprint available at: [`chassis_blueprint.svg`](chassis_blueprint.svg)*

---

## 🏆 Official Rulebook Compliance (Team Oorja Division B)

*Source: [`F1 RC Rulebook1.pdf`](F1%20RC%20Rulebook1.pdf)*

| Rulebook Requirement | Official Rule | Engineering Implementation |
| :--- | :--- | :--- |
| **Max Battery Voltage** | **$\le$ 8.4 V fully charged** (Rule 3.2.1) | A3SD **2S 2200mAh 80C LiPo** (7.4V nominal / 8.40V peak). 3S is strictly prohibited. |
| **Track Surface** | **Redstone outdoor tiles with 2–5 mm gaps** | Ground clearance set to **15 mm** (exceeds 12mm rule) with **65 mm** rubber slicks. |
| **Automatic Failsafe** | **Mandatory** (Rule 3.3.6) | ESP32-S3 firmware enforces immediate 1000 µs cutoff if transmitter/packet signal drops >200ms. |
| **Guarded Rotators** | **Mandatory** (Rule 3.1.4) | Outrunner motor and belt transmission enclosed within side nerf bar boundary. |
| **Recovery Rules** | **No self-recovery** (Rule 10.1) | Dual-relay electronic reverse phase-swapper implemented to unstick from barriers in 1 second. |

---

## ⚙️ The 3 Build Timelines & Powertrain Options

```mermaid
graph TD
    subgraph Timeline 1: The Rapid Racer (Recommended Winner)
        T1_M[1x A2212 1400KV] --> T1_ESC[1x 80A Airplane ESC]
        T1_ESC --> T1_R[2-Channel Relay Module]
        T1_R --> T1_S[Solid 8mm Steel Live Axle]
        T1_S --> T1_W[Locked Rear Wheels]
    end

    subgraph Timeline 2: The Twin-Engine Brute
        T2_M1[A2212 Motor 1] --> T2_S[Common 8mm Solid Axle]
        T2_M2[A2212 Motor 2] --> T2_S
        T2_ESC1[SimonK 30A ESC 1] --> T2_M1
        T2_ESC2[SimonK 30A ESC 2] --> T2_M2
        T2_R[4-Channel Relay Module] --> T2_ESC1
        T2_R --> T2_ESC2
    end

    subgraph Timeline 3: The Vector Kart
        T3_ML[Left A2212] --> T3_SL[Left Stub Axle] --> T3_WL[Left Wheel]
        T3_MR[Right A2212] --> T3_SR[Right Stub Axle] --> T3_WR[Right Wheel]
        T3_ESP[ESP32-S3 Torque Vectoring] --> T3_ESC1[Left 30A ESC]
        T3_ESP --> T3_ESC2[Right 30A ESC]
        T3_R[4-Channel Relay Module] --> T3_ML
        T3_R --> T3_MR
    end
```

### Master Comparison Table (All Prices in ₹ INR)

| Metric | Timeline 1: Single A2212 + 80A ESC *(Recommended)* | Timeline 2: Dual A2212 + 2x 30A ESCs (Solid Shaft) | Timeline 3: Dual A2212 Individual Drive (Vectoring) |
| :--- | :--- | :--- | :--- |
| **Powertrain Setup** | 1x A2212 1400KV + 1x 80A ESC | 2x A2212 1400KV + 2x 30A ESCs | 2x A2212 1400KV + 2x 30A ESCs |
| **Rear Drive Style** | Single Solid 8mm Live Axle (Shaft 1) | Ganged to 1 Solid 8mm Axle (Shaft 2) | Split Stub Axles (Independent 3) |
| **Incremental Cost (₹)**| **₹1,880 (Lowest Cost)** | **₹4,110** | **₹4,325** |
| **Total with Battery (₹)**| **₹4,270** | **₹5,210** | **₹5,375** |
| **Build Time & Complexity** | **🟢 3 – 5 Days (Fastest & Simplest)** | **🟡 7 – 9 Days** | **🔴 10 – 14 Days (Complex Code)** |
| **Electronics Weight** | **~140 g (Nimble & Featherweight)** | **~340 g (+200g heavy penalty)** | **~360 g** |
| **Cornering in 1.0m Hairpins**| ⭐⭐⭐⭐☆ Very agile; lifts inside wheel | ⭐⭐⭐☆☆ Pushes wide unless caster is high | ⭐⭐⭐⭐⭐ **Rotates on a dime via Vectoring** |
| **Relay Vibration Failure Risk**| **Lowest (Only 2 relay contacts)** | **High (4 relay contacts over tiles)**| **High (4 relay contacts over tiles)** |
| **Battery Life (2S 2200mAh)** | **~16 – 18 minutes (Full race + warmup)** | **~8 – 10 minutes** | **~9 – 11 minutes** |
| **Top Speed** | **~38.5 km/h** (~180 Watts) | **~48 – 52 km/h** (~360 Watts) | **~46 – 50 km/h** (~360 Watts) |

---

## ⚡ 80A ESC Programming Settings (For A2212 Outrunner)

Configure these exact parameters into the 80A ESC using your ESP32-S3 via [`firmware/esc_programmer.ino`](firmware/esc_programmer.ino):
1. **Cell Type**: `2S Li-Po (7.4V)` (6.0V Cutoff).
2. **Throttle Response**: `Auto Range` + `Hard Start` (explosive launch off the grid).
3. **Braking**: **`Hard Brake`** (clamps motor coils; stops motor in **<120 ms**).
4. **Direction & Cutoff**: Set direction to match gear/belt + **`Soft Cutoff`** (warning slowdown, no sudden death).
5. **Timing Mode**: **`15° (For 10–14 Pole Outrunners)`** (Mandatory for the 14-pole A2212; prevents cogging and desync).
6. **PWM Frequency**: **`16 KHz`** (Whisper-quiet, silky-smooth low-speed hairpin control).

---

## 🛡️ Race-Safe Relay Reverse Protocol

To prevent burning ESC MOSFETs or arcing relay contacts, the ESP32-S3 enforces a **Race-Safe State Machine** in [`firmware/race_kart_controller.ino`](firmware/race_kart_controller.ino):
* **During Racing**: Pushing the trigger forward engages **100% HARD BRAKES ONLY**. (Accidental reverse is physically impossible).
* **Barrier Recovery Mode**: 
  * Triggered only when stopped against a wall (via **Double-Tap** within 450ms).
  * **Sequence**: Throttle cut to 1000 µs $\to$ wait **150 ms** for motor to stop $\to$ click Relay ON $\to$ wait 50 ms $\to$ apply smooth 40% reverse power.

---

## 📁 Repository Structure

```
├── F1 RC Rulebook1.pdf               # Official Team Oorja Competition Rulebook
├── README.md                         # Master Technical Documentation & Overview
├── rc_car_dual_a2212_bom.txt         # Raw Bill of Materials & Safety Rules
├── pure_kart_render.jpg              # 3D Studio CAD Render of Pure Kart
├── rc_chassis_render.jpg             # 3D CAD Render of F1 Pod Chassis
├── pure_kart_blueprint.svg           # Vector Blueprint: Pure Go-Kart Layout
├── chassis_blueprint.svg             # Vector Blueprint: F1 Floating Pod Layout
├── firmware/
│   ├── esc_programmer.ino            # Bench ESC Programming Sketch for ESP32-S3
│   └── race_kart_controller.ino      # Race State Machine with Failsafe & Double-Tap Reverse
└── docs/
    ├── TIMELINE_1_RAPID_RACER.md     # Full Build Plan: 1x A2212 + 80A ESC + Solid Shaft
    ├── TIMELINE_2_TWIN_BRUTE.md       # Full Build Plan: 2x A2212 + 2x 30A ESCs + Solid Shaft
    ├── TIMELINE_3_VECTOR_KART.md      # Full Build Plan: 2x A2212 + Torque Vectoring
    ├── SUBSYSTEM_OPTIONS_PROS_CONS.md # Comprehensive Trade-Off Study with Pros & Cons
    └── MASTER_TIMELINE_COMPARISON.md  # Side-by-Side Matrix & Strategic Verdict
```

---

## 🏁 How to Build & Flash Firmware

1. Open `firmware/race_kart_controller.ino` in Arduino IDE or PlatformIO.
2. Select Board: **ESP32S3 Dev Module**.
3. Install Dependency: `ESP32Servo` by Kevin Harrington.
4. Pin Connections:
   * **GPIO 18**: ESC Throttle PWM.
   * **GPIO 19**: Steering Servo PWM.
   * **GPIO 21**: Relay Direction Trigger (Active LOW).
5. Compile, flash, and race!
