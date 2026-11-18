"""
RC Kart Timeline 1 Full Race Track Drivetrain & Lap Simulator
Team Oorja F1 RC Race (Division B: Build Your Own RC Cars)
Track: 12.0m x 7.4m Outdoor Redstone Tiles (mu = 0.95, 2-5mm tile seams)
Circuit: 44.85m Lap, 8-Lap Endurance (358.8m total race distance)

TIMELINE 1 FOCUS:
- 1x A2212 Brushless Outrunner + 80A Airplane ESC + Solid 8mm Precision Rear Axle
- GT2 Synchronous Timing Belt Transmission
- Head-to-Head: 1400 KV (16T:64T, 4.0:1) vs. 1000 KV (20T:60T, 3.0:1)
- 600g Baseline Curb Mass

FEATURES:
- Instantaneous 60+ FPS interactive sliders for Mass, KV, Gearing, Voltage, Grip, Tire Dia
- Two-pass forward-acceleration & backward-braking point-mass lap solver
- 2D Track Map with color-coded speed heatmap
- Velocity profile v(s) overlay
- Electrical power, motor current & battery voltage telemetry
- GT2 belt tooth shear stress, teeth in mesh & skipping safety factor
- Full 8-lap endurance race summary and 9-sector breakdown table
"""

import math
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.widgets import Slider, Button
from matplotlib.collections import LineCollection

# =============================================================================
# DEFAULT TRACK & TIMELINE 1 PARAMETERS
# =============================================================================
DEFAULT_MASS_KG    = 0.600    # 600g Curb Mass
DEFAULT_KV         = 1400.0   # A2212 1400KV default
DEFAULT_VOC        = 8.40     # 2S LiPo Peak Voltage
DEFAULT_Z1         = 16       # GT2 Motor Pinion
DEFAULT_Z2         = 64       # GT2 Axle Spur
DEFAULT_DTIRE_MM   = 65.0     # 65mm Rubber Slicks
DEFAULT_MUTIRE     = 0.95     # Outdoor Redstone Tiles
DEFAULT_REAR_WT    = 0.65     # 65% dynamic rear weight transfer
DEFAULT_BELTW_MM   = 6.0      # 6mm GT2 belt width
DEFAULT_CDIST_MM   = 50.0     # 50mm center distance

# Circuit Sectors (Total 44.85m)
LAP_LENGTH = 44.85
SEC_BOUNDS = [0.0, 7.0, 10.1416, 16.1416, 19.2832, 24.2832, 27.4248, 31.9248, 41.3496, 44.85]
SEC_NAMES = [
    'Main Straight (7.0m)', 'T1 Hairpin (R=1.0m)', 'Back Straight 1 (6.0m)',
    'T2 Hairpin (R=1.0m)', 'Back Straight 2 (5.0m)', 'T3 Hairpin (R=1.0m)',
    'Top Straight (4.5m)', 'T4 Sweeper (R=3.0m)', 'Front Link (3.50m)'
]

state = {
    'overlay_kv': True,       # Show 1400KV and 1000KV head-to-head
    'has_idler': True,        # 623ZZ idler snubber installed
    'flying_lap': True        # Show flying lap vs standing start
}

