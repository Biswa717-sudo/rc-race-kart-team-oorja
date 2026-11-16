"""
RC Kart Modified 4-Bar Tripod-Plate Steering Kinematics & Ackermann Analyzer
Team Oorja F1 RC Race (Division B)

INSTANTANEOUS 60+ FPS REAL-TIME EDITION
Features:
- 12 Interactive Sliders:
  1. Kingpin Distance (K)
  2. Wheelbase (L)
  3. Tripod Arc Radius (R_tripod)
  4. Tripod Points Separation (D_sep)
  5. Tripod Pivot Y-Offset (y_P)
  6. Tie-Rod Length (L_tierod)
  7. Control Arm Inward Angle (alpha_arm)
  8. Control Arm Length (L_arm)
  9. Kingpin Caster Angle (theta_caster) -> Real-time Dynamic Jacking & Camber Gain!
  10. Kingpin Inclination KPI (theta_kpi)
  11. Wheel Scrub Offset (W_scrub)
  12. Live Tripod Steer Input (theta_tripod)
- 4 High-Speed Real-time Analytical Graphs:
  1. 2D Kinematic Top-View (Tires with Scrub Offset, Spindle Axles, Arms, Tie-Rods, Tripod, Instant Center)
  2. Inner Angle vs. Outer Angle (Actual Mechanism vs. 100% Ideal Ackermann vs. Parallel)
  3. Ackermann Percentage (%) vs. Inner Steering Angle
  4. Instantaneous Intersection Distance (|y_int|) vs. Inner Steering Angle
- Live Telemetry HUD with Dynamic Chassis Jacking (Inside Rear Wheel Lift in mm)
"""

import math
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.widgets import Slider, Button
from matplotlib.patches import Polygon

# =============================================================================
# DEFAULT BASELINE DIMENSIONS (mm and degrees)
# =============================================================================
DEFAULT_K             = 150.0  # Kingpin Distance (mm)
DEFAULT_L             = 255.0  # Wheelbase (mm)
DEFAULT_R_TRIPOD      = 25.0   # Tripod Arc Radius (mm)
DEFAULT_D_SEP         = 22.0   # Tripod Points Separation (mm)
DEFAULT_Y_P           = -25.0  # Tripod Pivot Y-Offset (mm)
DEFAULT_L_ARM         = 22.0   # Control Arm Length (mm)
DEFAULT_ALPHA_DEG     = 16.0   # Control Arm Inward Angle (deg)
DEFAULT_CASTER_DEG    = 14.0   # Kingpin Caster Angle (deg)
DEFAULT_KPI_DEG       = 6.0    # Kingpin Inclination KPI (deg)
DEFAULT_SCRUB_MM      = 18.0   # Wheel Centerline Scrub Offset (mm)
DEFAULT_STEER_DEG     = 12.0   # Live Tripod Steer Input (deg)
TIRE_DIA              = 65.0   # Tire diameter (mm)
TIRE_WIDTH            = 26.0   # Tire width (mm)

def compute_neutral_tierod(K, R_tripod, D_sep, L_arm, alpha_deg, y_P):
    D_sep = min(D_sep, 2.0 * R_tripod - 0.5)
    phi0 = math.asin((D_sep / 2.0) / R_tripod)
    x_TL0 = -R_tripod * math.sin(phi0)
    y_TL0 = y_P - R_tripod * math.cos(phi0)
    alpha_rad = math.radians(alpha_deg)
    x_JL0 = -K / 2.0 + L_arm * math.sin(alpha_rad)
    y_JL0 = -L_arm * math.cos(alpha_rad)
    return math.hypot(x_JL0 - x_TL0, y_JL0 - y_TL0)

DEFAULT_L_TIEROD = compute_neutral_tierod(
    DEFAULT_K, DEFAULT_R_TRIPOD, DEFAULT_D_SEP, DEFAULT_L_ARM, DEFAULT_ALPHA_DEG, DEFAULT_Y_P
)

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
    return p1 if p1[1] < p2[1] else p2

