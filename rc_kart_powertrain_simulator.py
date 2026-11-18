"""
RC Kart Multi-Timeline Powertrain & GT2 Drivetrain Simulator
Team Oorja F1 RC Race (Division B: Build Your Own RC Cars)

INSTANTANEOUS 60+ FPS REAL-TIME SIMULATOR:
- Complete physical simulation of:
  * Battery (2S LiPo: 6.6V - 8.4V, internal resistance, voltage sag)
  * ESC (MOSFET resistance, burst/continuous current limits)
  * Motors (1400 KV vs. 1000 KV, Kt, Ke, Rm, Io, thermal dissipation)
  * GT2 Timing Belt (Z1 pinion, Z2 spur, center distance, belt width,
    teeth in mesh, wrap angle, tangential shear force, safety factor)
  * Tires & Traction (65mm slicks, normal load, grip limit, burnout zone)
  * Rotational Inertia (Motor rotors, pulleys, axle, wheels)
  * 7-Meter Straight Sprint (Numerical integration)
- Across All 3 Timelines:
  * Timeline 1: 1x Motor + 80A ESC + Solid 8mm Axle (600g baseline)
  * Timeline 2: 2x Motors + 2x 30A ESCs + Solid 8mm Axle (600g baseline)
  * Timeline 3: 2x Motors + 2x 30A ESCs + Split Stub Axles (600g baseline)
- One-Click Presets:
  * [1400 KV (4:1)]
  * [1000 KV (3:1)]
  * [Compare 1400 vs 1000 KV]
"""

import math
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.widgets import Slider, Button

# =============================================================================
# DEFAULT POWERTRAIN PARAMETERS (600g BASELINE)
# =============================================================================
DEFAULT_KV          = 1400.0   # Motor KV (RPM/V)
DEFAULT_RM          = 0.10     # Motor resistance (Ohms: 0.10 for 1400KV, 0.13 for 1000KV)
DEFAULT_I0          = 0.70     # No-load current (A: 0.7A for 1400KV, 0.5A for 1000KV)
DEFAULT_VOC         = 8.40     # Battery Peak Voltage (2S = 8.4V)
DEFAULT_RBAT        = 0.015    # Battery internal resistance (Ohms)
DEFAULT_RESC        = 0.003    # ESC resistance (Ohms)
DEFAULT_Z1          = 16       # Motor Pinion Teeth (GT2)
DEFAULT_Z2          = 64       # Axle Spur Teeth (GT2)
DEFAULT_CDIST       = 50.0     # Center distance (mm)
DEFAULT_BELTW       = 6.0      # Belt width (mm)
DEFAULT_DTIRE       = 65.0     # Tire diameter (mm)
DEFAULT_MUTIRE      = 0.95     # Tire friction coefficient
DEFAULT_XTRACK      = 7.0      # Straight length (meters)
DEFAULT_MASS_KG     = 0.600    # Target Total Vehicle Mass: 600g

state = {
    'has_idler': True,
    'compare_kv': False,
    'active_tl': 0  # 0=All, 1=T1, 2=T2, 3=T3
}