# Pre-generate 2D Track Centerline Coordinates for Visualization
def generate_track_2d(n_pts=600):
    s_arr = np.linspace(0, LAP_LENGTH, n_pts)
    x_arr = np.zeros(n_pts)
    y_arr = np.zeros(n_pts)

    for i, s in enumerate(s_arr):
        if s < 7.0:
            # S1: Main Straight from (3.5, 1.0) to (10.5, 1.0) along +X
            x_arr[i] = 3.5 + s
            y_arr[i] = 1.0
        elif s < 10.1416:
            # S2: T1 Hairpin (R=1.0m, center=(10.5, 2.0)), angle -pi/2 to +pi/2
            ds = s - 7.0
            theta = -np.pi/2 + ds / 1.0
            x_arr[i] = 10.5 + 1.0 * np.cos(theta)
            y_arr[i] = 2.0 + 1.0 * np.sin(theta)
        elif s < 16.1416:
            # S3: Back Straight 1 from (10.5, 3.0) to (4.5, 3.0) along -X
            ds = s - 10.1416
            x_arr[i] = 10.5 - ds
            y_arr[i] = 3.0
        elif s < 19.2832:
            # S4: T2 Hairpin (R=1.0m, center=(4.5, 4.0)), angle -pi/2 to +pi/2 (curving to left/up)
            ds = s - 16.1416
            theta = np.pi/2 - ds / 1.0
            x_arr[i] = 4.5 - 1.0 * np.sin(theta)
            y_arr[i] = 4.0 - 1.0 * np.cos(theta)
        elif s < 24.2832:
            # S5: Back Straight 2 from (4.5, 5.0) to (9.5, 5.0) along +X
            ds = s - 19.2832
            x_arr[i] = 4.5 + ds
            y_arr[i] = 5.0
        elif s < 27.4248:
            # S6: T3 Hairpin (R=1.0m, center=(9.5, 6.0)), angle -pi/2 to +pi/2
            ds = s - 24.2832
            theta = -np.pi/2 + ds / 1.0
            x_arr[i] = 9.5 + 1.0 * np.cos(theta)
            y_arr[i] = 6.0 + 1.0 * np.sin(theta)
        elif s < 31.9248:
            # S7: Top Straight from (9.5, 7.0) to (5.0, 7.0) along -X
            ds = s - 27.4248
            x_arr[i] = 9.5 - ds
            y_arr[i] = 7.0
        elif s < 41.3496:
            # S8: T4 Sweeper (R=3.0m, center=(5.0, 4.0)), angle +pi/2 to -pi/2
            ds = s - 31.9248
            theta = np.pi/2 + ds / 3.0
            x_arr[i] = 5.0 + 3.0 * np.cos(theta)
            y_arr[i] = 4.0 + 3.0 * np.sin(theta)
        else:
            # S9: Front Link from (5.0, 1.0) to (3.5, 1.0)
            ds = s - 41.3496
            x_arr[i] = 5.0 - (ds / (44.85 - 41.3496)) * 1.5
            y_arr[i] = 1.0

    return s_arr, x_arr, y_arr

TRACK_S_2D, TRACK_X_2D, TRACK_Y_2D = generate_track_2d(600)