def solve_kinematics(K, L, R_tripod, D_sep, L_tierod, alpha_deg, L_arm, y_P, th_range_deg):
    D_sep = min(D_sep, 2.0 * R_tripod - 0.5)
    phi0 = math.asin((D_sep / 2.0) / R_tripod)
    KL = (-K / 2.0, 0.0)
    KR = ( K / 2.0, 0.0)
    alpha_rad = math.radians(alpha_deg)

    JL0_ref = (KL[0] + L_arm * math.sin(alpha_rad), KL[1] - L_arm * math.cos(alpha_rad))
    JR0_ref = (KR[0] - L_arm * math.sin(alpha_rad), KR[1] - L_arm * math.cos(alpha_rad))
    ang_L0  = math.atan2(JL0_ref[1] - KL[1], JL0_ref[0] - KL[0])
    ang_R0  = math.atan2(JR0_ref[1] - KR[1], JR0_ref[0] - KR[0])

    inner_arr = []
    outer_arr = []
    ideal_arr = []
    ack_pct_arr = []
    y_int_arr = []

    for th_deg in th_range_deg:
        th_rad = math.radians(th_deg)
        TL = (-R_tripod * math.sin(phi0 - th_rad), y_P - R_tripod * math.cos(phi0 - th_rad))
        TR = ( R_tripod * math.sin(phi0 + th_rad), y_P - R_tripod * math.cos(phi0 + th_rad))

        JL = circle_intersect(KL, L_arm, TL, L_tierod)
        JR = circle_intersect(KR, L_arm, TR, L_tierod)

        if JL is not None and JR is not None:
            ang_L = math.atan2(JL[1] - KL[1], JL[0] - KL[0])
            ang_R = math.atan2(JR[1] - KR[1], JR[0] - KR[0])
            dL = math.degrees(ang_L - ang_L0)
            dR = math.degrees(ang_R - ang_R0)

            if dL >= 0:
                inner = dL
                outer = dR
            else:
                inner = abs(dR)
                outer = abs(dL)

            tan_inn = math.tan(math.radians(inner))
            if tan_inn > 0:
                ideal_out = math.degrees(math.atan((L * tan_inn) / (L + K * tan_inn)))
            else:
                ideal_out = 0.0

            diff_id = inner - ideal_out
            ack_pct = ((inner - outer) / diff_id) * 100.0 if abs(diff_id) > 0.05 else 100.0

            if abs(dL) > 0.05 and abs(dR) > 0.05:
                c_L = 1.0 / math.tan(math.radians(dL))
                c_R = 1.0 / math.tan(math.radians(dR))
                denom = c_R - c_L
                y_int = -K / denom if abs(denom) > 1e-4 else float('nan')
            else:
                y_int = float('nan')

            inner_arr.append(inner)
            outer_arr.append(outer)
            ideal_arr.append(ideal_out)
            ack_pct_arr.append(ack_pct)
            y_int_arr.append(y_int)

    return (np.array(inner_arr), np.array(outer_arr), np.array(ideal_arr),
            np.array(ack_pct_arr), np.array(y_int_arr))

# =============================================================================
# GUI SETUP WITH 12 EXPANDED SLIDERS
# =============================================================================
fig = plt.figure(figsize=(18, 9.6), facecolor='#121316')
fig.canvas.manager.set_window_title('RC Kart Tripod Steering Kinematics & Dynamic Jacking (Instantaneous 60FPS)')

# 4 Plot Axes
ax_mech = fig.add_axes([0.31, 0.54, 0.32, 0.40], facecolor='#16181D')
ax_ang  = fig.add_axes([0.68, 0.54, 0.29, 0.40], facecolor='#16181D')
ax_pct  = fig.add_axes([0.31, 0.08, 0.32, 0.38], facecolor='#16181D')
ax_int  = fig.add_axes([0.68, 0.08, 0.29, 0.38], facecolor='#16181D')

slider_color = '#00B4D8'
ax_bg        = '#22252C'