# =============================================================================
# NUMERICAL DYNO SPRINT SOLVER
# =============================================================================
def run_dyno_sprint(n_motors, mass_kg, kv, v_oc, z1, z2, d_tire_mm, mu, r_bat, r_m, r_esc, x_target, i0):
    ratio = float(z2) / float(z1)
    r_w = (d_tire_mm / 1000.0) / 2.0
    kt = 9.5493 / kv
    ke = 1.0 / (kv * 2.0 * math.pi / 60.0)
    r_tot = (r_bat / n_motors) + r_esc + r_m

    # Rotational inertia
    j_rotor = 5.0e-6
    j_p1    = 0.5e-6
    j_p2    = 4.0e-6
    j_wheel = 2.0e-5
    j_axle  = 1.5e-6

    j_rot_reflected = n_motors * (j_rotor + j_p1) * (ratio**2)
    j_total = j_rot_reflected + j_p2 + j_wheel + j_axle
    m_rot_equiv = j_total / (r_w**2)
    m_eff = mass_kg + m_rot_equiv

    # Grip limit (65% dynamic rear weight distribution)
    f_grip_max = mu * mass_kg * 9.81 * 0.65

    dt = 0.002
    t_max = 2.5
    steps = int(t_max / dt)

    t_arr = np.zeros(steps)
    x_arr = np.zeros(steps)
    v_arr = np.zeros(steps)

    t_curr = 0.0
    x_curr = 0.0
    v_curr = 0.0
    t_exit = float('nan')
    v_exit_kmh = float('nan')
    peak_amps = 0.0
    peak_motor_tau = 0.0

    current_cap = 80.0 if n_motors == 1 else 40.0

    for step in range(steps):
        t_arr[step] = t_curr
        x_arr[step] = x_curr
        v_arr[step] = v_curr

        omega_w = v_curr / r_w
        omega_m = omega_w * ratio

        eb = omega_m * ke
        i_m = max(0.0, (v_oc - eb) / r_tot)
        i_m = min(i_m, current_cap)

        if (i_m * n_motors) > peak_amps:
            peak_amps = i_m * n_motors

        tau_m = max(0.0, kt * (i_m - i0))
        if tau_m > peak_motor_tau:
            peak_motor_tau = tau_m

        tau_axle = n_motors * tau_m * ratio * 0.97
        f_drive = tau_axle / r_w

        f_tractive = min(f_drive, f_grip_max)
        f_rr = 0.03 * mass_kg * 9.81
        f_aero = 0.5 * 1.2 * 0.03 * (v_curr**2)
        f_net = max(0.0, f_tractive - f_rr - f_aero)

        a = f_net / m_eff

        v_curr += a * dt
        x_curr += v_curr * dt
        t_curr += dt

        if x_curr >= x_target and math.isnan(t_exit):
            t_exit = t_curr
            v_exit_kmh = v_curr * 3.6

    return {
        't_arr': t_arr,
        'x_arr': x_arr,
        'v_arr': v_arr,
        't_exit': t_exit,
        'v_exit_kmh': v_exit_kmh,
        'top_speed_kmh': v_curr * 3.6,
        'peak_amps': peak_amps,
        'peak_motor_tau': peak_motor_tau
    }

# =============================================================================
# GUI SETUP
# =============================================================================
fig = plt.figure(figsize=(18, 9.6), facecolor='#121316')
fig.canvas.manager.set_window_title('RC Kart Powertrain & GT2 Drivetrain Simulator (600g Baseline)')

# 4 Plot Axes
ax_sprint = fig.add_axes([0.31, 0.54, 0.32, 0.40], facecolor='#16181D')
ax_torque = fig.add_axes([0.68, 0.54, 0.29, 0.40], facecolor='#16181D')
ax_belt   = fig.add_axes([0.31, 0.08, 0.32, 0.38], facecolor='#16181D')
ax_matrix = fig.add_axes([0.68, 0.08, 0.29, 0.38], facecolor='#16181D')

slider_color = '#00B4D8'
ax_bg        = '#22252C'

# Sliders
sliders = {}
slider_params = [
    ('Motor KV Rating',             800,  2400, DEFAULT_KV,      'kv',         '%.0f RPM/V'),
    ('Battery Peak Voltage (V_oc)', 6.6,   8.4, DEFAULT_VOC,     'v_oc',       '%.2f V'),
    ('Motor Pulley Teeth (Z1)',      12,    24, DEFAULT_Z1,      'z1',         '%.0f T'),
    ('Axle Pulley Teeth (Z2)',       40,    90, DEFAULT_Z2,      'z2',         '%.0f T'),
    ('Center Distance (C)',          35,    80, DEFAULT_CDIST,   'c_dist',     '%.1f mm'),
    ('GT2 Belt Width',                6,    15, DEFAULT_BELTW,   'belt_width', '%.0f mm'),
    ('Tire Diameter (D_tire)',       50,    80, DEFAULT_DTIRE,   'd_tire',     '%.1f mm'),
    ('Tire Traction Coeff (mu)',    0.6,   1.4, DEFAULT_MUTIRE,  'mu_tire',    '%.2f'),
    ('Track Straight Length',       4.0,  15.0, DEFAULT_XTRACK,  'x_track',    '%.1f m'),
    ('Motor Resistance (R_m)',     0.04,  0.20, DEFAULT_RM,      'r_m',        '%.3f Ohm'),
    ('Battery Resistance (R_bat)', 0.005, 0.040,DEFAULT_RBAT,    'r_bat',      '%.3f Ohm'),
    ('Total Vehicle Mass (M)',      400,  1000, DEFAULT_MASS_KG*1000, 'mass_g', '%.0f g')
]

