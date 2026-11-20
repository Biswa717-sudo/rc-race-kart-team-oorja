"""
Generate Master CAD Parametric Blueprint for Team Oorja S-Curve Tripod Steering Linkage
Chassis: K = 126 mm, L = 130 mm
"""

import math
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as patches
from matplotlib.patches import FancyArrowPatch, Arc, Circle, Polygon, Wedge

# Set high DPI and aesthetic styling
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['font.sans-serif'] = ['DejaVu Sans', 'Arial', 'Helvetica']

fig = plt.figure(figsize=(20, 11), facecolor='#0A0F1D')

# Create 2 main panels: Left (Detailed Parametric Geometry), Right-Top (Kinematic Motion Overlay), Right-Bottom (Dimension Table & Specs)
gs = fig.add_gridspec(2, 2, width_ratios=[1.25, 0.95], height_ratios=[1.1, 0.9],
                       left=0.04, right=0.97, bottom=0.06, top=0.92, wspace=0.18, hspace=0.22)

ax_main = fig.add_subplot(gs[:, 0], facecolor='#0D1527')
ax_motion = fig.add_subplot(gs[0, 1], facecolor='#0D1527')
ax_table = fig.add_subplot(gs[1, 1], facecolor='#0D1527')

# Title Banner
fig.text(0.5, 0.965, "TEAM OORJA F1 RC RACE KART — PARAMETRIC TRIPOD STEERING BLUEPRINT",
         ha='center', va='center', fontsize=18, fontweight='bold', color='#00F5D4')
fig.text(0.5, 0.938, "Progressive S-Curve Ackermann Linkage (K = 126 mm | L = 130 mm | Dual Sweeper Anti-Ackermann & Hairpin Super-Ackermann)",
         ha='center', va='center', fontsize=11, color='#A0AEC0')

# =============================================================================
# PANEL 1: DETAILED PARAMETRIC BLUEPRINT (NEUTRAL CAD VIEW)
# =============================================================================
ax = ax_main
ax.set_aspect('equal')
ax.grid(True, which='both', color='#1E293B', linestyle='--', linewidth=0.8, alpha=0.7)

# Coordinates
K = 126.0
L = 130.0
y_P = -30.0
x_T = 22.0
D_sep = 44.0
y_T_offset = 5.0
y_T = y_P + y_T_offset # -25.0
L_arm = 20.0
alpha_deg = 25.0
alpha_rad = math.radians(alpha_deg)

KL = (-K / 2.0, 0.0)
KR = ( K / 2.0, 0.0)

JL = (KL[0] + L_arm * math.sin(alpha_rad), -L_arm * math.cos(alpha_rad))
JR = (KR[0] - L_arm * math.sin(alpha_rad), -L_arm * math.cos(alpha_rad))

TL = (-x_T, y_T)
TR = ( x_T, y_T)

L_tierod = math.hypot(JL[0] - TL[0], JL[1] - TL[1])
R_tri = math.hypot(x_T, y_T_offset)

# Draw Front Axle Reference Centerline (y = 0)
ax.axhline(0, color='#38BDF8', linestyle='-.', linewidth=1.2, alpha=0.6)
ax.axvline(0, color='#38BDF8', linestyle='-.', linewidth=1.2, alpha=0.6)
ax.text(-68, 2.5, "FRONT KINGPIN AXIS (y = 0)", color='#38BDF8', fontsize=9, fontweight='bold')
ax.text(2.0, 12, "CHASSIS CENTERLINE (x = 0)", color='#38BDF8', fontsize=8.5, rotation=90)

# Draw Front Axle Beam
ax.plot([KL[0], KR[0]], [KL[1], KR[1]], color='#64748B', linewidth=4.0, zorder=2, solid_capstyle='round')

# Draw Wheel Hubs & Tires (Neutral)
tire_w = 24.0
tire_dia = 62.0
for kx, side in [(-K/2.0 - 12.0, 'LEFT'), (K/2.0 + 12.0, 'RIGHT')]:
    rect = patches.Rectangle((kx - tire_w/2, -tire_dia/2), tire_w, tire_dia,
                             linewidth=1.5, edgecolor='#475569', facecolor='#1E293B', alpha=0.6, zorder=2)
    ax.add_patch(rect)
    # Spindle line
    ax.plot([kx < 0 and KL[0] or KR[0], kx], [0, 0], color='#94A3B8', linewidth=2.5, zorder=3)
    ax.text(kx, 35, f"{side} FRONT TIRE\n(Scrub Offset = 12mm)", color='#94A3B8', fontsize=7.5, ha='center')