sliders = {}
slider_params = [
    ('Kingpin Distance (K)',          110,  200, DEFAULT_K,          'K',             '%.1f mm'),
    ('Wheelbase (L)',                 200,  350, DEFAULT_L,          'L',             '%.1f mm'),
    ('Tripod Arc Radius (R)',          12,   45, DEFAULT_R_TRIPOD,   'R_tripod',      '%.1f mm'),
    ('Tripod Points Sep (D_sep)',       6,   40, DEFAULT_D_SEP,      'D_sep',         '%.1f mm'),
    ('Tripod Pivot Y-Offset (y_P)',   -55,   15, DEFAULT_Y_P,        'y_P',           '%.1f mm'),
    ('Tie-Rod Length (L_tr)',          40,   95, DEFAULT_L_TIEROD,   'L_tierod',      '%.2f mm'),
    ('Control Arm Angle (alpha)',       0,   35, DEFAULT_ALPHA_DEG,  'alpha_arm_deg', '%.1f deg'),
    ('Control Arm Length (L_arm)',     12,   40, DEFAULT_L_ARM,      'L_arm',         '%.1f mm'),
    ('Caster Angle (theta_c)',          0,   22, DEFAULT_CASTER_DEG, 'caster_deg',    '%.1f deg'),
    ('Kingpin Inclination (KPI)',       0,   16, DEFAULT_KPI_DEG,    'kpi_deg',       '%.1f deg'),
    ('Wheel Scrub Offset (W_scrub)',    8,   35, DEFAULT_SCRUB_MM,   'scrub_mm',      '%.1f mm'),
    ('Live Tripod Steer Input',       -30,   30, DEFAULT_STEER_DEG,  'steer_input',   '%.1f deg')
]

y_pos = 0.935
for name, s_min, s_max, s_init, tag, val_fmt in slider_params:
    ax_s = fig.add_axes([0.02, y_pos, 0.25, 0.018], facecolor=ax_bg)
    s = Slider(ax_s, name, s_min, s_max, valinit=s_init, color=slider_color)
    s.label.set_color('#E0E0E0')
    s.label.set_fontsize(8.5)
    s.valtext.set_color('#00E5FF')
    s.valtext.set_fontsize(8.5)
    sliders[tag] = s
    y_pos -= 0.046

# Action Buttons
ax_btn_zero = fig.add_axes([0.02, 0.355, 0.12, 0.028], facecolor='#2B9348')
btn_zero = Button(ax_btn_zero, 'Auto-Zero Toe Length', color='#2B9348', hovercolor='#55A630')
btn_zero.label.set_color('white')
btn_zero.label.set_fontsize(8.0)
btn_zero.label.set_weight('bold')

ax_btn_reset = fig.add_axes([0.15, 0.355, 0.12, 0.028], facecolor='#D90429')
btn_reset = Button(ax_btn_reset, 'Reset to Baseline', color='#D90429', hovercolor='#EF233C')
btn_reset.label.set_color('white')
btn_reset.label.set_fontsize(8.0)
btn_reset.label.set_weight('bold')

# Telemetry Display Box
ax_telemetry = fig.add_axes([0.02, 0.018, 0.25, 0.325], facecolor='#090A0D')
ax_telemetry.axis('off')
telemetry_txt = ax_telemetry.text(0.04, 0.96, '', color='#38B000', fontsize=8.0,
                                  fontfamily='monospace', va='top')

fig.text(0.145, 0.968, 'EXPANDED GEOMETRY SLIDERS', color='#00E5FF',
         fontsize=11, fontweight='bold', ha='center')

def draw_tire(ax, center, steer_deg, dia, width, color):
    theta = math.radians(steer_deg)
    bx = np.array([-width/2, width/2, width/2, -width/2])
    by = np.array([-dia/2, -dia/2, dia/2, dia/2])
    rot_x = bx * math.cos(theta) - by * math.sin(theta) + center[0]
    rot_y = bx * math.sin(theta) + by * math.cos(theta) + center[1]
    poly = Polygon(np.column_stack([rot_x, rot_y]), closed=True,
                   facecolor=color, edgecolor='black', alpha=0.85, zorder=4)
    ax.add_patch(poly)