# =============================================================================
# LAP SOLVER KINEMATICS & DYNAMICS
# =============================================================================
def solve_full_track(mass_kg, kv, v_oc, z1, z2, d_tire_mm, mu, rear_wt_frac, belt_w_mm, cdist_mm, has_idler):
    N = 1200
    s_single = np.linspace(0, LAP_LENGTH, N)
    ds = s_single[1] - s_single[0]

    # Concatenate 2 laps for cyclic boundary convergence
    N2 = 2 * N
    s_2lap = np.concatenate([s_single, s_single + LAP_LENGTH])

    R_2lap = np.full(N2, np.inf)
    for j in range(2):
        offset = j * LAP_LENGTH
        for i in range(N):
            idx = j * N + i
            si = s_2lap[idx] - offset
            if SEC_BOUNDS[1] <= si < SEC_BOUNDS[2]:
                R_2lap[idx] = 1.0
            elif SEC_BOUNDS[3] <= si < SEC_BOUNDS[4]:
                R_2lap[idx] = 1.0
            elif SEC_BOUNDS[5] <= si < SEC_BOUNDS[6]:
                R_2lap[idx] = 1.0
            elif SEC_BOUNDS[7] <= si < SEC_BOUNDS[8]:
                R_2lap[idx] = 3.0

    g = 9.81
    r_bat = 0.015
    r_esc = 0.003
    rm = 0.100 if kv >= 1200 else 0.130
    i0 = 0.70 if kv >= 1200 else 0.50
    r_tot = r_bat + r_esc + rm

    kt = 9.5493 / kv
    ke = 1.0 / (kv * 2.0 * math.pi / 60.0)
    ratio = float(z2) / float(z1)
    r_w = (d_tire_mm / 1000.0) / 2.0

    # Inertia
    j_rotor = 5.0e-6
    j_p1 = 0.5e-6
    j_p2 = 4.0e-6
    j_wheel = 2.0e-5
    j_axle = 1.5e-6
    j_total = (j_rotor + j_p1) * (ratio**2) + j_p2 + j_wheel + j_axle
    m_eff = mass_kg + j_total / (r_w**2)

    # Traction grip limit
    f_grip_max = mu * mass_kg * g * rear_wt_frac

    # Lateral cornering limits
    v_max_curve = np.sqrt(mu * g * R_2lap)

    # Belt Geometry & Shear Capacity
    pitch = 2.0 # GT2 2mm
    d1 = (z1 * pitch) / math.pi
    d2 = (z2 * pitch) / math.pi
    r_pinion = (d1 / 1000.0) / 2.0
    sin_phi = max(-1.0, min(1.0, (d2 - d1) / (2.0 * cdist_mm)))
    phi_wrap_deg = 180.0 - 2.0 * math.degrees(math.asin(sin_phi))
    if has_idler:
        phi_wrap_deg = min(230.0, phi_wrap_deg + 65.0)
    tim = z1 * (phi_wrap_deg / 360.0)
    f_shear_allowable_per_tooth = 2.4 * belt_w_mm # ~14.4 N/tooth for 6mm belt

    def calc_drive_accel(v):
        omega_w = v / r_w
        omega_m = omega_w * ratio
        eb = omega_m * ke
        i_m = max(0.0, min(80.0, (v_oc - eb) / r_tot))
        tau_m = max(0.0, kt * (i_m - i0))
        tau_axle = tau_m * ratio * 0.97
        f_drive = tau_axle / r_w
        f_tractive = min(f_drive, f_grip_max)
        f_rr = 0.03 * mass_kg * g
        f_aero = 0.5 * 1.2 * 0.03 * (v**2)
        return max(0.0, (f_tractive - f_rr - f_aero) / m_eff)

    def calc_brake_accel(v):
        f_rr = 0.03 * mass_kg * g
        f_aero = 0.5 * 1.2 * 0.03 * (v**2)
        return (mu * g * mass_kg + f_rr + f_aero) / mass_kg

    # 1. Forward Pass
    v_fwd = np.zeros(N2)
    v_fwd[0] = 0.05
    for i in range(N2 - 1):
        a_fwd = calc_drive_accel(v_fwd[i])
        v_next_sq = v_fwd[i]**2 + 2.0 * a_fwd * ds
        v_fwd[i+1] = min(math.sqrt(max(0.0, v_next_sq)), v_max_curve[i+1])

    # 2. Backward Pass
    v_bwd = np.zeros(N2)
    v_bwd[-1] = v_fwd[-1]
    for i in range(N2 - 1, 0, -1):
        a_bwd = calc_brake_accel(v_bwd[i])
        v_prev_sq = v_bwd[i]**2 + 2.0 * a_bwd * ds
        v_bwd[i-1] = min(math.sqrt(max(0.0, v_prev_sq)), v_max_curve[i-1])

    v_prof_2lap = np.minimum(v_fwd, v_bwd)
    v_prof_2lap = np.maximum(v_prof_2lap, 0.05)

    v_std = v_prof_2lap[:N]
    v_fly = v_prof_2lap[N:]

    def analyze(v_prof):
        dt = ds / v_prof
        t_lap = np.sum(dt)

        current_arr = np.zeros(N)
        power_arr = np.zeros(N)
        copper_loss_arr = np.zeros(N)
        tau_m_arr = np.zeros(N)
        belt_ft_arr = np.zeros(N)
        belt_sf_arr = np.zeros(N)

        for i in range(N):
            v = v_prof[i]
            omega_w = v / r_w
            omega_m = omega_w * ratio
            eb = omega_m * ke

            if i < N - 1:
                a_req = (v_prof[i+1]**2 - v_prof[i]**2) / (2.0 * ds)
            else:
                a_req = 0.0

            if a_req > 0.01:
                f_req = a_req * m_eff + 0.03 * mass_kg * g + 0.5 * 1.2 * 0.03 * (v**2)
                tau_axle_req = f_req * r_w
                tau_m_req = tau_axle_req / (ratio * 0.97)
                i_req = tau_m_req / kt + i0
                i_m = min(80.0, max(0.0, min(i_req, (v_oc - eb) / r_tot)))
                tau_m = max(0.0, kt * (i_m - i0))
            else:
                i_m = 0.0
                tau_m = 0.0

            current_arr[i] = i_m
            v_load = v_oc - i_m * r_bat
            power_arr[i] = v_load * i_m
            copper_loss_arr[i] = (i_m**2) * rm
            tau_m_arr[i] = tau_m

            # Belt tension & shear
            ft = tau_m / r_pinion
            f_tooth = ft / max(1.0, tim)
            belt_ft_arr[i] = ft
            belt_sf_arr[i] = (f_shear_allowable_per_tooth / max(0.01, f_tooth)) if ft > 0.1 else 10.0

        mah_lap = np.sum(current_arr * dt) / 3.6
        energy_j = np.sum(power_arr * dt)
        avg_power = energy_j / t_lap
        avg_copper_heat = np.sum(copper_loss_arr * dt) / t_lap

        # Sector Times
        sector_times = []
        sector_vmax = []
        for k in range(len(SEC_BOUNDS) - 1):
            mask = (s_single >= SEC_BOUNDS[k]) & (s_single < SEC_BOUNDS[k+1])
            sector_times.append(np.sum(dt[mask]))
            sector_vmax.append(np.max(v_prof[mask]) * 3.6)

        return {
            'v_kmh': v_prof * 3.6,
            't_lap': t_lap,
            'sector_times': sector_times,
            'sector_vmax': sector_vmax,
            'mah_lap': mah_lap,
            'avg_power': avg_power,
            'avg_heat': avg_copper_heat,
            'peak_amps': np.max(current_arr),
            'top_speed_kmh': np.max(v_prof) * 3.6,
            'peak_tau_m': np.max(tau_m_arr),
            'current_arr': current_arr,
            'power_arr': power_arr,
            'belt_ft_arr': belt_ft_arr,
            'belt_sf_arr': belt_sf_arr,
            'tim': tim,
            'phi_wrap_deg': phi_wrap_deg,
            'f_shear_allowable': f_shear_allowable_per_tooth
        }

    return {
        's': s_single,
        'std': analyze(v_std),
        'fly': analyze(v_fly)
    }