# Draw Knuckle Trailing Arms
ax.plot([KL[0], JL[0]], [KL[1], JL[1]], color='#F43F5E', linewidth=3.5, zorder=4, solid_capstyle='round')
ax.plot([KR[0], JR[0]], [KR[1], JR[1]], color='#F43F5E', linewidth=3.5, zorder=4, solid_capstyle='round')

# Draw Knuckle Arm Labels
ax.text((KL[0] + JL[0])/2 - 13, (KL[1] + JL[1])/2 - 2, f"L_arm = {L_arm:.0f}mm\n(alpha = +{alpha_deg:.0f}°)",
        color='#F43F5E', fontsize=8.5, fontweight='bold', ha='right')

# Draw Tripod Bellcrank Plate
# Tripod shape: triangle between Pivot (0, y_P), TL, and TR
tripod_poly = Polygon([[0, y_P], [TL[0], TL[1]], [0, y_P + y_T_offset + 3.0], [TR[0], TR[1]]],
                      closed=True, edgecolor='#F59E0B', facecolor='#F59E0B', alpha=0.25, linewidth=2.0, zorder=3)
ax.add_patch(tripod_poly)
ax.plot([0, TL[0]], [y_P, TL[1]], color='#F59E0B', linewidth=2.5, zorder=4)
ax.plot([0, TR[0]], [y_P, TR[1]], color='#F59E0B', linewidth=2.5, zorder=4)

# Draw Tie-Rods
ax.plot([TL[0], JL[0]], [TL[1], JL[1]], color='#10B981', linewidth=3.5, zorder=4, solid_capstyle='round')
ax.plot([TR[0], JR[0]], [TR[1], JR[1]], color='#10B981', linewidth=3.5, zorder=4, solid_capstyle='round')

# Tie-Rod Dimension Callout
ax.text((TL[0] + JL[0])/2 - 2, (TL[1] + JL[1])/2 - 5, f"Tie-Rod = {L_tierod:.2f} mm",
        color='#10B981', fontsize=9.5, fontweight='bold', ha='center',
        bbox=dict(boxstyle='round,pad=0.25', facecolor='#064E3B', edgecolor='#10B981', alpha=0.9))

# Draw Joints (Kingpins, Ball-joints, Tripod Pivot)
ax.scatter([KL[0], KR[0]], [KL[1], KR[1]], color='#38BDF8', s=120, edgecolor='white', linewidth=1.5, zorder=6)
ax.text(KL[0], 5, f"Kingpin KL\n(-{K/2:.0f}, 0)", color='#38BDF8', fontsize=8, ha='center', fontweight='bold')
ax.text(KR[0], 5, f"Kingpin KR\n(+{K/2:.0f}, 0)", color='#38BDF8', fontsize=8, ha='center', fontweight='bold')

ax.scatter([JL[0], JR[0]], [JL[1], JR[1]], color='#F43F5E', s=90, edgecolor='white', linewidth=1.2, zorder=6)
ax.text(JL[0] - 2, JL[1] - 5, f"JL ({JL[0]:.1f}, {JL[1]:.1f})", color='#F43F5E', fontsize=7.5, ha='right')
ax.text(JR[0] + 2, JR[1] - 5, f"JR ({JR[0]:.1f}, {JR[1]:.1f})", color='#F43F5E', fontsize=7.5, ha='left')

ax.scatter(0, y_P, color='#EAB308', s=160, marker='^', edgecolor='white', linewidth=1.5, zorder=6)
ax.text(0, y_P - 7, f"Tripod Steering Shaft Pivot\nP(0, {y_P:.0f} mm)", color='#EAB308', fontsize=8.5, ha='center', fontweight='bold')