def update(val=None):
    K         = sliders['K'].val
    L         = sliders['L'].val
    R_tripod  = sliders['R_tripod'].val
    D_sep     = sliders['D_sep'].val
    y_P       = sliders['y_P'].val
    L_tierod  = sliders['L_tierod'].val
    alpha_deg = sliders['alpha_arm_deg'].val
    L_arm     = sliders['L_arm'].val
    caster_d  = sliders['caster_deg'].val
    kpi_d     = sliders['kpi_deg'].val
    scrub_w   = sliders['scrub_mm'].val
    th_steer  = sliders['steer_input'].val

    if D_sep >= 2.0 * R_tripod:
        D_sep = 2.0 * R_tripod - 0.5
        sliders['D_sep'].set_val(D_sep)

    phi0 = math.asin((D_sep / 2.0) / R_tripod)
    KL = (-K / 2.0, 0.0)
    KR = ( K / 2.0, 0.0)
    alpha_rad = math.radians(alpha_deg)

    JL0_ref = (KL[0] + L_arm * math.sin(alpha_rad), KL[1] - L_arm * math.cos(alpha_rad))
    JR0_ref = (KR[0] - L_arm * math.sin(alpha_rad), KR[1] - L_arm * math.cos(alpha_rad))
    ang_L0  = math.atan2(JL0_ref[1] - KL[1], JL0_ref[0] - KL[0])
    ang_R0  = math.atan2(JR0_ref[1] - KR[1], JR0_ref[0] - KR[0])

    # Sweep kinematics
    th_sweep = np.linspace(0.1, 26.0, 160)
    inner_s, outer_s, ideal_s, ack_pct_s, y_int_s = solve_kinematics(
        K, L, R_tripod, D_sep, L_tierod, alpha_deg, L_arm, y_P, th_sweep
    )

    # Live point evaluation
    th_live_rad = math.radians(th_steer)
    TL_live = (-R_tripod * math.sin(phi0 - th_live_rad), y_P - R_tripod * math.cos(phi0 - th_live_rad))
    TR_live = ( R_tripod * math.sin(phi0 + th_live_rad), y_P - R_tripod * math.cos(phi0 + th_live_rad))
    JL_live = circle_intersect(KL, L_arm, TL_live, L_tierod)
    JR_live = circle_intersect(KR, L_arm, TR_live, L_tierod)

    valid_geom = (JL_live is not None and JR_live is not None)
    if valid_geom:
        dL_live = math.degrees(math.atan2(JL_live[1] - KL[1], JL_live[0] - KL[0]) - ang_L0)
        dR_live = math.degrees(math.atan2(JR_live[1] - KR[1], JR_live[0] - KR[0]) - ang_R0)
    else:
        dL_live, dR_live = 0.0, 0.0

    if dL_live >= 0:
        live_inner = dL_live
        live_outer = dR_live
        is_turn_left = True
    else:
        live_inner = abs(dR_live)
        live_outer = abs(dL_live)
        is_turn_left = False

    tan_inn = math.tan(math.radians(live_inner))
    live_ideal_outer = math.degrees(math.atan((L * tan_inn) / (L + K * tan_inn))) if tan_inn > 0 else 0.0
    diff_id = live_inner - live_ideal_outer
    live_ack_pct = ((live_inner - live_outer) / diff_id) * 100.0 if abs(diff_id) > 0.05 else 100.0

    if abs(dL_live) > 0.1 and abs(dR_live) > 0.1:
        c_L = 1.0 / math.tan(math.radians(dL_live))
        c_R = 1.0 / math.tan(math.radians(dR_live))
        denom = c_R - c_L
        if abs(denom) > 1e-4:
            live_x_int = (K / 2.0) * (c_R + c_L) / denom
            live_y_int = -K / denom
        else:
            live_x_int, live_y_int = float('nan'), float('nan')
    else:
        live_x_int, live_y_int = float('nan'), float('nan')

    # Dynamic Chassis Jacking (Inside Rear Wheel Lift):
    caster_rad = math.radians(caster_d)
    jacking_lift_mm = scrub_w * math.sin(caster_rad) * math.sin(math.radians(live_inner))
    camber_gain_deg = -live_outer * math.sin(caster_rad)

    # =========================================================================
    # PLOT 1: 2D KINEMATICS TOP VIEW (WITH WHEEL SCRUB & SPINDLES)
    # =========================================================================
    ax_mech.cla()
    ax_mech.grid(True, color='#282C34', linestyle='--', linewidth=0.7)
    ax_mech.plot([KL[0], KR[0]], [KL[1], KR[1]], color='white', linewidth=2.5, zorder=2)
    ax_mech.scatter([KL[0], KR[0]], [KL[1], KR[1]], color='#00F5D4', s=70, zorder=3)

    # Tripod Plate
    ax_mech.scatter(0, y_P, color='#FFD166', marker='^', s=90, zorder=3)
    tripod_pts = np.array([[0, y_P], [TL_live[0], TL_live[1]], [TR_live[0], TR_live[1]]])
    ax_mech.add_patch(Polygon(tripod_pts, closed=True, facecolor='#FFD166', alpha=0.35,
                              edgecolor='#FFD166', linewidth=1.5, zorder=2))
    ax_mech.scatter([TL_live[0], TR_live[0]], [TL_live[1], TR_live[1]], color='#F77F00', s=45, zorder=3)

    if valid_geom:
        # Control arms & tie-rods
        ax_mech.plot([KL[0], JL_live[0]], [KL[1], JL_live[1]], color='#EF233C', linewidth=3, zorder=3)
        ax_mech.plot([KR[0], JR_live[0]], [KR[1], JR_live[1]], color='#EF233C', linewidth=3, zorder=3)
        ax_mech.scatter([JL_live[0], JR_live[0]], [JL_live[1], JR_live[1]], color='#EF233C', s=50, zorder=4)

        ax_mech.plot([TL_live[0], JL_live[0]], [TL_live[1], JL_live[1]], color='#52B788', linewidth=2.5, zorder=3)
        ax_mech.plot([TR_live[0], JR_live[0]], [TR_live[1], JR_live[1]], color='#52B788', linewidth=2.5, zorder=3)

        # Wheel Centers with scrub radius
        wh_L = (KL[0] - scrub_w * math.cos(math.radians(dL_live)), KL[1] - scrub_w * math.sin(math.radians(dL_live)))
        wh_R = (KR[0] + scrub_w * math.cos(math.radians(dR_live)), KR[1] - scrub_w * math.sin(math.radians(dR_live)))

        draw_tire(ax_mech, wh_L, dL_live, TIRE_DIA, TIRE_WIDTH, '#00B4D8')
        draw_tire(ax_mech, wh_R, dR_live, TIRE_DIA, TIRE_WIDTH, '#00B4D8')

        # Spindle stub axle lines
        ax_mech.plot([KL[0], wh_L[0]], [KL[1], wh_L[1]], color='#00E5FF', linewidth=2)
        ax_mech.plot([KR[0], wh_R[0]], [KR[1], wh_R[1]], color='#00E5FF', linewidth=2)

        # Intersection lines
        if not math.isnan(live_x_int) and not math.isnan(live_y_int) and abs(live_y_int) < 1400:
            ax_mech.plot([wh_L[0], live_x_int], [wh_L[1], live_y_int], color='#FF006E', linestyle='--', linewidth=1.2)
            ax_mech.plot([wh_R[0], live_x_int], [wh_R[1], live_y_int], color='#FF006E', linestyle='--', linewidth=1.2)
            ax_mech.scatter(live_x_int, live_y_int, color='#FF006E', marker='*', s=140, zorder=5)

    # Rear Axle Line
    ax_mech.axhline(-L, color='#00F5D4', linestyle='-.', linewidth=1.5)
    ax_mech.text(-K * 0.9, -L + 8, f'Rear Axle Target Line (L = {L:.0f}mm)', color='#00F5D4', fontsize=8)

    ax_mech.set_title(f'Kinematic Top View (Steer: $\\theta_{{tripod}} = {th_steer:+.1f}^\\circ$)',
                      color='white', fontsize=10.0, fontweight='bold')
    ax_mech.set_xlabel('X (Transverse, mm)', color='white', fontsize=8.5)
    ax_mech.set_ylabel('Y (Longitudinal, mm)', color='white', fontsize=8.5)
    ax_mech.tick_params(colors='white', labelsize=8)
    ax_mech.set_aspect('equal', 'datalim')
    ax_mech.set_xlim(-K * 1.1, K * 1.1)
    ax_mech.set_ylim(-L * 1.18, TIRE_DIA * 0.8)

    # =========================================================================
    # PLOT 2: INNER VS OUTER ANGLE
    # =========================================================================
    ax_ang.cla()
    ax_ang.grid(True, color='#282C34', linestyle='--', linewidth=0.7)
    if len(inner_s) > 0:
        sort_i = np.argsort(inner_s)
        ax_ang.plot(inner_s[sort_i], inner_s[sort_i], 'w:', linewidth=1.4, label='Parallel (0% Ackermann)')
        ax_ang.plot(inner_s[sort_i], ideal_s[sort_i], color='#00B4D8', linestyle='--', linewidth=2.2, label='100% Ideal Ackermann')
        ax_ang.plot(inner_s[sort_i], outer_s[sort_i], color='#EF233C', linewidth=2.5, label='Actual Set Geometry')
        ax_ang.scatter(live_inner, live_outer, color='#FFD166', s=80, zorder=5,
                       label=f'Live: $\\delta_i={live_inner:.1f}^\\circ, \\delta_o={live_outer:.1f}^\\circ$')

    ax_ang.set_title('Inner Steer Angle vs. Outer Steer Angle', color='white', fontsize=10.0, fontweight='bold')
    ax_ang.set_xlabel(r'Inner Wheel Angle $\delta_{inner}$ (deg)', color='white', fontsize=8.5)
    ax_ang.set_ylabel(r'Outer Wheel Angle $\delta_{outer}$ (deg)', color='white', fontsize=8.5)
    ax_ang.tick_params(colors='white', labelsize=8)
    ax_ang.legend(loc='upper left', facecolor='#16181D', edgecolor='#282C34', labelcolor='white', fontsize=7.5)
    ax_ang.set_xlim(0, 35)
    ax_ang.set_ylim(0, 32)

    # =========================================================================
    # PLOT 3: ACKERMANN PERCENTAGE (%)
    # =========================================================================
    ax_pct.cla()
    ax_pct.grid(True, color='#282C34', linestyle='--', linewidth=0.7)
    ax_pct.axhspan(-40, 0, color='#D90429', alpha=0.14, label='Anti-Ackermann (<0%)')
    ax_pct.axhspan(0, 100, color='#2B9348', alpha=0.14, label='Pro-Ackermann (0-100%)')
    ax_pct.axhspan(100, 180, color='#0077B6', alpha=0.14, label='Over-Ackermann (>100%)')
    ax_pct.axhline(100, color='#52B788', linestyle='--', linewidth=1.8)
    ax_pct.axhline(0, color='white', linestyle=':', linewidth=1.2)

    if len(inner_s) > 0:
        ax_pct.plot(inner_s[sort_i], ack_pct_s[sort_i], color='#EF233C', linewidth=2.5, label='Actual Ackermann %')
        ax_pct.scatter(live_inner, live_ack_pct, color='#FFD166', s=80, zorder=5,
                       label=f'Live: {live_ack_pct:.1f}%')

    ax_pct.set_title('Ackermann Percentage (%) vs. Inner Angle', color='white', fontsize=10.0, fontweight='bold')
    ax_pct.set_xlabel(r'Inner Wheel Angle $\delta_{inner}$ (deg)', color='white', fontsize=8.5)
    ax_pct.set_ylabel('Ackermann %', color='white', fontsize=8.5)
    ax_pct.tick_params(colors='white', labelsize=8)
    ax_pct.legend(loc='upper right', facecolor='#16181D', edgecolor='#282C34', labelcolor='white', fontsize=7.5)
    ax_pct.set_xlim(0, 35)
    ax_pct.set_ylim(-20, 180)

    # =========================================================================
    # PLOT 4: POINT OF INTERSECTION (|y_int|)
    # =========================================================================
    ax_int.cla()
    ax_int.grid(True, color='#282C34', linestyle='--', linewidth=0.7)
    ax_int.axhline(L, color='#00F5D4', linestyle='--', linewidth=2.0, label=f'Target: Rear Axle (L = {L:.0f}mm)')

    if len(inner_s) > 0:
        valid_int_mask = ~np.isnan(y_int_s[sort_i])
        ax_int.plot(inner_s[sort_i][valid_int_mask], np.abs(y_int_s[sort_i][valid_int_mask]),
                    color='#FF006E', linewidth=2.5, label='Actual Intersection |y_{int}|')
        if not math.isnan(live_y_int):
            ax_int.scatter(live_inner, abs(live_y_int), color='#FFD166', s=80, zorder=5,
                           label=f'Live |y_{{int}}| = {abs(live_y_int):.1f}mm')

    ax_int.set_title('Instantaneous Intersection Distance vs. Inner Angle', color='white', fontsize=10.0, fontweight='bold')
    ax_int.set_xlabel(r'Inner Wheel Angle $\delta_{inner}$ (deg)', color='white', fontsize=8.5)
    ax_int.set_ylabel('Distance from Front Axle (mm)', color='white', fontsize=8.5)
    ax_int.tick_params(colors='white', labelsize=8)
    ax_int.legend(loc='upper right', facecolor='#16181D', edgecolor='#282C34', labelcolor='white', fontsize=7.5)
    ax_int.set_xlim(2, 35)
    ax_int.set_ylim(0, L * 1.8)

    # =========================================================================
    # TELEMETRY HUD UPDATE
    # =========================================================================
    turn_dir = 'LEFT TURN' if is_turn_left else 'RIGHT TURN'
    r_turn = (L / math.sin(math.radians(live_inner))) / 1000.0 if abs(live_inner) > 0.1 else float('inf')

    txt = (
        "================================\n"
        "   REAL-TIME KINEMATIC HUD      \n"
        "================================\n"
        f"Active Direction : {turn_dir}\n"
        f"Tripod Steer Ang : {th_steer:+.1f} deg\n"
        "--------------------------------\n"
        f"Inner Wheel (di) : {live_inner:.2f} deg\n"
        f"Outer Wheel (do) : {live_outer:.2f} deg\n"
        f"Ideal Outer (id) : {live_ideal_outer:.2f} deg\n"
        f"Steer Error      : {(live_outer - live_ideal_outer):+.2f} deg\n"
        "--------------------------------\n"
        f"Ackermann %      : {live_ack_pct:.1f} %\n"
        f"Intersection Y   : {live_y_int:.1f} mm\n"
        f"Target Axle (L)  : {-L:.1f} mm\n"
        f"Intersection X   : {live_x_int:.1f} mm\n"
        f"Est Turn Radius  : {r_turn:.2f} m\n"
        "--------------------------------\n"
        "DYNAMIC CHASSIS JACKING:\n"
        f"Inside Wheel Lift: {jacking_lift_mm:+.2f} mm\n"
        f"Outer Camber Gain: {camber_gain_deg:+.2f} deg\n"
        "--------------------------------\n"
        f"Scrub Offset     : {scrub_w:.1f} mm\n"
        f"Tripod Y-Offset  : {y_P:+.1f} mm\n"
        f"Mechanism Status : {'VALID 4-BAR' if valid_geom else 'TOGGLE LOCK'}\n"
        "Ground Clearance : 15mm (Legal)\n"
        "================================"
    )
    telemetry_txt.set_text(txt)
    fig.canvas.draw_idle()