# =============================================================================
# GUI SETUP (MATPLOTLIB)
# =============================================================================
fig = plt.figure(figsize=(19, 10.2), facecolor='#111317')
fig.canvas.manager.set_window_title('Timeline 1 Full Race Track Powertrain Simulator (1400KV vs 1000KV)')

# Grid Layout:
# Left Column: Track 2D Map (top) & GT2 Belt Telemetry (bottom)
# Middle Column: Velocity Profile (top) & Electrical Power / Current (bottom)
# Right Column: Interactive Sliders & Telemetry Dashboard

ax_track  = fig.add_axes([0.05, 0.53, 0.30, 0.42], facecolor='#181a20')
ax_belt   = fig.add_axes([0.05, 0.08, 0.30, 0.38], facecolor='#181a20')
ax_vel    = fig.add_axes([0.38, 0.53, 0.35, 0.42], facecolor='#181a20')
ax_power  = fig.add_axes([0.38, 0.08, 0.35, 0.38], facecolor='#181a20')
ax_hud    = fig.add_axes([0.76, 0.50, 0.22, 0.45], facecolor='#15171d')
ax_hud.axis('off')

# Style subplots
for ax in [ax_track, ax_belt, ax_vel, ax_power]:
    ax.tick_params(colors='#8e9297', labelsize=8)
    for spine in ax.spines.values():
        spine.set_color('#2e333d')

# -----------------------------------------------------------------------------
# BUTTONS AT TOP RIGHT
# -----------------------------------------------------------------------------
ax_btn_1400  = fig.add_axes([0.76, 0.955, 0.068, 0.032])
ax_btn_1000  = fig.add_axes([0.835, 0.955, 0.068, 0.032])
ax_btn_over  = fig.add_axes([0.910, 0.955, 0.075, 0.032])

btn_1400 = Button(ax_btn_1400, '1400KV (4:1)', color='#232730', hovercolor='#303644')
btn_1000 = Button(ax_btn_1000, '1000KV (3:1)', color='#232730', hovercolor='#303644')
btn_over = Button(ax_btn_over, 'Overlay Both', color='#1e3a5f', hovercolor='#2a5286')

for btn in [btn_1400, btn_1000, btn_over]:
    btn.label.set_fontsize(8)
    btn.label.set_color('#00ffcc')