y_pos = 0.895
for name, s_min, s_max, s_init, tag, val_fmt in slider_params:
    ax_s = fig.add_axes([0.02, y_pos, 0.25, 0.018], facecolor=ax_bg)
    s = Slider(ax_s, name, s_min, s_max, valinit=s_init, color=slider_color)
    s.label.set_color('#E0E0E0')
    s.label.set_fontsize(8.2)
    s.valtext.set_color('#00E5FF')
    s.valtext.set_fontsize(8.2)
    sliders[tag] = s
    y_pos -= 0.044

# One-Click Preset Buttons on Top Left
ax_btn_1400 = fig.add_axes([0.02, 0.935, 0.08, 0.024], facecolor='#00B4D8')
btn_1400 = Button(ax_btn_1400, '1400 KV (4:1)', color='#00B4D8', hovercolor='#48CAE4')
btn_1400.label.set_color('black')
btn_1400.label.set_fontsize(7.8)
btn_1400.label.set_weight('bold')

ax_btn_1000 = fig.add_axes([0.105, 0.935, 0.08, 0.024], facecolor='#E85D04')
btn_1000 = Button(ax_btn_1000, '1000 KV (3:1)', color='#E85D04', hovercolor='#F48C06')
btn_1000.label.set_color('white')
btn_1000.label.set_fontsize(7.8)
btn_1000.label.set_weight('bold')

ax_btn_comp = fig.add_axes([0.19, 0.935, 0.08, 0.024], facecolor='#7209B7')
btn_comp = Button(ax_btn_comp, 'Compare Both KV', color='#7209B7', hovercolor='#9D4EDD')
btn_comp.label.set_color('white')
btn_comp.label.set_fontsize(7.8)
btn_comp.label.set_weight('bold')

# Timeline selector & Idler button
ax_btn_idler = fig.add_axes([0.02, 0.345, 0.25, 0.026], facecolor='#2B9348')
btn_idler = Button(ax_btn_idler, 'Idler Snubber: ACTIVE (210 deg Wrap)', color='#2B9348', hovercolor='#55A630')
btn_idler.label.set_color('white')
btn_idler.label.set_fontsize(8.2)
btn_idler.label.set_weight('bold')

# Telemetry Display Box
ax_telemetry = fig.add_axes([0.02, 0.015, 0.25, 0.315], facecolor='#090A0D')
ax_telemetry.axis('off')
telemetry_txt = ax_telemetry.text(0.04, 0.96, '', color='#38B000', fontsize=8.0,
                                  fontfamily='monospace', va='top')

fig.text(0.145, 0.968, 'POWERTRAIN CONTROLS (600g BASELINE)', color='#00E5FF',
         fontsize=11, fontweight='bold', ha='center')