def on_zero_toe(event):
    K         = sliders['K'].val
    R_tripod  = sliders['R_tripod'].val
    D_sep     = sliders['D_sep'].val
    L_arm     = sliders['L_arm'].val
    alpha_deg = sliders['alpha_arm_deg'].val
    y_P       = sliders['y_P'].val
    calc_L_tr = compute_neutral_tierod(K, R_tripod, D_sep, L_arm, alpha_deg, y_P)
    sliders['L_tierod'].set_val(calc_L_tr)

def on_reset(event):
    sliders['K'].set_val(DEFAULT_K)
    sliders['L'].set_val(DEFAULT_L)
    sliders['R_tripod'].set_val(DEFAULT_R_TRIPOD)
    sliders['D_sep'].set_val(DEFAULT_D_SEP)
    sliders['y_P'].set_val(DEFAULT_Y_P)
    sliders['L_arm'].set_val(DEFAULT_L_ARM)
    sliders['alpha_arm_deg'].set_val(DEFAULT_ALPHA_DEG)
    sliders['caster_deg'].set_val(DEFAULT_CASTER_DEG)
    sliders['kpi_deg'].set_val(DEFAULT_KPI_DEG)
    sliders['scrub_mm'].set_val(DEFAULT_SCRUB_MM)
    sliders['steer_input'].set_val(DEFAULT_STEER_DEG)
    calc_L_tr = compute_neutral_tierod(DEFAULT_K, DEFAULT_R_TRIPOD, DEFAULT_D_SEP,
                                       DEFAULT_L_ARM, DEFAULT_ALPHA_DEG, DEFAULT_Y_P)
    sliders['L_tierod'].set_val(calc_L_tr)

for s in sliders.values():
    s.on_changed(update)

btn_zero.on_clicked(on_zero_toe)
btn_reset.on_clicked(on_reset)

update()
plt.show()