# -----------------------------------------------------------------------------
# SLIDERS (LOWER RIGHT PANEL)
# -----------------------------------------------------------------------------
slider_defs = [
    ('mass',     'Total Mass (g)',        400.0, 900.0,  DEFAULT_MASS_KG * 1000.0, '%.0f g'),
    ('kv',       'Motor KV (RPM/V)',      800.0, 1800.0, DEFAULT_KV,               '%.0f KV'),
    ('voc',      '2S LiPo Voltage (V)',   6.8,   8.4,    DEFAULT_VOC,              '%.2f V'),
    ('z1',       'Pinion Teeth (Z1)',     12.0,  26.0,   DEFAULT_Z1,               '%.0f T'),
    ('z2',       'Spur Teeth (Z2)',       40.0,  80.0,   DEFAULT_Z2,               '%.0f T'),
    ('mu',       'Tire Grip (mu)',        0.60,  1.10,   DEFAULT_MUTIRE,           '%.2f'),
    ('dtire',    'Tire Dia (mm)',         50.0,  75.0,   DEFAULT_DTIRE_MM,         '%.1f mm'),
    ('rear_wt',  'Rear Wt Dist (%)',      50.0,  80.0,   DEFAULT_REAR_WT * 100.0,  '%.0f %%'),
    ('belt_w',   'GT2 Belt Width (mm)',   4.0,   10.0,   DEFAULT_BELTW_MM,         '%.0f mm'),
    ('cdist',    'Center Distance (mm)',  35.0,  75.0,   DEFAULT_CDIST_MM,         '%.0f mm'),
]

sliders = {}
y_pos = 0.42
for key, label, val_min, val_max, val_init, val_fmt in slider_defs:
    ax_s = fig.add_axes([0.81, y_pos, 0.17, 0.020], facecolor='#1a1d24')
    sl = Slider(ax_s, label, val_min, val_max, valinit=val_init, valstep=None, valfmt=val_fmt)
    sl.label.set_fontsize(7.5)
    sl.label.set_color('#c0c4cc')
    sl.valtext.set_fontsize(7.5)
    sl.valtext.set_color('#00ffcc')
    sliders[key] = sl
    y_pos -= 0.033

# Button: Idler Snubber Toggle & Lap Mode Toggle
ax_btn_idler = fig.add_axes([0.76, 0.040, 0.105, 0.028])
ax_btn_lap   = fig.add_axes([0.875, 0.040, 0.110, 0.028])
btn_idler = Button(ax_btn_idler, 'Idler: ON (210°)', color='#1e3a2f', hovercolor='#2a5242')
btn_lap   = Button(ax_btn_lap,   'Mode: Flying Lap', color='#232730', hovercolor='#303644')
btn_idler.label.set_fontsize(8)
btn_idler.label.set_color('#00ffcc')
btn_lap.label.set_fontsize(8)
btn_lap.label.set_color('#ffd700')