ax.scatter([TL[0], TR[0]], [TL[1], TR[1]], color='#10B981', s=80, edgecolor='white', linewidth=1.2, zorder=6)
ax.text(TL[0] - 2, TL[1] + 3, f"TL (-{x_T:.0f}, {y_T:.0f})", color='#10B981', fontsize=8, ha='right')
ax.text(TR[0] + 2, TR[1] + 3, f"TR (+{x_T:.0f}, {y_T:.0f})", color='#10B981', fontsize=8, ha='left')

# --- DIMENSION ARROWS & ANNOTATIONS ---
# 1. Trackwidth K Arrow
ax.annotate('', xy=(KR[0], 18), xytext=(KL[0], 18),
            arrowprops=dict(arrowstyle='<->', color='#38BDF8', lw=1.8))
ax.text(0, 21, f"TRACKWIDTH K = {K:.1f} mm (Kingpin-to-Kingpin)", color='#38BDF8', fontsize=9.5, fontweight='bold', ha='center')

# 2. Tripod Width D_sep Arrow
ax.annotate('', xy=(TR[0], -21), xytext=(TL[0], -21),
            arrowprops=dict(arrowstyle='<->', color='#F59E0B', lw=1.5))
ax.text(0, -19.5, f"D_sep = {D_sep:.0f} mm (±{x_T:.0f} mm)", color='#F59E0B', fontsize=8.5, fontweight='bold', ha='center')

# 3. Tripod Longitudinal Pivot Distance (y_P)
ax.annotate('', xy=(34, y_P), xytext=(34, 0),
            arrowprops=dict(arrowstyle='<->', color='#EAB308', lw=1.4))
ax.text(36, y_P / 2, f"y_P = {abs(y_P):.0f} mm\n(Behind Axle)", color='#EAB308', fontsize=8, va='center')

# 4. Tripod Forward Offset (y_T_offset = +5 mm)
ax.annotate('', xy=(-34, y_T), xytext=(-34, y_P),
            arrowprops=dict(arrowstyle='<->', color='#10B981', lw=1.4))
ax.text(-36, (y_T + y_P)/2, f"Offset = +{y_T_offset:.0f} mm\n(Forward of Pivot)", color='#10B981', fontsize=8, va='center', ha='right')

# 5. Inward Knuckle Angle Arc (alpha = 25°)
arc = Arc((KL[0], KL[1]), 22, 22, angle=0, theta1=270, theta2=270+alpha_deg, color='#F43F5E', lw=1.5)
ax.add_patch(arc)
ax.text(KL[0] + 5, -12, f"α = {alpha_deg:.0f}°", color='#F43F5E', fontsize=8.5, fontweight='bold')

# Main Axis limits
ax.set_xlim(-92, 92)
ax.set_ylim(-48, 42)
ax.set_xlabel("Transverse X (mm)", color='#94A3B8', fontsize=9)
ax.set_ylabel("Longitudinal Y (mm)", color='#94A3B8', fontsize=9)
ax.tick_params(colors='#94A3B8', labelsize=8)
ax.set_title("TOP-DOWN PARAMETRIC LINKAGE GEOMETRY (NEUTRAL STATE)", color='white', fontsize=11, fontweight='bold', pad=10)

# =============================================================================
# PANEL 2: KINEMATIC MOTION OVERLAY (SWEPPER VS HAIRPIN)
# =============================================================================
ax2 = ax_motion
ax2.set_aspect('equal')
ax2.grid(True, color='#1E293B', linestyle='--', linewidth=0.7, alpha=0.7)

# Draw kingpins
ax2.plot([KL[0], KR[0]], [0, 0], color='#475569', linewidth=2.0)
ax2.scatter([KL[0], KR[0]], [0, 0], color='#38BDF8', s=60, zorder=5)

# Simulate 3 key states: Neutral (0°), Sweeper (8° input), Hairpin (17° input)
from rc_kart_scurve_tripod_benchmark import circle_intersect

states = [
    {'name': 'NEUTRAL (0°)', 'th': 0.0, 'color': '#475569', 'alpha': 0.4, 'lw': 1.2, 'dash': ':'},
    {'name': 'SWEEPER (R=3m, th=8°)\nAnti-Ackermann: Out > In', 'th': 8.0, 'color': '#38BDF8', 'alpha': 0.85, 'lw': 2.0, 'dash': '--'},
    {'name': 'HAIRPIN (R=1m, th=17°)\nSuper-Ackermann: In >> Out (+204%)', 'th': 17.0, 'color': '#00F5D4', 'alpha': 1.0, 'lw': 2.8, 'dash': '-'}
]