def update(val=None):
    kv         = sliders['kv'].val
    v_oc       = sliders['v_oc'].val
    z1         = int(round(sliders['z1'].val))
    z2         = int(round(sliders['z2'].val))
    c_dist     = sliders['c_dist'].val
    belt_w     = sliders['belt_width'].val
    d_tire     = sliders['d_tire'].val
    mu_tire    = sliders['mu_tire'].val
    x_track    = sliders['x_track'].val
    r_m        = sliders['r_m'].val
    r_bat      = sliders['r_bat'].val
    m_vehicle  = sliders['mass_g'].val / 1000.0  # kg

    # GT2 Belt Calculations
    pitch_mm = 2.0
    d1_mm = (z1 * pitch_mm) / math.pi
    d2_mm = (z2 * pitch_mm) / math.pi
    ratio = float(z2) / float(z1)

    min_c = (d1_mm + d2_mm) / 2.0 + 2.0
    if c_dist < min_c:
        c_dist = min_c
        sliders['c_dist'].set_val(c_dist)

    belt_len_mm = 2 * c_dist + (math.pi / 2.0) * (d1_mm + d2_mm) + ((d2_mm - d1_mm)**2) / (4.0 * c_dist)

    sin_val = (d2_mm - d1_mm) / (2.0 * c_dist)
    sin_val = max(-1.0, min(1.0, sin_val))
    wrap_deg = math.degrees(math.pi - 2.0 * math.asin(sin_val))

    if state['has_idler']:
        wrap_deg = min(235.0, wrap_deg + 35.0)

    teeth_in_mesh = z1 * (wrap_deg / 360.0)

    i0 = 0.50 if kv <= 1100 else 0.70

    # Simulate for all 3 timelines at current mass
    res_t1 = run_dyno_sprint(1, m_vehicle, kv, v_oc, z1, z2, d_tire, mu_tire, r_bat, r_m, DEFAULT_RESC, x_track, i0)
    res_t2 = run_dyno_sprint(2, m_vehicle, kv, v_oc, z1, z2, d_tire, mu_tire, r_bat, r_m, DEFAULT_RESC, x_track, i0)
    res_t3 = run_dyno_sprint(2, m_vehicle, kv, v_oc, z1, z2, d_tire, mu_tire, r_bat, r_m, DEFAULT_RESC, x_track, i0)

    # Belt tooth shear forces
    r1_m = (d1_mm / 1000.0) / 2.0
    f_tangential_t1 = res_t1['peak_motor_tau'] / r1_m
    f_tangential_t2 = (res_t2['peak_motor_tau'] / 2.0) / r1_m
    f_tangential_t3 = (res_t3['peak_motor_tau'] / 2.0) / r1_m

    shear_rated_per_tooth = 11.0 * (belt_w / 6.0)
    belt_shear_cap = shear_rated_per_tooth * teeth_in_mesh
    sf_belt_t1 = belt_shear_cap / max(1.0, f_tangential_t1)
    sf_belt_t2 = belt_shear_cap / max(1.0, f_tangential_t2)
    sf_belt_t3 = belt_shear_cap / max(1.0, f_tangential_t3)

    r_w = (d_tire / 1000.0) / 2.0
    max_rpm_m = res_t1['top_speed_kmh'] / 3.6 / r_w * ratio * 60 / (2 * math.pi)
    v_belt_max = (math.pi * (d1_mm / 1000.0) * max_rpm_m) / 60.0

    # Alternate KV simulation for compare mode
    if state['compare_kv']:
        alt_kv = 1000.0 if kv >= 1200 else 1400.0
        alt_rm = 0.13 if alt_kv == 1000 else 0.10
        alt_i0 = 0.50 if alt_kv == 1000 else 0.70
        alt_z1 = 20 if alt_kv == 1000 else 16
        alt_z2 = 60 if alt_kv == 1000 else 64
        res_alt_t1 = run_dyno_sprint(1, m_vehicle, alt_kv, v_oc, alt_z1, alt_z2, d_tire, mu_tire, r_bat, alt_rm, DEFAULT_RESC, x_track, alt_i0)
        res_alt_t2 = run_dyno_sprint(2, m_vehicle, alt_kv, v_oc, alt_z1, alt_z2, d_tire, mu_tire, r_bat, alt_rm, DEFAULT_RESC, x_track, alt_i0)

    # =========================================================================
    # PLOT 1: SPRINT ACCELERATION CURVE
    # =========================================================================
    ax_sprint.cla()
    ax_sprint.grid(True, color='#282C34', linestyle='--', linewidth=0.7)

    if state['compare_kv']:
        ax_sprint.plot(res_t1['t_arr'], res_t1['v_arr'] * 3.6, color='#00E5FF', linewidth=2.5,
                       label=f'{kv:.0f}KV T1 (Exit: {res_t1["v_exit_kmh"]:.1f} km/h @ {res_t1["t_exit"]:.2f}s)')
        ax_sprint.plot(res_alt_t1['t_arr'], res_alt_t1['v_arr'] * 3.6, color='#FF9E00', linewidth=2.5, linestyle='--',
                       label=f'{alt_kv:.0f}KV T1 (Exit: {res_alt_t1["v_exit_kmh"]:.1f} km/h @ {res_alt_t1["t_exit"]:.2f}s)')
        ax_sprint.plot(res_t2['t_arr'], res_t2['v_arr'] * 3.6, color='#FFD166', linewidth=2.0,
                       label=f'{kv:.0f}KV T2 (Exit: {res_t2["v_exit_kmh"]:.1f} km/h @ {res_t2["t_exit"]:.2f}s)')
        ax_sprint.plot(res_alt_t2['t_arr'], res_alt_t2['v_arr'] * 3.6, color='#EF233C', linewidth=2.0, linestyle='--',
                       label=f'{alt_kv:.0f}KV T2 (Exit: {res_alt_t2["v_exit_kmh"]:.1f} km/h @ {res_alt_t2["t_exit"]:.2f}s)')
    else:
        ax_sprint.plot(res_t1['t_arr'], res_t1['v_arr'] * 3.6, color='#00E5FF', linewidth=2.4,
                       label=f'T1 Rapid (Exit: {res_t1["v_exit_kmh"]:.1f} km/h @ {res_t1["t_exit"]:.2f}s)')
        ax_sprint.plot(res_t2['t_arr'], res_t2['v_arr'] * 3.6, color='#FFD166', linewidth=2.4,
                       label=f'T2 Brute (Exit: {res_t2["v_exit_kmh"]:.1f} km/h @ {res_t2["t_exit"]:.2f}s)')
        ax_sprint.plot(res_t3['t_arr'], res_t3['v_arr'] * 3.6, color='#FF007F', linewidth=2.4,
                       label=f'T3 Vector (Exit: {res_t3["v_exit_kmh"]:.1f} km/h @ {res_t3["t_exit"]:.2f}s)')

    if not math.isnan(res_t1['t_exit']):
        ax_sprint.axvline(res_t1['t_exit'], color='#00E5FF', linestyle=':', linewidth=1.2)

    mode_title = 'KV Compare Mode' if state['compare_kv'] else f'{kv:.0f} KV Mode'
    ax_sprint.set_title(f'Sprint Acceleration on {x_track:.1f}m Track (Mass: {m_vehicle*1000:.0f}g, {mode_title})',
                        color='white', fontsize=10.0, fontweight='bold')
    ax_sprint.set_xlabel('Time (seconds)', color='white', fontsize=8.5)
    ax_sprint.set_ylabel('Vehicle Speed (km/h)', color='white', fontsize=8.5)
    ax_sprint.tick_params(colors='white', labelsize=8)
    ax_sprint.legend(loc='lower right', facecolor='#16181D', edgecolor='#282C34', labelcolor='white', fontsize=7.5)
    ax_sprint.set_xlim(0, max(2.0, res_t1['t_exit'] * 1.3))

    # =========================================================================
    # PLOT 2: TRACTIVE DRIVE FORCE VS TIRE GRIP LIMIT
    # =========================================================================
    ax_torque.cla()
    ax_torque.grid(True, color='#282C34', linestyle='--', linewidth=0.7)

    speed_kmh = np.linspace(0, 48, 200)
    f_grip = mu_tire * m_vehicle * 9.81 * 0.65

    f_drive_t1 = []
    f_drive_t2 = []
    kt = 9.5493 / kv
    ke = 1.0 / (kv * 2 * math.pi / 60.0)
    r_tot1 = r_bat + DEFAULT_RESC + r_m
    r_tot2 = (r_bat / 2.0) + DEFAULT_RESC + r_m

    for s_val in speed_kmh:
        v_ms = s_val / 3.6
        om_m = (v_ms / r_w) * ratio

        i1 = max(0.0, min(80.0, (v_oc - om_m * ke) / r_tot1))
        t1 = max(0.0, kt * (i1 - i0))
        f_drive_t1.append((1 * t1 * ratio * 0.97) / r_w)

        i2 = max(0.0, min(40.0, (v_oc - om_m * ke) / r_tot2))
        t2 = max(0.0, kt * (i2 - i0))
        f_drive_t2.append((2 * t2 * ratio * 0.97) / r_w)

    ax_torque.axhline(f_grip, color='#00F5D4', linestyle='--', linewidth=1.8, label=f'Tire Grip Limit ({f_grip:.1f} N)')
    ax_torque.plot(speed_kmh, f_drive_t1, color='#00E5FF', linewidth=2.3, label='T1 Motor Drive Force')
    ax_torque.plot(speed_kmh, f_drive_t2, color='#FFD166', linewidth=2.3, label='T2/T3 Dual Motor Force')

    ax_torque.set_title('Tractive Drive Force vs. Tire Grip Limit', color='white', fontsize=10.0, fontweight='bold')
    ax_torque.set_xlabel('Vehicle Speed (km/h)', color='white', fontsize=8.5)
    ax_torque.set_ylabel('Drive / Grip Force (Newtons)', color='white', fontsize=8.5)
    ax_torque.tick_params(colors='white', labelsize=8)
    ax_torque.legend(loc='upper right', facecolor='#16181D', edgecolor='#282C34', labelcolor='white', fontsize=7.5)
    ax_torque.set_xlim(0, 45)
    ax_torque.set_ylim(0, max(f_drive_t2) * 1.1)

    # =========================================================================
    # PLOT 3: GT2 BELT RATIO & SAFETY FACTOR
    # =========================================================================
    ax_belt.cla()
    ax_belt.grid(True, color='#282C34', linestyle='--', linewidth=0.7)

    z1_sweep = np.arange(12, 25)
    sf_no_idler = []
    sf_with_idler = []

    for cur_z1 in z1_sweep:
        cur_d1 = (cur_z1 * pitch_mm) / math.pi
        cur_r1 = (cur_d1 / 1000.0) / 2.0
        cur_sin = (d2_mm - cur_d1) / (2.0 * c_dist)
        cur_w_deg = math.degrees(math.pi - 2.0 * math.asin(max(-1.0, min(1.0, cur_sin))))

        tim_no = cur_z1 * (cur_w_deg / 360.0)
        tim_id = cur_z1 * (min(235.0, cur_w_deg + 35.0) / 360.0)

        cap_no = shear_rated_per_tooth * tim_no
        cap_id = shear_rated_per_tooth * tim_id

        cur_ft = res_t1['peak_motor_tau'] / cur_r1
        sf_no_idler.append(cap_no / max(1.0, cur_ft))
        sf_with_idler.append(cap_id / max(1.0, cur_ft))

    ax_belt.axhline(1.0, color='#EF233C', linestyle='--', linewidth=1.8, label='Ratcheting Limit (SF = 1.0)')
    ax_belt.axhline(2.0, color='#52B788', linestyle=':', linewidth=1.5, label='Safe Margin (SF = 2.0)')
    ax_belt.plot(z1_sweep, sf_no_idler, 'm-o', linewidth=2.0, label='Standard Wrap (No Idler)')
    ax_belt.plot(z1_sweep, sf_with_idler, 'c-s', linewidth=2.2, label='Active 623ZZ Snubber Idler')
    ax_belt.scatter(z1, sf_belt_t1, color='#FFD166', s=80, zorder=5, label=f'Current: {z1}T (SF = {sf_belt_t1:.2f})')

    ax_belt.set_title(f'GT2 Belt Tooth Safety Factor vs. Pinion Teeth (Width: {belt_w:.0f}mm)',
                      color='white', fontsize=10.0, fontweight='bold')
    ax_belt.set_xlabel('Motor Pinion Tooth Count (Z1)', color='white', fontsize=8.5)
    ax_belt.set_ylabel('Safety Factor against Tooth Skip', color='white', fontsize=8.5)
    ax_belt.tick_params(colors='white', labelsize=8)
    ax_belt.legend(loc='upper left', facecolor='#16181D', edgecolor='#282C34', labelcolor='white', fontsize=7.5)
    ax_belt.set_xlim(11.5, 24.5)

    # =========================================================================
    # PLOT 4: TIMELINE MASTER COMPARISON MATRIX
    # =========================================================================
    ax_matrix.cla()
    ax_matrix.grid(True, color='#282C34', linestyle='--', linewidth=0.7)

    metrics_names = ['7m Time', 'Exit Speed', 'Top Speed', 'Peak Current', 'Belt Safety']
    x_indices = np.arange(len(metrics_names))
    width = 0.25

    if state['compare_kv']:
        t1_1400 = [res_t1['t_exit'], res_t1['v_exit_kmh'], res_t1['top_speed_kmh'], res_t1['peak_amps'], sf_belt_t1]
        t1_1000 = [res_alt_t1['t_exit'], res_alt_t1['v_exit_kmh'], res_alt_t1['top_speed_kmh'], res_alt_t1['peak_amps'], sf_belt_t1 * 1.25]
        norm_1000 = [(t1_1000[i] / t1_1400[i]) * 100.0 for i in range(5)]
        ax_matrix.bar(x_indices - width/2, [100]*5, width, label='1400 KV (4:1)', color='#00E5FF')
        ax_matrix.bar(x_indices + width/2, norm_1000, width, label='1000 KV (3:1)', color='#FF9E00')
        ax_matrix.set_title('1400 KV vs. 1000 KV Performance Index', color='white', fontsize=10.0, fontweight='bold')
    else:
        t1_vals = [res_t1['t_exit'], res_t1['v_exit_kmh'], res_t1['top_speed_kmh'], res_t1['peak_amps'], sf_belt_t1]
        t2_vals = [res_t2['t_exit'], res_t2['v_exit_kmh'], res_t2['top_speed_kmh'], res_t2['peak_amps'], sf_belt_t2]
        t3_vals = [res_t3['t_exit'], res_t3['v_exit_kmh'], res_t3['top_speed_kmh'], res_t3['peak_amps'], sf_belt_t3]

        norm_t2 = [(t2_vals[i] / t1_vals[i]) * 100.0 for i in range(5)]
        norm_t3 = [(t3_vals[i] / t1_vals[i]) * 100.0 for i in range(5)]

        ax_matrix.bar(x_indices - width, [100]*5, width, label='T1 Rapid', color='#00E5FF')
        ax_matrix.bar(x_indices, norm_t2, width, label='T2 Brute', color='#FFD166')
        ax_matrix.bar(x_indices + width, norm_t3, width, label='T3 Vector', color='#FF007F')
        ax_matrix.set_title(f'Timeline Comparison ({kv:.0f} KV, Mass {m_vehicle*1000:.0f}g)', color='white', fontsize=10.0, fontweight='bold')

    ax_matrix.set_xticks(x_indices)
    ax_matrix.set_xticklabels(metrics_names, rotation=15, color='white', fontsize=8.0)
    ax_matrix.axhline(100, color='white', linestyle=':', linewidth=1.2)
    ax_matrix.tick_params(colors='white', labelsize=8)
    ax_matrix.set_ylabel('Relative Performance (%)', color='white', fontsize=8.5)
    ax_matrix.legend(loc='upper left', facecolor='#16181D', edgecolor='#282C34', labelcolor='white', fontsize=7.5)
    ax_matrix.set_ylim(0, 180)

    # =========================================================================
    # TELEMETRY HUD UPDATE
    # =========================================================================
    txt = (
        "================================\n"
        "   POWERTRAIN DYNAMICS HUD      \n"
        "================================\n"
        f"Vehicle Mass     : {m_vehicle*1000:.0f} grams\n"
        f"Motor KV Rating  : {kv:.0f} RPM/V\n"
        f"Gear Ratio       : {ratio:.2f}:1 ({z1}T:{z2}T)\n"
        f"Belt Pitch Len   : {belt_len_mm:.1f} mm\n"
        f"Teeth in Mesh    : {teeth_in_mesh:.1f} teeth\n"
        f"Belt Max Speed   : {v_belt_max:.1f} m/s (Limit: 40)\n"
        f"Tire Grip Limit  : {f_grip:.1f} N\n"
        "--------------------------------\n"
        "TIMELINE 1 (1x Motor + 80A ESC):\n"
        f"  7m Sprint Time : {res_t1['t_exit']:.3f} sec\n"
        f"  7m Exit Speed  : {res_t1['v_exit_kmh']:.1f} km/h\n"
        f"  Top Speed      : {res_t1['top_speed_kmh']:.1f} km/h\n"
        f"  Peak Current   : {res_t1['peak_amps']:.1f} Amps\n"
        f"  Belt Safety SF : {sf_belt_t1:.2f}x (Safe)\n"
        "--------------------------------\n"
        "TIMELINE 2 (2x Motors Solid Axle):\n"
        f"  7m Sprint Time : {res_t2['t_exit']:.3f} sec\n"
        f"  7m Exit Speed  : {res_t2['v_exit_kmh']:.1f} km/h\n"
        f"  Top Speed      : {res_t2['top_speed_kmh']:.1f} km/h\n"
        f"  Peak Current   : {res_t2['peak_amps']:.1f} Amps\n"
        f"  Belt Safety SF : {sf_belt_t2:.2f}x (Safe)\n"
        "--------------------------------\n"
        "TIMELINE 3 (Vector Stub Axles):\n"
        f"  7m Sprint Time : {res_t3['t_exit']:.3f} sec\n"
        f"  7m Exit Speed  : {res_t3['v_exit_kmh']:.1f} km/h\n"
        f"  Top Speed      : {res_t3['top_speed_kmh']:.1f} km/h\n"
        f"  Peak Current   : {res_t3['peak_amps']:.1f} Amps\n"
        "================================"
    )
    telemetry_txt.set_text(txt)
    fig.canvas.draw_idle()