# =============================================================================
# UPDATE FUNCTION (INSTANTANEOUS REAL-TIME)
# =============================================================================
def update(val=None):
    mass_kg    = sliders['mass'].val / 1000.0
    kv         = sliders['kv'].val
    v_oc       = sliders['voc'].val
    z1         = int(round(sliders['z1'].val))
    z2         = int(round(sliders['z2'].val))
    mu         = sliders['mu'].val
    dtire_mm   = sliders['dtire'].val
    rear_wt    = sliders['rear_wt'].val / 100.0
    belt_w_mm  = sliders['belt_w'].val
    cdist_mm   = sliders['cdist'].val

    # 1. Primary Simulation (Current Slider Set)
    res_primary = solve_full_track(
        mass_kg, kv, v_oc, z1, z2, dtire_mm, mu, rear_wt, belt_w_mm, cdist_mm, state['has_idler']
    )

    # 2. Benchmark Set for Head-to-Head Comparison (1000KV with 20T:60T)
    res_bench = solve_full_track(
        mass_kg, 1000.0, v_oc, 20, 60, dtire_mm, mu, rear_wt, belt_w_mm, cdist_mm, state['has_idler']
    )

    lap_key = 'fly' if state['flying_lap'] else 'std'
    dat_prim = res_primary[lap_key]
    dat_bench = res_bench[lap_key]
    s_axis = res_primary['s']

    # -------------------------------------------------------------------------
    # PLOT 1: 2D RACE TRACK SPEED HEATMAP
    # -------------------------------------------------------------------------
    ax_track.cla()
    ax_track.set_title('Team Oorja Track (12.0m x 7.4m) Speed Map', color='#00ffcc', fontsize=9, fontweight='bold')
    ax_track.set_facecolor('#14161a')
    ax_track.set_aspect('equal')
    ax_track.set_xlim(-0.5, 12.5)
    ax_track.set_ylim(-0.5, 8.0)
    ax_track.set_xlabel('Track X [meters]', color='#8e9297', fontsize=7.5)
    ax_track.set_ylabel('Track Y [meters]', color='#8e9297', fontsize=7.5)
    ax_track.grid(True, linestyle=':', color='#262a33', alpha=0.7)

    # Plot track outer/inner boundary (0.6m track width)
    ax_track.plot(TRACK_X_2D, TRACK_Y_2D, color='#2e333d', linewidth=14, zorder=1)
    ax_track.plot(TRACK_X_2D, TRACK_Y_2D, color='#14161a', linewidth=10, zorder=2)

    # Color segments by speed
    points = np.array([TRACK_X_2D, TRACK_Y_2D]).T.reshape(-1, 1, 2)
    segments = np.concatenate([points[:-1], points[1:]], axis=1)
    norm = plt.Normalize(10.0, 35.0)
    # interpolate speed onto 600 track pts
    v_interp = np.interp(TRACK_S_2D, s_axis, dat_prim['v_kmh'])
    lc = LineCollection(segments, cmap='turbo', norm=norm, linewidth=3.5, zorder=3)
    lc.set_array(v_interp[:-1])
    ax_track.add_collection(lc)

    # Annotate key locations
    ax_track.plot(3.5, 1.0, marker='>', color='#00ffcc', markersize=8, zorder=5)
    ax_track.text(3.5, 0.4, 'START/FINISH', color='#00ffcc', fontsize=6.5, fontweight='bold', ha='center')
    ax_track.text(10.5, 2.0, 'T1 (1.0m)', color='#ff9900', fontsize=6.5, ha='left')
    ax_track.text(4.5, 4.0, 'T2 (1.0m)', color='#ff9900', fontsize=6.5, ha='right')
    ax_track.text(9.5, 6.0, 'T3 (1.0m)', color='#ff9900', fontsize=6.5, ha='left')
    ax_track.text(1.7, 4.0, 'T4 Sweeper\n(R=3.0m)', color='#00e5ff', fontsize=6.5, ha='center')

    # -------------------------------------------------------------------------
    # PLOT 2: VELOCITY PROFILE V(S)
    # -------------------------------------------------------------------------
    ax_vel.cla()
    ax_vel.set_title(f'Lap Velocity Profile v(s) ({"Flying Lap" if state["flying_lap"] else "Standing Start"})',
                     color='#00ffcc', fontsize=9, fontweight='bold')
    ax_vel.set_facecolor('#181a20')
    ax_vel.set_xlim(0, LAP_LENGTH)
    ax_vel.set_ylim(0, 42)
    ax_vel.set_xlabel('Lap Distance [meters]', color='#8e9297', fontsize=7.5)
    ax_vel.set_ylabel('Velocity [km/h]', color='#8e9297', fontsize=7.5)
    ax_vel.grid(True, linestyle=':', color='#2e333d')

    # Sector shading & vertical boundaries
    for b in SEC_BOUNDS:
        ax_vel.axvline(b, color='#2e333d', linestyle='--', linewidth=0.8)

    # Corner apex speed limits
    ax_vel.axhline(10.99, color='#ff9900', linestyle=':', linewidth=1.2, label='Hairpin Apex Limit (11 km/h)')
    ax_vel.axhline(19.04, color='#00e5ff', linestyle=':', linewidth=1.2, label='Sweeper Apex Limit (19 km/h)')

    # Primary Curve
    label_prim = f'Current: {kv:.0f}KV ({z1}:{z2}) - {dat_prim["t_lap"]:.3f}s'
    ax_vel.plot(s_axis, dat_prim['v_kmh'], color='#00ffcc', linewidth=2.0, label=label_prim)

    # Benchmark Curve
    if state['overlay_kv']:
        label_bench = f'Benchmark: 1000KV (20:60) - {dat_bench["t_lap"]:.3f}s'
        ax_vel.plot(s_axis, dat_bench['v_kmh'], color='#ff4d88', linewidth=1.8, linestyle='--', label=label_bench)

    ax_vel.legend(loc='lower right', fontsize=6.8, facecolor='#15171d', edgecolor='#2e333d', labelcolor='#c0c4cc')

    # -------------------------------------------------------------------------
    # PLOT 3: GT2 BELT MECHANICS & TOOTH SAFETY FACTOR
    # -------------------------------------------------------------------------
    ax_belt.cla()
    ax_belt.set_title(f'GT2 Belt Tooth Safety Factor (TIM={dat_prim["tim"]:.1f} teeth, Wrap={dat_prim["phi_wrap_deg"]:.0f}°)',
                      color='#00ffcc', fontsize=9, fontweight='bold')
    ax_belt.set_facecolor('#181a20')
    ax_belt.set_xlim(0, LAP_LENGTH)
    ax_belt.set_ylim(0, 10)
    ax_belt.set_xlabel('Lap Distance [meters]', color='#8e9297', fontsize=7.5)
    ax_belt.set_ylabel('Tooth Shear Safety Factor', color='#8e9297', fontsize=7.5)
    ax_belt.grid(True, linestyle=':', color='#2e333d')

    # Failure Threshold Line at SF = 1.0
    ax_belt.axhline(1.0, color='#ff3344', linestyle='-', linewidth=1.5, label='Ratcheting Risk (SF < 1.0)')
    ax_belt.axhline(2.5, color='#ffd700', linestyle=':', linewidth=1.0, label='Recommended Safe (SF > 2.5)')

    ax_belt.plot(s_axis, dat_prim['belt_sf_arr'], color='#00ffcc', linewidth=1.8, label=f'Current {kv:.0f}KV')
    if state['overlay_kv']:
        ax_belt.plot(s_axis, dat_bench['belt_sf_arr'], color='#ff4d88', linewidth=1.6, linestyle='--', label='1000KV (20T:60T)')

    ax_belt.legend(loc='lower right', fontsize=6.8, facecolor='#15171d', edgecolor='#2e333d', labelcolor='#c0c4cc')

    # -------------------------------------------------------------------------
    # PLOT 4: ELECTRICAL POWER & CURRENT DRAIN
    # -------------------------------------------------------------------------
    ax_power.cla()
    ax_power.set_title('Powertrain Electrical Draw (Current & Power Profile)', color='#00ffcc', fontsize=9, fontweight='bold')
    ax_power.set_facecolor('#181a20')
    ax_power.set_xlim(0, LAP_LENGTH)
    ax_power.set_ylim(0, 80)
    ax_power.set_xlabel('Lap Distance [meters]', color='#8e9297', fontsize=7.5)
    ax_power.set_ylabel('Motor Current [Amps]', color='#8e9297', fontsize=7.5)
    ax_power.grid(True, linestyle=':', color='#2e333d')

    ax_power.plot(s_axis, dat_prim['current_arr'], color='#ffd700', linewidth=1.8, label=f'{kv:.0f}KV Current (Peak: {dat_prim["peak_amps"]:.1f}A)')
    if state['overlay_kv']:
        ax_power.plot(s_axis, dat_bench['current_arr'], color='#ff4d88', linewidth=1.6, linestyle='--', label=f'1000KV Current (Peak: {dat_bench["peak_amps"]:.1f}A)')

    ax_power.legend(loc='upper right', fontsize=6.8, facecolor='#15171d', edgecolor='#2e333d', labelcolor='#c0c4cc')

    # -------------------------------------------------------------------------
    # TELEMETRY HUD & SECTOR BREAKDOWN (RIGHT PANEL)
    # -------------------------------------------------------------------------
    ax_hud.cla()
    ax_hud.axis('off')

    t_lap_prim  = dat_prim['t_lap']
    t_std_prim  = res_primary['std']['t_lap']
    t8_prim     = t_std_prim + 7.0 * res_primary['fly']['t_lap']
    mah_8_prim  = res_primary['std']['mah_lap'] + 7.0 * res_primary['fly']['mah_lap']

    t_lap_bench = dat_bench['t_lap']
    t_std_bench = res_bench['std']['t_lap']
    t8_bench    = t_std_bench + 7.0 * res_bench['fly']['t_lap']
    mah_8_bench = res_bench['std']['mah_lap'] + 7.0 * res_bench['fly']['mah_lap']

    hud_text = (
        f"TIMELINE 1 FULL-TRACK TELEMETRY HUD\n"
        f"=========================================\n"
        f"Setup: 1x Motor + 80A ESC + 8mm Solid Axle\n"
        f"Vehicle Mass: {mass_kg*1000:.0f}g | Pack: {v_oc:.1f}V (2S LiPo)\n\n"
        f"{'METRIC':<18s} | {'CURRENT':<10s} | {'1000KV BENCH'}\n"
        f"-----------------------------------------\n"
        f"{'Motor Rating':<18s} | {kv:.0f} KV     | 1000 KV\n"
        f"{'GT2 Gearing':<18s} | {z1}T:{z2}T ({z2/z1:.2f}:1) | 20T:60T (3:1)\n"
        f"{'Flying Lap Time':<18s} | {dat_prim['t_lap']:5.3f} s    | {dat_bench['t_lap']:5.3f} s\n"
        f"{'Standing Lap 1':<18s} | {t_std_prim:5.3f} s    | {t_std_bench:5.3f} s\n"
        f"{'8-Lap Race Time':<18s} | {t8_prim:5.2f} s    | {t8_bench:5.2f} s\n"
        f"{'8-Lap Minutes':<18s} | {t8_prim/60:5.2f} min  | {t8_bench/60:5.2f} min\n"
        f"{'Straight Top Speed':<18s} | {dat_prim['top_speed_kmh']:5.1f} km/h | {dat_bench['top_speed_kmh']:5.1f} km/h\n"
        f"{'Peak Accel Amps':<18s} | {dat_prim['peak_amps']:5.1f} A    | {dat_bench['peak_amps']:5.1f} A\n"
        f"{'Avg Power (W)':<18s} | {dat_prim['avg_power']:5.1f} W    | {dat_bench['avg_power']:5.1f} W\n"
        f"{'8-Lap Drain (mAh)':<18s} | {mah_8_prim:5.1f} mAh  | {mah_8_bench:5.1f} mAh\n"
        f"{'Pack Capacity %':<18s} | {mah_8_prim/2200*100:5.1f} %    | {mah_8_bench/2200*100:5.1f} %\n"
        f"{'Belt Teeth in Mesh':<18s} | {dat_prim['tim']:5.1f} T    | {dat_bench['tim']:5.1f} T\n"
        f"{'Min Belt Safety SF':<18s} | {np.min(dat_prim['belt_sf_arr']):5.2f} x    | {np.min(dat_bench['belt_sf_arr']):5.2f} x\n"
        f"-----------------------------------------\n"
        f"SECTOR BREAKDOWN (FLYING LAP):\n"
    )

    for i in range(len(SEC_NAMES)):
        t_c = dat_prim['sector_times'][i]
        t_b = dat_bench['sector_times'][i]
        diff = t_c - t_b
        hud_text += f"S{i+1} {SEC_NAMES[i][:15]:<15s}: {t_c:5.3f}s | {t_b:5.3f}s ({diff:+.3f}s)\n"

    ax_hud.text(0.02, 0.98, hud_text, transform=ax_hud.transAxes, color='#c0c4cc',
                fontsize=7.2, fontfamily='monospace', verticalalignment='top',
                bbox=dict(boxstyle='round,pad=0.5', facecolor='#181a20', edgecolor='#2e333d', alpha=0.9))

    fig.canvas.draw_idle()