vL0 = (-x_T, y_T_offset)
vR0 = ( x_T, y_T_offset)
ang_L0 = math.atan2(JL[1] - KL[1], JL[0] - KL[0])
ang_R0 = math.atan2(JR[1] - KR[1], JR[0] - KR[0])

legend_elements = []
for st in states:
    th = math.radians(st['th'])
    TL_rot = (vL0[0]*math.cos(th) - vL0[1]*math.sin(th), y_P + vL0[0]*math.sin(th) + vL0[1]*math.cos(th))
    TR_rot = (vR0[0]*math.cos(th) - vR0[1]*math.sin(th), y_P + vR0[0]*math.sin(th) + vR0[1]*math.cos(th))
    
    cL = circle_intersect(KL, L_arm, TL_rot, L_tierod)
    cR = circle_intersect(KR, L_arm, TR_rot, L_tierod)
    
    if cL and cR:
        pL1, pL2 = cL
        pJL = pL1 if math.hypot(pL1[0]-JL[0], pL1[1]-JL[1]) < math.hypot(pL2[0]-JL[0], pL2[1]-JL[1]) else pL2
        pR1, pR2 = cR
        pJR = pR1 if math.hypot(pR1[0]-JR[0], pR1[1]-JR[1]) < math.hypot(pR2[0]-JR[0], pR2[1]-JR[1]) else pR2
        
        # Draw tripod
        ax2.plot([0, TL_rot[0]], [y_P, TL_rot[1]], color=st['color'], linewidth=st['lw'], linestyle=st['dash'], alpha=st['alpha'])
        ax2.plot([0, TR_rot[0]], [y_P, TR_rot[1]], color=st['color'], linewidth=st['lw'], linestyle=st['dash'], alpha=st['alpha'])
        
        # Draw tie rods
        ax2.plot([TL_rot[0], pJL[0]], [TL_rot[1], pJL[1]], color=st['color'], linewidth=st['lw'], linestyle=st['dash'], alpha=st['alpha'])
        ax2.plot([TR_rot[0], pJR[0]], [TR_rot[1], pJR[1]], color=st['color'], linewidth=st['lw'], linestyle=st['dash'], alpha=st['alpha'])
        
        # Draw knuckle arms
        ax2.plot([KL[0], pJL[0]], [KL[1], pJL[1]], color=st['color'], linewidth=st['lw'], linestyle=st['dash'], alpha=st['alpha'])
        ax2.plot([KR[0], pJR[0]], [KR[1], pJR[1]], color=st['color'], linewidth=st['lw'], linestyle=st['dash'], alpha=st['alpha'])
        
        dL = math.degrees(math.atan2(pJL[1]-KL[1], pJL[0]-KL[0]) - ang_L0)
        dR = math.degrees(math.atan2(pJR[1]-KR[1], pJR[0]-KR[0]) - ang_R0)
        
        # Wheels
        for hub_x, steer_ang in [(-K/2 - 10, abs(dL)), (K/2 + 10, abs(dR))]:
            w_th = math.radians(steer_ang if hub_x < 0 else steer_ang)
            bx = np.array([-10, 10])
            by = np.array([0, 0])
            rx = bx * math.cos(w_th) - by * math.sin(w_th) + hub_x
            ry = bx * math.sin(w_th) + by * math.cos(w_th)
            ax2.plot(rx, ry, color=st['color'], linewidth=3.0, alpha=st['alpha'])

# Annotate the Tripod Toggle Arc
arc_tripod = Arc((0, y_P), 2*R_tri, 2*R_tri, angle=0, theta1=60, theta2=120, color='#EAB308', lw=1.2, ls=':')
ax2.add_patch(arc_tripod)
ax2.text(0, y_T + 4, "Tripod Toggle Circular Arc (R = 22.56 mm)", color='#EAB308', fontsize=7.5, ha='center')

