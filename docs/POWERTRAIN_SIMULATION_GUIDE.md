# RC Kart Powertrain & GT2 Drivetrain Comprehensive Simulation Guide
**Target Total Vehicle Mass:** 600 grams (0.60 kg) • **Power Source:** 2S LiPo (8.4V Peak / 7.4V Nominal)
**Motors Analyzed:** A2212 1400KV vs. A2212 1000KV • **Transmission:** GT2 Synchronous Timing Belt

---

## 1. Executive Summary & Physics Overview

At a lightweight **600-gram curb mass** on the **Team Oorja 7.0-meter straightaway**, the powertrain dynamics shift dramatically from being motor-power limited to **traction-limited**:

```
                       7.0-METER TRACK STRAIGHTAWAY SPRINT
 0.0m (Standing Launch) ────────────────────────────────────────► 7.0m (Hairpin Turn-In)
 [Peak Stall Torque]       [Traction Grip Limit Zone]            [Terminal Exit Velocity]
  • 1400KV: 0.481 N·m       • Max Normal Force: 3.82 N           • 1400KV (4:1): 27.8 km/h
  • 1000KV: 0.537 N·m       • Max Tire Grip (μ=0.95): 3.63 N     • 1000KV (3:1): 28.4 km/h
```

### Key Simulation Findings at 600g Mass:
1. **The Traction Limit (3.63 N)**:
   * Rear axle static + dynamic weight transfer places **~65% of the vehicle mass** over the rear wheels ($W_{\text{rear}} = 0.60\text{ kg} \times 9.81 \times 0.65 = 3.82\text{ N}$).
   * On clean outdoor redstone tiles ($\mu_{\text{tire}} \approx 0.95$), the maximum tractive force the 65mm tires can transmit without burning out is:
     $$F_{\text{grip\_max}} = \mu \times W_{\text{rear}} = 0.95 \times 3.82\text{ N} = \mathbf{3.63\text{ Newtons}}$$
2. **Timeline 1 (1x Motor) vs. Timeline 2 & 3 (2x Motors)**:
   * **Timeline 1 (Single Motor)**: Delivers ~3.9 N of peak driving force at launch. It barely grazes the traction limit, hooking up immediately with minimal wheelspin and rocketing to 27.8 km/h in **1.72 seconds**.
   * **Timeline 2 & 3 (Dual Motors)**: Delivers ~7.8 N of peak driving force—more than **200% of the tire's physical grip limit**! Unless progressive throttle expo or torque-limiting is applied in firmware, full-throttle launch simply produces a tire burnout on the tiles.

---

## 2. A2212 1400KV vs. A2212 1000KV Head-to-Head Comparison

| Motor Parameter | A2212 1400KV (High-RPM Spec) | A2212 1000KV (High-Torque Spec) | Engineering Impact |
| :--- | :---: | :---: | :--- |
| **KV Rating** | 1400 RPM/V | 1000 RPM/V | 1000KV turns 28.5% fewer RPM per volt |
| **No-Load RPM (8.4V Peak)** | 11,760 RPM | 8,400 RPM | 1400KV needs steeper gear reduction |
| **Torque Constant ($K_t$)** | $0.00682\text{ N}\cdot\text{m/A}$ | $\mathbf{0.00955\text{ N}\cdot\text{m/A}}$ | **1000KV produces +40% more torque per Amp!** |
| **Winding Resistance ($R_m$)**| $0.100\ \Omega$ | $0.130\ \Omega$ | 1000KV has more turns of finer copper wire |
| **No-Load Current ($I_0$)** | 0.70 A | 0.50 A | 1000KV has lower idle magnetic core losses |
| **Optimal GT2 Gearing** | **16T : 64T (4.0:1)** | **20T : 60T (3.0:1)** | 1000KV uses a larger pinion with more teeth! |
| **0–7m Sprint Time (T1, 600g)**| **1.722 seconds** | **1.684 seconds (WINNER 🏆)** | **1000KV with 3:1 is 0.038s faster to 7m!** |
| **7m Exit Velocity** | 27.8 km/h | 28.4 km/h | 1000KV exits the straight slightly faster |
| **Top Terminal Speed** | 34.4 km/h | 32.8 km/h | 1400KV has higher theoretical top speed |
| **Peak Current Burst** | 71.2 Amps | **56.8 Amps (WINNER 🏆)** | **1000KV pulls 20% less peak current!** |
| **Thermal Operating Temp** | Runs warm (~55°C) | **Runs cold (~38°C)** | 1000KV generates far less $I^2 R$ heat |
| **Battery Life (2S 2200mAh)**| ~15 minutes | **~19 minutes (WINNER 🏆)** | +26% longer race endurance |

---

## 3. GT2 Timing Belt Pulley Mechanics & Tooth Skipping Analysis

A critical discovery of this simulation is the interaction between **pinion tooth count ($Z_1$)** and **belt ratcheting (tooth skipping)**:

```
               GT2 BELT ENGAGEMENT WITH 623ZZ IDLER SNUBBER
                    ┌─────────────┐
                    │ A2212 Motor │
                    └──────┬──────┘
                           │
                 [Z1 Pinion Pulley] ◄── 16T or 20T
                           │\
     Tight Driving Span    │ \  ◄── 623ZZ Ball Bearing Idler Snubber
      (Tangential Pull)    │  \     (Expands wrap angle from 144° to 210°!)
                           │   \
                           │    \  Slack Return Span
                           │     \
                           │      \
                     [Z2 Axle Pulley] ◄── 60T or 64T
                           │
               [8mm Precision Solid Axle]
```

### Belt Mechanics Breakdown:

| Gearing Setup | Motor KV | Pinion $Z_1$ | Spur $Z_2$ | Ratio | Wrap Angle | Teeth in Mesh (TIM) | Tooth Shear Force ($F_t$) | Safety Factor (SF) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Standard Baseline** | 1400KV | 16T | 64T | 4.0:1 | 144.4° (No Idler) | 6.4 teeth | 35.3 N | **2.00x** (Baseline) |
| **Snubber Enhanced** | 1400KV | 16T | 64T | 4.0:1 | 210.0° (With Idler)| 9.3 teeth | 35.3 N | **2.90x** (+45% Safer) |
| **1000KV Optimized** | 1000KV | 20T | 60T | 3.0:1 | 215.0° (With Idler)| **11.9 teeth** | 32.1 N | **4.08x (BULLETPROOF 🏆)** |

> [!TIP]
> **Why 1000KV + 20T:60T Gearing is Mechanically Superior:**
> By switching to the 1000KV motor with a larger **20T motor pinion**, the pitch diameter grows from $10.19\text{ mm}$ to $12.73\text{ mm}$. This increases the number of teeth simultaneously engaged from 9.3 to nearly 12 teeth, pushing the **belt skipping safety factor to over 4.0x**! Tooth ratcheting becomes virtually impossible even under violent full-throttle launches or 100% hard braking.

---

## 4. Master Simulation Performance Matrix Across All 3 Timelines (600g Mass)

### At 1400 KV (16T:64T, 4.0:1 Ratio):
| Metric | Timeline 1: Single A2212 + 80A ESC | Timeline 2: Dual A2212 + Solid Axle | Timeline 3: Dual A2212 + Vector Stubs |
| :--- | :---: | :---: | :---: |
| **Total Mass** | 600 grams | 600 grams | 600 grams |
| **0–7m Sprint Time** | **1.722 seconds** | 1.837 seconds (Wheelspin) | 1.837 seconds (Wheelspin) |
| **Exit Speed at 7m** | **27.8 km/h** | 26.1 km/h | 26.1 km/h |
| **Top Terminal Speed**| 34.4 km/h | 35.0 km/h | 34.8 km/h |
| **Peak Battery Current**| 71.2 Amps | 80.0 Amps | 120.0 Amps (Burst) |
| **Belt Tooth Safety SF**| 2.90x | 5.80x (Dual Belts share load) | 5.80x (Dual Belts share load) |
| **Hairpin Turning Drag**| Lifts inside wheel via 14° Caster | Lifts inside wheel via 14° Caster | **0% Drag (Torque Vectoring)** |

### At 1000 KV (20T:60T, 3.0:1 Ratio):
| Metric | Timeline 1: Single A2212 + 80A ESC | Timeline 2: Dual A2212 + Solid Axle | Timeline 3: Dual A2212 + Vector Stubs |
| :--- | :---: | :---: | :---: |
| **Total Mass** | 600 grams | 600 grams | 600 grams |
| **0–7m Sprint Time** | **1.684 seconds (FASTEST 🏆)** | 1.695 seconds | 1.731 seconds |
| **Exit Speed at 7m** | **28.4 km/h** | 28.6 km/h | 28.0 km/h |
| **Top Terminal Speed**| 32.8 km/h | 33.4 km/h | 33.6 km/h |
| **Peak Battery Current**| **56.8 Amps (Lowest Heat 🏆)**| 80.0 Amps | 120.0 Amps |
| **Belt Tooth Safety SF**| **4.08x (Indestructible 🏆)** | 8.16x | 8.16x |

---

## 5. Running the Simulation Applications

### A. In Python (Instant Launch):
```powershell
python "D:\rc car\rc_kart_powertrain_simulator.py"
```
* Click `[1400 KV (4:1)]` or `[1000 KV (3:1)]` on top to switch presets instantly.
* Click `[Compare Both KV]` to overlay 1400KV and 1000KV on the same sprint and torque graphs.
* Adjust mass, gearing, center distance, and belt width live at 60 FPS.

### B. In MATLAB:
```matlab
rc_kart_powertrain_simulator
```
Runs the native MATLAB GUI app with continuous event listeners.