# Connect sliders
for sl in sliders.values():
    sl.on_changed(update)

# Button Callbacks
def set_preset_1400(event):
    sliders['kv'].set_val(1400.0)
    sliders['z1'].set_val(16.0)
    sliders['z2'].set_val(64.0)

def set_preset_1000(event):
    sliders['kv'].set_val(1000.0)
    sliders['z1'].set_val(20.0)
    sliders['z2'].set_val(60.0)

def toggle_overlay(event):
    state['overlay_kv'] = not state['overlay_kv']
    btn_over.color = '#1e3a5f' if state['overlay_kv'] else '#232730'
    update()

def toggle_idler(event):
    state['has_idler'] = not state['has_idler']
    if state['has_idler']:
        btn_idler.label.set_text('Idler: ON (210°)')
        btn_idler.color = '#1e3a2f'
    else:
        btn_idler.label.set_text('Idler: OFF (144°)')
        btn_idler.color = '#3a1e24'
    update()

def toggle_lap(event):
    state['flying_lap'] = not state['flying_lap']
    if state['flying_lap']:
        btn_lap.label.set_text('Mode: Flying Lap')
        btn_lap.label.set_color('#ffd700')
    else:
        btn_lap.label.set_text('Mode: Standing Start')
        btn_lap.label.set_color('#00e5ff')
    update()

btn_1400.on_clicked(set_preset_1400)
btn_1000.on_clicked(set_preset_1000)
btn_over.on_clicked(toggle_overlay)
btn_idler.on_clicked(toggle_idler)
btn_lap.on_clicked(toggle_lap)

# Initial render
update()

if __name__ == '__main__':
    print("Launching Timeline 1 Full Race Track Powertrain Simulator GUI...")
    plt.show()