# Callouts for hairpins and sweepers
ax2.text(-68, -20, "HAIRPIN (17° Input):\nInside δi = 7.3°\nOutside δo = 5.6°\n-> Ackermann = +204.5%\n-> Jacking Lift = +1.91 mm",
         color='#00F5D4', fontsize=7.5, fontweight='bold', bbox=dict(boxstyle='round,pad=0.3', facecolor='#0B2925', edgecolor='#00F5D4', alpha=0.9))

ax2.text(12, -38, "SWEEPER (8° Input):\nInside δi = 1.25°\nOutside δo = 1.41°\n-> Anti-Ackermann (-0.15°)\n-> Maximizes loaded grip",
         color='#38BDF8', fontsize=7.5, fontweight='bold', bbox=dict(boxstyle='round,pad=0.3', facecolor='#0B1E38', edgecolor='#38BDF8', alpha=0.9))

ax2.set_xlim(-85, 85)
ax2.set_ylim(-45, 15)
ax2.tick_params(colors='#94A3B8', labelsize=7.5)
ax2.set_title("KINEMATIC MULTI-STATE OVERLAY: SWEEPER VS HAIRPIN", color='white', fontsize=10.5, fontweight='bold', pad=8)

# =============================================================================
# PANEL 3: PARAMETRIC DIMENSION SCHEDULE & SPECIFICATIONS
# =============================================================================
ax3 = ax_table
ax3.axis('off')

# Header
ax3.text(0.02, 0.96, "PARAMETRIC FABRICATION & SETUP SCHEDULE", color='#00F5D4', fontsize=11, fontweight='bold')
ax3.text(0.02, 0.90, "Strict mm & degree dimensions for CNC machining & 3D printing:", color='#94A3B8', fontsize=8)

specs = [
    ("Kingpin Trackwidth (K)", "126.0 mm", "Center-to-center between kingpin pivot pins"),
    ("Chassis Wheelbase (L)", "130.0 mm", "Front kingpin line to rear solid axle center"),
    ("Tripod Pivot Offset (y_P)", "-30.0 mm", "Pivot position relative to kingpin axis (y=0)"),
    ("Tripod Hole Spacing (D_sep)", "44.0 mm", "Distance between left & right tie-rod holes (x = ±22.0 mm)"),
    ("Tripod Hole Forward Offset", "+5.0 mm", "Holes located at y = -25.0 mm (forward of column pivot)"),
    ("Tripod Plate Arc Radius (R_tri)", "22.56 mm", "R = sqrt(22.0^2 + 5.0^2) | Lobe Angle = +12.8° forward"),
    ("Knuckle Steering Arm (L_arm)", "20.0 mm", "Trailing arm length from kingpin to rod ball joint"),
    ("Knuckle Arm Angle (alpha)", "+25.0°", "Angled INWARD toward chassis centerline"),
    ("Left Ball-Joint JL", "(-54.55, -18.13)", "Neutral eye coordinate in chassis frame (mm)"),
    ("Right Ball-Joint JR", "(+54.55, -18.13)", "Neutral eye coordinate in chassis frame (mm)"),
    ("Turnbuckle Tie-Rod Length", "33.27 mm", "Finished eye-to-eye tie-rod length (M2/M3 rod)"),
    ("Kingpin Caster Angle", "+14.0°", "Dynamic chassis jacking & camber gain active"),
    ("Kingpin Inclination (KPI)", "6.0°", "Centerpoint steering scrub reduction"),
    ("Wheel Scrub Offset", "12.0 mm", "Kingpin line to tire contact patch center")
]

y_row = 0.81
for param, val, note in specs:
    ax3.text(0.04, y_row, param, color='#F8FAFC', fontsize=7.8, fontweight='bold')
    ax3.text(0.48, y_row, val, color='#38BDF8', fontsize=7.8, fontweight='bold')
    ax3.text(0.66, y_row, note, color='#64748B', fontsize=7.2)
    y_row -= 0.054

# Save high-res PNG image
output_path = r"D:\rc car\tripod_steering_parametric_blueprint.png"
plt.savefig(output_path, dpi=300, facecolor=fig.get_facecolor(), edgecolor='none')
print(f"Blueprint image saved successfully at: {output_path}")