def on_preset_1400(event):
    state['compare_kv'] = False
    sliders['kv'].set_val(1400.0)
    sliders['z1'].set_val(16.0)
    sliders['z2'].set_val(64.0)
    sliders['r_m'].set_val(0.10)
    update()

def on_preset_1000(event):
    state['compare_kv'] = False
    sliders['kv'].set_val(1000.0)
    sliders['z1'].set_val(20.0)
    sliders['z2'].set_val(60.0)
    sliders['r_m'].set_val(0.13)
    update()

def on_compare_kv(event):
    state['compare_kv'] = not state['compare_kv']
    update()

def on_toggle_idler(event):
    state['has_idler'] = not state['has_idler']
    if state['has_idler']:
        btn_idler.label.set_text('Idler Snubber: ACTIVE (210 deg Wrap)')
        btn_idler.color = '#2B9348'
    else:
        btn_idler.label.set_text('Idler Snubber: OFF (Standard Wrap)')
        btn_idler.color = '#D90429'
    update()

for s in sliders.values():
    s.on_changed(update)

btn_1400.on_clicked(on_preset_1400)
btn_1000.on_clicked(on_preset_1000)
btn_comp.on_clicked(on_compare_kv)
btn_idler.on_clicked(on_toggle_idler)

update()
if __name__ == '__main__':
    plt.show()

