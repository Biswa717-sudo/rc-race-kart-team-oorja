"""
RC Kart S-Curve Ackermann Tripod Kinematic Benchmark
Chassis: Trackwidth K = 126 mm | Wheelbase L = 130 mm
Features:
- Anti-Ackermann at High-Speed Sweeper (R >= 3.0m, low steer)
- True 0% Parallel Crossover at R ~ 2.5m
- Massive Pro-Ackermann (>180% Ackermann) at 1.0m Hairpin
"""

import math
import numpy as np

def circle_intersect(C1, r1, C2, r2):
    dx = C2[0] - C1[0]
    dy = C2[1] - C1[1]
    d = math.hypot(dx, dy)
    if d > (r1 + r2) or d < abs(r1 - r2) or d == 0:
        return None
    a = (r1**2 - r2**2 + d**2) / (2.0 * d)
    h_sq = r1**2 - a**2
    if h_sq < 0:
        return None
    h = math.sqrt(h_sq)
    x2 = C1[0] + a * dx / d
    y2 = C1[1] + a * dy / d
    p1 = (x2 + h * dy / d, y2 - h * dx / d)
    p2 = (x2 - h * dy / d, y2 + h * dx / d)
    return p1, p2

def run_scurve_benchmark(
    K=126.0,            # Kingpin Trackwidth (mm)
    L=130.0,            # Wheelbase (mm)
    y_P=-30.0,          # Tripod Pivot Y (mm behind front axle)
    D_sep=44.0,         # Tripod Hole Separation (mm)
    y_T_offset=5.0,     # Tripod Hole Offset forward of pivot (+5 mm => y_T = -25 mm)
    L_arm=20.0,         # Knuckle Arm Length (mm)
    alpha_deg=25.0,     # Knuckle Arm Inward Angle (deg)
    caster_deg=14.0     # Caster Angle (deg)
):
    KL = (-K / 2.0, 0.0)
    KR = ( K / 2.0, 0.0)
    
    alpha_rad = math.radians(alpha_deg)
    JL0 = (KL[0] + L_arm * math.sin(alpha_rad), -L_arm * math.cos(alpha_rad))
    JR0 = (KR[0] - L_arm * math.sin(alpha_rad), -L_arm * math.cos(alpha_rad))
    
    x_T = D_sep / 2.0
    y_T = y_P + y_T_offset
    TL0 = (-x_T, y_T)
    TR0 = ( x_T, y_T)
    
    L_tierod = math.hypot(JL0[0] - TL0[0], JL0[1] - TL0[1])
    R_tripod = math.hypot(x_T, y_T_offset)
    
    ang_L0 = math.atan2(JL0[1] - KL[1], JL0[0] - KL[0])
    ang_R0 = math.atan2(JR0[1] - KR[1], JR0[0] - KR[0])
    
    vL0 = (TL0[0], TL0[1] - y_P)
    vR0 = (TR0[0], TR0[1] - y_P)
    
    print("=" * 78)
    print("        TEAM OORJA RC KART S-CURVE TRIPOD KINEMATIC SYNTHESIS        ")
    print("=" * 78)
    print(f"  Chassis Geometry:      Trackwidth K = {K:.1f} mm | Wheelbase L = {L:.1f} mm")
    print(f"  Tripod Pivot Position: x = 0.0 mm, y = {y_P:.1f} mm (30mm behind front axle)")
    print(f"  Tripod Hole Spread:    x = ±{x_T:.1f} mm (Total Width D_sep = {D_sep:.1f} mm)")
    print(f"  Tripod Hole Y:         y = {y_T:.1f} mm ({y_T_offset:+.1f} mm forward of pivot)")
    print(f"  Tripod Arm Radius:     R_tripod = {R_tripod:.2f} mm")
    print(f"  Knuckle Arm:           Trailing, Length = {L_arm:.1f} mm, Inward Angle = {alpha_deg:.1f}°")
    print(f"  Kingpin Ball-Joints:   Left: ({JL0[0]:.2f}, {JL0[1]:.2f}) | Right: ({JR0[0]:.2f}, {JR0[1]:.2f})")
    print(f"  Calculated Tie-Rod:    L_tierod = {L_tierod:.2f} mm (Eye-to-Eye Turnbuckle)")
    print(f"  Kingpin Caster Angle:  +14.0° (Dynamic Jacking Enabled)")
    print("-" * 78)
    print(f"{'Steer θ':>7} | {'Inside δi':>9} | {'Outside δo':>10} | {'Delta (δi-δo)':>13} | {'Ackermann %':>11} | {'Turn Radius':>11} | {'Regime'}")
    print("-" * 78)
    
    results = []
    for th_deg in np.linspace(0.5, 26.0, 52):
        th = math.radians(th_deg)
        TL = (vL0[0]*math.cos(th) - vL0[1]*math.sin(th), y_P + vL0[0]*math.sin(th) + vL0[1]*math.cos(th))
        TR = (vR0[0]*math.cos(th) - vR0[1]*math.sin(th), y_P + vR0[0]*math.sin(th) + vR0[1]*math.cos(th))
        
        cL = circle_intersect(KL, L_arm, TL, L_tierod)
        cR = circle_intersect(KR, L_arm, TR, L_tierod)
        if cL is None or cR is None:
            break
            
        pL1, pL2 = cL
        JL = pL1 if math.hypot(pL1[0]-JL0[0], pL1[1]-JL0[1]) < math.hypot(pL2[0]-JL0[0], pL2[1]-JL0[1]) else pL2
        pR1, pR2 = cR
        JR = pR1 if math.hypot(pR1[0]-JR0[0], pR1[1]-JR0[1]) < math.hypot(pR2[0]-JR0[0], pR2[1]-JR0[1]) else pR2
        
        dL = math.degrees(math.atan2(JL[1]-KL[1], JL[0]-KL[0]) - ang_L0)
        dR = math.degrees(math.atan2(JR[1]-KR[1], JR[0]-KR[0]) - ang_R0)
        
        inside = abs(dL)
        outside = abs(dR)
        diff = inside - outside
        
        tan_i = math.tan(math.radians(inside))
        if tan_i > 0:
            ideal_o = math.degrees(math.atan((L * tan_i) / (L + K * tan_i)))
            R_turn_m = (K / 2.0 + L / tan_i) / 1000.0
        else:
            ideal_o = 0.0
            R_turn_m = 999.0
            
        diff_id = inside - ideal_o
        ack_pct = (diff / diff_id * 100.0) if abs(diff_id) > 0.001 else 100.0
        
        # Chassis inside rear wheel lift via caster jacking (mm)
        # Jacking lift = (K/2) * sin(caster) * sin(inside)
        wheel_lift_mm = (K / 2.0) * math.sin(math.radians(caster_deg)) * math.sin(math.radians(inside))
        
        results.append({
            'theta': th_deg,
            'inside': inside,
            'outside': outside,
            'diff': diff,
            'ideal_o': ideal_o,
            'ack_pct': ack_pct,
            'R_turn_m': R_turn_m,
            'wheel_lift_mm': wheel_lift_mm
        })
        
    # Print clean selected telemetry
    sample_angles = [2.0, 5.0, 8.0, 11.0, 14.0, 17.0, 20.0, 23.0]
    for sa in sample_angles:
        p = min(results, key=lambda x: abs(x['theta'] - sa))
        if p['diff'] < -0.01:
            regime = "ANTI-ACKERMANN (Sweeper Grip)"
        elif abs(p['diff']) <= 0.02:
            regime = "PARALLEL CROSSOVER (0% Ack)"
        elif p['ack_pct'] < 120.0:
            regime = "PRO-ACKERMANN (Transition)"
        else:
            regime = f"SUPER ACKERMANN (+{p['wheel_lift_mm']:.1f}mm Lift)"
            
        print(f"{p['theta']:6.1f}° | {p['inside']:8.2f}° | {p['outside']:9.2f}° | {p['diff']:+12.2f}° | {p['ack_pct']:+10.1f}% | {p['R_turn_m']:9.2f} m | {regime}")
        
    print("=" * 78)
    return results

if __name__ == '__main__':
    run_scurve_benchmark()
