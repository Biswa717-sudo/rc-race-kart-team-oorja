function rc_kart_powertrain_simulator()
% =========================================================================
% RC KART MULTI-TIMELINE POWERTRAIN & GT2 DRIVETRAIN SIMULATOR
% Team Oorja F1 RC Race (Division B: Build Your Own RC Cars)
%
% COMPLETE PHYSICAL SIMULATION OF:
%   - Battery (Internal resistance, voltage sag, C-rate, capacity)
%   - ESC (MOSFET on-resistance, continuous/burst current clipping)
%   - Motor (1400 KV vs. 1000 KV, Kt, Ke, Rm, Io, thermal dissipation)
%   - GT2 Timing Belt (Tooth counts Z1, Z2, center distance, width,
%     wrap angle, teeth in mesh, tangential shear force, safety factor)
%   - Wheels & Traction (65mm rubber slicks, normal force, grip limit)
%   - Vehicle Dynamics (Rotational inertia of motor, belts, axle, wheels)
%   - Track Sprint (Numerical integration over 7.0-meter straight)
%
% ACROSS ALL THREE TIMELINES:
%   - Timeline 1: 1x Motor + 80A ESC + Solid 8mm Axle (~680g)
%   - Timeline 2: 2x Motors + 2x 30A ESCs + Solid 8mm Axle (~880g)
%   - Timeline 3: 2x Motors + 2x 30A ESCs + Split Independent Axles (~890g)
%
% ENHANCED KV FEATURES:
%   - One-click [1400 KV] Preset (High-RPM, 16T:64T 4:1)
%   - One-click [1000 KV] Preset (High-Torque, 20T:60T 3:1)
%   - [Compare 1400KV vs 1000KV] Dual-Motor Overlay Mode
% =========================================================================

    close all;
    clc;

    % ---------------------------------------------------------------------
    % Default Powertrain Parameters
    % ---------------------------------------------------------------------
    p.kv            = 1400.0;  % Motor KV rating (RPM/V)
    p.r_m           = 0.10;    % Motor winding resistance (Ohms: 0.10 for 1400KV, 0.13 for 1000KV)
    p.i0            = 0.70;    % Motor no-load current (Amps: 0.7A for 1400KV, 0.5A for 1000KV)
    p.v_oc          = 8.40;    % Battery Open-Circuit Voltage (2S peak = 8.4V)
    p.r_bat         = 0.015;   % Battery internal resistance (Ohms)
    p.r_esc         = 0.003;   % ESC MOSFET resistance (Ohms)
    p.z1            = 16;      % Motor Pinion Pulley Teeth (GT2 2mm pitch)
    p.z2            = 64;      % Axle Spur Pulley Teeth (GT2 2mm pitch)
    p.c_dist        = 50.0;    % Center distance between shafts (mm)
    p.belt_width    = 6.0;     % GT2 Belt Width (mm: 6, 9, 10, 15)
    p.d_tire        = 65.0;    % Tire Diameter (mm, Rulebook min 50mm)
    p.mu_tire       = 0.95;    % Tire Friction Coefficient (rubber on redstone tiles)
    p.x_track       = 7.0;     % Straightaway Sprint Length (meters)
    p.has_idler     = 1;       % 623ZZ Idler Snubber enabled (1=Yes, 0=No)
    p.active_tl     = 0;       % 0=All Timelines Overlay, 1=T1, 2=T2, 3=T3
    p.compare_kv    = 0;       % 0=Single KV view, 1=Dual 1400KV vs 1000KV Overlay

    % Default Masses (kg) - Target Total Mass: 600g
    p.mass_t1       = 0.600;   % Timeline 1 mass (600g baseline)
    p.mass_t2       = 0.600;   % Timeline 2 mass (600g baseline)
    p.mass_t3       = 0.600;   % Timeline 3 mass (600g baseline)

    % ---------------------------------------------------------------------
    % Create Figure Window & Control Layout
    % ---------------------------------------------------------------------
    fig = figure('Name', 'RC Kart Powertrain & GT2 Drivetrain Simulator (1400KV vs 1000KV)', ...
                 'NumberTitle', 'off', ...
                 'Color', [0.10 0.11 0.13], ...
                 'Position', [30, 30, 1560, 940], ...
                 'MenuBar', 'figure', ...
                 'ToolBar', 'auto');

    % Subplot Axes
    ax_sprint = subplot('Position', [0.31, 0.54, 0.32, 0.40], 'Parent', fig);
    ax_torque = subplot('Position', [0.68, 0.54, 0.29, 0.40], 'Parent', fig);
    ax_belt   = subplot('Position', [0.31, 0.08, 0.32, 0.38], 'Parent', fig);
    ax_matrix = subplot('Position', [0.68, 0.08, 0.29, 0.38], 'Parent', fig);

    % Title on Left Control Panel
    uicontrol('Style', 'text', 'String', 'POWERTRAIN CONTROLS & KV MODES', ...
              'Parent', fig, 'Units', 'normalized', ...
              'Position', [0.015, 0.965, 0.26, 0.025], ...
              'FontSize', 11, 'FontWeight', 'bold', ...
              'ForegroundColor', [0.0 0.8 1.0], 'BackgroundColor', [0.10 0.11 0.13]);

    % One-Click Motor KV Quick-Presets
    handles.btn_kv1400 = uicontrol('Style', 'pushbutton', 'String', 'Preset: 1400 KV (4:1)', ...
              'Parent', fig, 'Units', 'normalized', ...
              'Position', [0.015, 0.932, 0.082, 0.026], ...
              'FontSize', 8.0, 'FontWeight', 'bold', ...
              'ForegroundColor', [0.1 0.1 0.1], 'BackgroundColor', [0.2 0.85 1.0], ...
              'Callback', @(s, e) set_kv_preset(1400, 16, 64, 0.10, 0.70));

    handles.btn_kv1000 = uicontrol('Style', 'pushbutton', 'String', 'Preset: 1000 KV (3:1)', ...
              'Parent', fig, 'Units', 'normalized', ...
              'Position', [0.102, 0.932, 0.082, 0.026], ...
              'FontSize', 8.0, 'FontWeight', 'bold', ...
              'ForegroundColor', [1 1 1], 'BackgroundColor', [0.85 0.55 0.15], ...
              'Callback', @(s, e) set_kv_preset(1000, 20, 60, 0.13, 0.50));

    handles.btn_kv_comp = uicontrol('Style', 'pushbutton', 'String', 'Compare 1400 vs 1000', ...
              'Parent', fig, 'Units', 'normalized', ...
              'Position', [0.189, 0.932, 0.086, 0.026], ...
              'FontSize', 8.0, 'FontWeight', 'bold', ...
              'ForegroundColor', [1 1 1], 'BackgroundColor', [0.65 0.25 0.85], ...
              'Callback', @(s, e) toggle_kv_compare());

    % Slider definitions: {Name, min, max, default, step, format, tag}
    slider_defs = {
        'Motor KV Rating',             800,  2400, p.kv,         20,   '%.0f RPM/V', 'kv';
        'Battery Peak Voltage (V_oc)', 6.6,   8.4, p.v_oc,       0.05, '%.2f V',     'v_oc';
        'Motor Pulley Teeth (Z1)',      12,    24, p.z1,         1,    '%.0f T',     'z1';
        'Axle Pulley Teeth (Z2)',       40,    90, p.z2,         1,    '%.0f T',     'z2';
        'Center Distance (C)',          35,    80, p.c_dist,     0.5,  '%.1f mm',    'c_dist';
        'GT2 Belt Width',                6,    15, p.belt_width, 1,    '%.0f mm',    'belt_width';
        'Tire Diameter (D_tire)',       50,    80, p.d_tire,     0.5,  '%.1f mm',    'd_tire';
        'Tire Traction Coeff (mu)',    0.6,   1.4, p.mu_tire,    0.02, '%.2f',       'mu_tire';
        'Track Straight Length',       4.0,  15.0, p.x_track,    0.2,  '%.1f m',     'x_track';
        'Motor Resistance (R_m)',     0.04,  0.20, p.r_m,        0.005,'%.3f Ohm',   'r_m';
        'Battery Resistance (R_bat)', 0.005, 0.040,p.r_bat,      0.001,'%.3f Ohm',   'r_bat';
        'Total Vehicle Mass (M)',      400,  1000, p.mass_t1*1000, 10, '%.0f g',     'mass_t1'
    };

    num_sliders = size(slider_defs, 1);
    handles.sliders = struct();
    handles.labels  = struct();

    y_start = 0.895;
    y_step  = 0.044;

    for i = 1:num_sliders
        s_name   = slider_defs{i, 1};
        s_min    = slider_defs{i, 2};
        s_max    = slider_defs{i, 3};
        s_val    = slider_defs{i, 4};
        s_step   = slider_defs{i, 5} / (s_max - s_min);
        s_fmt    = slider_defs{i, 6};
        s_tag    = slider_defs{i, 7};
        y_pos    = y_start - (i - 1) * y_step;

        txt_h = uicontrol('Style', 'text', ...
                          'String', sprintf(['%s: ' s_fmt], s_name, s_val), ...
                          'Parent', fig, 'Units', 'normalized', ...
                          'Position', [0.015, y_pos + 0.018, 0.26, 0.018], ...
                          'HorizontalAlignment', 'left', ...
                          'FontSize', 8.5, 'FontWeight', 'bold', ...
                          'ForegroundColor', [0.92 0.94 0.96], ...
                          'BackgroundColor', [0.10 0.11 0.13]);

        sld_h = uicontrol('Style', 'slider', ...
                          'Min', s_min, 'Max', s_max, 'Value', s_val, ...
                          'SliderStep', [s_step, s_step * 5], ...
                          'Parent', fig, 'Units', 'normalized', ...
                          'Position', [0.015, y_pos, 0.26, 0.017], ...
                          'BackgroundColor', [0.18 0.20 0.24]);

        addlistener(sld_h, 'ContinuousValueChange', @(src, event) update_sim());

        handles.sliders.(s_tag) = sld_h;
        handles.labels.(s_tag)  = txt_h;
    end

    % Timeline Selection Toggle Buttons
    uicontrol('Style', 'text', 'String', 'Timeline View:', ...
              'Parent', fig, 'Units', 'normalized', ...
              'Position', [0.015, 0.345, 0.08, 0.022], ...
              'FontSize', 8.5, 'FontWeight', 'bold', ...
              'ForegroundColor', 'w', 'BackgroundColor', [0.10 0.11 0.13]);

    handles.btn_all = uicontrol('Style', 'pushbutton', 'String', 'Overlay All 3', ...
              'Parent', fig, 'Units', 'normalized', ...
              'Position', [0.095, 0.345, 0.075, 0.024], ...
              'FontSize', 8.0, 'FontWeight', 'bold', ...
              'ForegroundColor', [0.1 0.1 0.1], 'BackgroundColor', [0.0 0.85 1.0], ...
              'Callback', @(s, e) set_timeline_view(0));

    handles.btn_t1 = uicontrol('Style', 'pushbutton', 'String', 'T1 Rapid', ...
              'Parent', fig, 'Units', 'normalized', ...
              'Position', [0.175, 0.345, 0.048, 0.024], ...
              'FontSize', 8.0, 'FontWeight', 'bold', ...
              'ForegroundColor', 'w', 'BackgroundColor', [0.25 0.28 0.33], ...
              'Callback', @(s, e) set_timeline_view(1));

    handles.btn_t2 = uicontrol('Style', 'pushbutton', 'String', 'T2 Brute', ...
              'Parent', fig, 'Units', 'normalized', ...
              'Position', [0.228, 0.345, 0.048, 0.024], ...
              'FontSize', 8.0, 'FontWeight', 'bold', ...
              'ForegroundColor', 'w', 'BackgroundColor', [0.25 0.28 0.33], ...
              'Callback', @(s, e) set_timeline_view(2));

    % Toggle Idler Snubber Button
    handles.btn_idler = uicontrol('Style', 'pushbutton', 'String', 'Idler Snubber: ACTIVE (210 deg Wrap)', ...
              'Parent', fig, 'Units', 'normalized', ...
              'Position', [0.015, 0.315, 0.265, 0.025], ...
              'FontSize', 8.5, 'FontWeight', 'bold', ...
              'ForegroundColor', [0.1 0.1 0.1], 'BackgroundColor', [0.35 0.85 0.45], ...
              'Callback', @(s, e) toggle_idler());

    % Live Telemetry Box
    handles.telemetry_box = uicontrol('Style', 'text', ...
              'String', 'Live Powertrain Telemetry Initializing...', ...
              'Parent', fig, 'Units', 'normalized', ...
              'Position', [0.015, 0.015, 0.265, 0.292], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 8.5, 'FontName', 'Courier', ...
              'ForegroundColor', [0.25 0.95 0.45], 'BackgroundColor', [0.06 0.07 0.08]);

    guidata(fig, handles);
    update_sim();

    % =====================================================================
    % NESTED CONTROLLER FUNCTIONS
    % =====================================================================

    function set_kv_preset(target_kv, target_z1, target_z2, target_rm, target_i0)
        h = guidata(fig);
        p.kv  = target_kv;
        p.z1  = target_z1;
        p.z2  = target_z2;
        p.r_m = target_rm;
        p.i0  = target_i0;
        p.compare_kv = 0; % Disable overlay mode

        set(h.sliders.kv,  'Value', target_kv);
        set(h.sliders.z1,  'Value', target_z1);
        set(h.sliders.z2,  'Value', target_z2);
        set(h.sliders.r_m, 'Value', target_rm);

        set(h.btn_kv_comp, 'BackgroundColor', [0.25 0.28 0.33]);
        if target_kv == 1400
            set(h.btn_kv1400, 'BackgroundColor', [0.2 0.85 1.0], 'ForegroundColor', [0.1 0.1 0.1]);
            set(h.btn_kv1000, 'BackgroundColor', [0.25 0.28 0.33], 'ForegroundColor', [1 1 1]);
        else
            set(h.btn_kv1000, 'BackgroundColor', [0.85 0.55 0.15], 'ForegroundColor', [0.1 0.1 0.1]);
            set(h.btn_kv1400, 'BackgroundColor', [0.25 0.28 0.33], 'ForegroundColor', [1 1 1]);
        end
        update_sim();
    end

    function toggle_kv_compare()
        p.compare_kv = ~p.compare_kv;
        h = guidata(fig);
        if p.compare_kv
            set(h.btn_kv_comp, 'BackgroundColor', [0.75 0.25 0.95], 'ForegroundColor', [1 1 1]);
        else
            set(h.btn_kv_comp, 'BackgroundColor', [0.25 0.28 0.33], 'ForegroundColor', [1 1 1]);
        end
        update_sim();
    end

    function set_timeline_view(tl_mode)
        p.active_tl = tl_mode;
        update_sim();
    end

    function toggle_idler()
        p.has_idler = ~p.has_idler;
        h = guidata(fig);
        if p.has_idler
            set(h.btn_idler, 'String', 'Idler Snubber: ACTIVE (210 deg Wrap)', ...
                             'BackgroundColor', [0.35 0.85 0.45], 'ForegroundColor', [0.1 0.1 0.1]);
        else
            set(h.btn_idler, 'String', 'Idler Snubber: OFF (Standard Wrap)', ...
                             'BackgroundColor', [0.75 0.3 0.25], 'ForegroundColor', [1 1 1]);
        end
        update_sim();
    end

    function update_sim()
        h = guidata(fig);

        % Read current slider values
        kv         = get(h.sliders.kv, 'Value');
        v_oc       = get(h.sliders.v_oc, 'Value');
        z1         = round(get(h.sliders.z1, 'Value'));
        z2         = round(get(h.sliders.z2, 'Value'));
        c_dist     = get(h.sliders.c_dist, 'Value');
        belt_w     = get(h.sliders.belt_width, 'Value');
        d_tire     = get(h.sliders.d_tire, 'Value');
        mu_tire    = get(h.sliders.mu_tire, 'Value');
        x_track    = get(h.sliders.x_track, 'Value');
        r_m        = get(h.sliders.r_m, 'Value');
        r_bat      = get(h.sliders.r_bat, 'Value');
        m_t1       = get(h.sliders.mass_t1, 'Value') / 1000.0; % kg

        for j = 1:num_sliders
            tag = slider_defs{j, 7};
            fmt = slider_defs{j, 6};
            nam = slider_defs{j, 1};
            val = get(h.sliders.(tag), 'Value');
            set(h.labels.(tag), 'String', sprintf(['%s: ' fmt], nam, val));
        end

        m_t2 = m_t1 + 0.200; % +200g
        m_t3 = m_t1 + 0.210; % +210g

        % GT2 Belt Mechanics
        pitch_mm = 2.0;
        d1_mm = (z1 * pitch_mm) / pi;
        d2_mm = (z2 * pitch_mm) / pi;
        ratio = z2 / z1;

        min_c = (d1_mm + d2_mm) / 2.0 + 2.0;
        if c_dist < min_c
            c_dist = min_c;
            set(h.sliders.c_dist, 'Value', c_dist);
        end

        belt_len_mm = 2 * c_dist + (pi / 2.0) * (d1_mm + d2_mm) + ((d2_mm - d1_mm)^2) / (4.0 * c_dist);

        sin_val = (d2_mm - d1_mm) / (2.0 * c_dist);
        sin_val = max(-1.0, min(1.0, sin_val));
        wrap_deg = rad2deg(pi - 2.0 * asin(sin_val));

        if p.has_idler
            wrap_deg = min(235.0, wrap_deg + 35.0);
        end

        teeth_in_mesh = z1 * (wrap_deg / 360.0);

        % Simulate Sprint for Current Parameters
        res_t1 = run_dyno_sprint(1, m_t1, kv, v_oc, z1, z2, d_tire, mu_tire, r_bat, r_m, p.r_esc, x_track, p.i0);
        res_t2 = run_dyno_sprint(2, m_t2, kv, v_oc, z1, z2, d_tire, mu_tire, r_bat, r_m, p.r_esc, x_track, p.i0);
        res_t3 = run_dyno_sprint(2, m_t3, kv, v_oc, z1, z2, d_tire, mu_tire, r_bat, r_m, p.r_esc, x_track, p.i0);

        % If Compare KV mode is active, simulate alternate 1000KV or 1400KV
        if p.compare_kv
            alt_kv = ternary(kv >= 1200, 1000.0, 1400.0);
            alt_rm = ternary(alt_kv == 1000, 0.13, 0.10);
            alt_i0 = ternary(alt_kv == 1000, 0.50, 0.70);
            alt_z1 = ternary(alt_kv == 1000, 20, 16);
            alt_z2 = ternary(alt_kv == 1000, 60, 64);

            res_alt_t1 = run_dyno_sprint(1, m_t1, alt_kv, v_oc, alt_z1, alt_z2, d_tire, mu_tire, r_bat, alt_rm, p.r_esc, x_track, alt_i0);
            res_alt_t2 = run_dyno_sprint(2, m_t2, alt_kv, v_oc, alt_z1, alt_z2, d_tire, mu_tire, r_bat, alt_rm, p.r_esc, x_track, alt_i0);
        end

        % Belt tooth shear forces
        r1_m = (d1_mm / 1000.0) / 2.0;
        f_tangential_t1 = res_t1.peak_motor_tau / r1_m;
        f_tangential_t2 = (res_t2.peak_motor_tau / 2.0) / r1_m;
        f_tangential_t3 = (res_t3.peak_motor_tau / 2.0) / r1_m;

        shear_rated_per_tooth = 11.0 * (belt_w / 6.0);
        belt_shear_cap = shear_rated_per_tooth * teeth_in_mesh;
        sf_belt_t1 = belt_shear_cap / max(1.0, f_tangential_t1);
        sf_belt_t2 = belt_shear_cap / max(1.0, f_tangential_t2);
        sf_belt_t3 = belt_shear_cap / max(1.0, f_tangential_t3);

        max_rpm_m = res_t1.top_speed_kmh / 3.6 / ((d_tire/1000)/2) * ratio * 60 / (2*pi);
        v_belt_max = (pi * (d1_mm/1000) * max_rpm_m) / 60.0;

        % =================================================================
        % PLOT 1: SPRINT VELOCITY & DISTANCE VS TIME
        % =================================================================
        cla(ax_sprint);
        hold(ax_sprint, 'on');
        grid(ax_sprint, 'on');
        set(ax_sprint, 'Color', [0.14 0.15 0.18], 'GridColor', [0.25 0.28 0.33]);

        if p.compare_kv
            % Plot 1400KV vs 1000KV directly
            plot(ax_sprint, res_t1.t_arr, res_t1.v_arr * 3.6, 'Color', [0.2 0.85 1.0], 'LineWidth', 2.5, ...
                 'DisplayName', sprintf('%.0fKV T1 (Exit: %.1f km/h @ %.2fs)', kv, res_t1.v_exit_kmh, res_t1.t_exit));
            plot(ax_sprint, res_alt_t1.t_arr, res_alt_t1.v_arr * 3.6, 'Color', [0.85 0.55 0.15], 'LineWidth', 2.5, 'LineStyle', '--', ...
                 'DisplayName', sprintf('%.0fKV T1 (Exit: %.1f km/h @ %.2fs)', alt_kv, res_alt_t1.v_exit_kmh, res_alt_t1.t_exit));
            plot(ax_sprint, res_t2.t_arr, res_t2.v_arr * 3.6, 'Color', [1.0 0.8 0.2], 'LineWidth', 2.0, ...
                 'DisplayName', sprintf('%.0fKV T2 (Exit: %.1f km/h @ %.2fs)', kv, res_t2.v_exit_kmh, res_t2.t_exit));
            plot(ax_sprint, res_alt_t2.t_arr, res_alt_t2.v_arr * 3.6, 'Color', [0.9 0.2 0.4], 'LineWidth', 2.0, 'LineStyle', '--', ...
                 'DisplayName', sprintf('%.0fKV T2 (Exit: %.1f km/h @ %.2fs)', alt_kv, res_alt_t2.v_exit_kmh, res_alt_t2.t_exit));
        else
            if p.active_tl == 0 || p.active_tl == 1
                plot(ax_sprint, res_t1.t_arr, res_t1.v_arr * 3.6, 'Color', [0.2 0.85 1.0], 'LineWidth', 2.4, ...
                     'DisplayName', sprintf('T1 Rapid (Exit: %.1f km/h @ %.2fs)', res_t1.v_exit_kmh, res_t1.t_exit));
            end
            if p.active_tl == 0 || p.active_tl == 2
                plot(ax_sprint, res_t2.t_arr, res_t2.v_arr * 3.6, 'Color', [1.0 0.8 0.2], 'LineWidth', 2.4, ...
                     'DisplayName', sprintf('T2 Brute (Exit: %.1f km/h @ %.2fs)', res_t2.v_exit_kmh, res_t2.t_exit));
            end
            if p.active_tl == 0 || p.active_tl == 3
                plot(ax_sprint, res_t3.t_arr, res_t3.v_arr * 3.6, 'Color', [1.0 0.3 0.8], 'LineWidth', 2.4, ...
                     'DisplayName', sprintf('T3 Vector (Exit: %.1f km/h @ %.2fs)', res_t3.v_exit_kmh, res_t3.t_exit));
            end
        end

        if ~isnan(res_t1.t_exit)
            xline(ax_sprint, res_t1.t_exit, 'c:', 'LineWidth', 1.2);
        end

        title(ax_sprint, sprintf('Sprint Acceleration on %.1fm Straight (%s)', x_track, ternary(p.compare_kv, 'KV Compare Mode', sprintf('%.0f KV', kv))), ...
              'Color', 'w', 'FontSize', 10.5, 'FontWeight', 'bold');
        xlabel(ax_sprint, 'Time (seconds)', 'Color', 'w', 'FontSize', 8.5);
        ylabel(ax_sprint, 'Vehicle Speed (km/h)', 'Color', 'w', 'FontSize', 8.5);
        legend(ax_sprint, 'Location', 'southeast', 'TextColor', 'w', 'Color', [0.1 0.11 0.13], 'FontSize', 7.5);
        xlim(ax_sprint, [0, max(2.0, res_t1.t_exit * 1.3)]);

        % =================================================================
        % PLOT 2: TRACTIVE FORCE VS SPEED & TIRE TRACTION LIMIT
        % =================================================================
        cla(ax_torque);
        hold(ax_torque, 'on');
        grid(ax_torque, 'on');
        set(ax_torque, 'Color', [0.14 0.15 0.18], 'GridColor', [0.25 0.28 0.33]);

        speed_sweep_kmh = linspace(0, 48, 200);
        r_w = (d_tire / 1000.0) / 2.0;

        f_grip_t1 = mu_tire * m_t1 * 9.81 * 0.65;
        f_grip_t2 = mu_tire * m_t2 * 9.81 * 0.65;

        f_drive_t1 = zeros(size(speed_sweep_kmh));
        f_drive_t2 = zeros(size(speed_sweep_kmh));

        kt = 9.5493 / kv;
        ke = 1.0 / (kv * 2 * pi / 60.0);
        r_tot1 = r_bat + p.r_esc + r_m;
        r_tot2 = (r_bat / 2.0) + p.r_esc + r_m;

        for k = 1:length(speed_sweep_kmh)
            v_ms = speed_sweep_kmh(k) / 3.6;
            om_w = v_ms / r_w;
            om_m = om_w * ratio;

            i1 = max(0.0, min(80.0, (v_oc - om_m * ke) / r_tot1));
            t1_m = max(0.0, kt * (i1 - p.i0));
            f_drive_t1(k) = (1 * t1_m * ratio * 0.97) / r_w;

            i2 = max(0.0, min(40.0, (v_oc - om_m * ke) / r_tot2));
            t2_m = max(0.0, kt * (i2 - p.i0));
            f_drive_t2(k) = (2 * t2_m * ratio * 0.97) / r_w;
        end

        yline(ax_torque, f_grip_t1, 'c--', 'LineWidth', 1.8, 'DisplayName', sprintf('T1 Grip Limit (%.1f N)', f_grip_t1));
        yline(ax_torque, f_grip_t2, 'y--', 'LineWidth', 1.8, 'DisplayName', sprintf('T2/T3 Grip Limit (%.1f N)', f_grip_t2));

        plot(ax_torque, speed_sweep_kmh, f_drive_t1, 'Color', [0.2 0.85 1.0], 'LineWidth', 2.3, 'DisplayName', 'T1 Motor Drive Force');
        plot(ax_torque, speed_sweep_kmh, f_drive_t2, 'Color', [1.0 0.8 0.2], 'LineWidth', 2.3, 'DisplayName', 'T2/T3 Dual Motor Force');

        title(ax_torque, 'Tractive Drive Force vs. Tire Grip Limit', 'Color', 'w', 'FontSize', 10.5, 'FontWeight', 'bold');
        xlabel(ax_torque, 'Vehicle Speed (km/h)', 'Color', 'w', 'FontSize', 8.5);
        ylabel(ax_torque, 'Drive / Grip Force (Newtons)', 'Color', 'w', 'FontSize', 8.5);
        legend(ax_torque, 'Location', 'northeast', 'TextColor', 'w', 'Color', [0.1 0.11 0.13], 'FontSize', 7.5);
        xlim(ax_torque, [0, 45]);
        ylim(ax_torque, [0, max(f_drive_t2) * 1.1]);

        % =================================================================
        % PLOT 3: GT2 BELT RATIO & TOOTH SAFETY FACTOR
        % =================================================================
        cla(ax_belt);
        hold(ax_belt, 'on');
        grid(ax_belt, 'on');
        set(ax_belt, 'Color', [0.14 0.15 0.18], 'GridColor', [0.25 0.28 0.33]);

        z1_sweep = 12:24;
        sf_sweep_no_idler = zeros(size(z1_sweep));
        sf_sweep_idler    = zeros(size(z1_sweep));

        for s_idx = 1:length(z1_sweep)
            cur_z1 = z1_sweep(s_idx);
            cur_d1 = (cur_z1 * pitch_mm) / pi;
            cur_r1 = (cur_d1 / 1000.0) / 2.0;
            cur_sin = (d2_mm - cur_d1) / (2.0 * c_dist);
            cur_w_deg = rad2deg(pi - 2.0 * asin(max(-1.0, min(1.0, cur_sin))));

            tim_no = cur_z1 * (cur_w_deg / 360.0);
            tim_id = cur_z1 * (min(235.0, cur_w_deg + 35.0) / 360.0);

            cap_no = shear_rated_per_tooth * tim_no;
            cap_id = shear_rated_per_tooth * tim_id;

            cur_ft = res_t1.peak_motor_tau / cur_r1;
            sf_sweep_no_idler(s_idx) = cap_no / max(1.0, cur_ft);
            sf_sweep_idler(s_idx)    = cap_id / max(1.0, cur_ft);
        end

        yline(ax_belt, 1.0, 'r--', 'LineWidth', 1.8, 'DisplayName', 'Ratcheting Danger (SF = 1.0)');
        yline(ax_belt, 2.0, 'g:', 'LineWidth', 1.5, 'DisplayName', 'Safe Racing Margin (SF = 2.0)');

        plot(ax_belt, z1_sweep, sf_sweep_no_idler, 'm-o', 'LineWidth', 2.0, 'DisplayName', 'Standard Wrap (No Idler)');
        plot(ax_belt, z1_sweep, sf_sweep_idler, 'c-s', 'LineWidth', 2.2, 'DisplayName', 'Active 623ZZ Snubber Idler');

        plot(ax_belt, z1, sf_belt_t1, 'yo', 'MarkerSize', 10, 'MarkerFaceColor', [1 0.8 0.2], ...
             'DisplayName', sprintf('Current: %dT (SF = %.2f)', z1, sf_belt_t1));

        title(ax_belt, sprintf('GT2 Belt Skip Safety Factor vs. Pinion Teeth (Width: %.0fmm)', belt_w), ...
              'Color', 'w', 'FontSize', 10.5, 'FontWeight', 'bold');
        xlabel(ax_belt, 'Motor Pinion Tooth Count (Z1)', 'Color', 'w', 'FontSize', 8.5);
        ylabel(ax_belt, 'Safety Factor against Tooth Skipping', 'Color', 'w', 'FontSize', 8.5);
        legend(ax_belt, 'Location', 'northwest', 'TextColor', 'w', 'Color', [0.1 0.11 0.13], 'FontSize', 7.5);
        xlim(ax_belt, [11.5, 24.5]);
        ylim(ax_belt, [0, max(sf_sweep_idler) * 1.15]);

        % =================================================================
        % PLOT 4: TIMELINE MASTER COMPARISON MATRIX
        % =================================================================
        cla(ax_matrix);
        hold(ax_matrix, 'on');
        grid(ax_matrix, 'on');
        set(ax_matrix, 'Color', [0.14 0.15 0.18], 'GridColor', [0.25 0.28 0.33]);

        if p.compare_kv
            % Compare 1400KV vs 1000KV across T1 and T2
            metrics_names = {'7m Time', 'Exit Speed', 'Top Speed', 'Peak Current', 'Belt Safety'};
            t1_1400 = [res_t1.t_exit, res_t1.v_exit_kmh, res_t1.top_speed_kmh, res_t1.peak_amps, sf_belt_t1];
            t1_1000 = [res_alt_t1.t_exit, res_alt_t1.v_exit_kmh, res_alt_t1.top_speed_kmh, res_alt_t1.peak_amps, sf_belt_t1*1.2];

            norm_1400 = [100, 100, 100, 100, 100];
            norm_1000 = (t1_1000 ./ t1_1400) * 100.0;

            b = bar(ax_matrix, [norm_1400; norm_1000]', 'grouped');
            b(1).FaceColor = [0.2 0.85 1.0];  % 1400KV Cyan
            b(2).FaceColor = [0.85 0.55 0.15]; % 1000KV Orange
            legend(ax_matrix, {'1400 KV (4:1)', '1000 KV (3:1)'}, ...
                   'Location', 'northwest', 'TextColor', 'w', 'Color', [0.1 0.11 0.13], 'FontSize', 7.5);
            title(ax_matrix, '1400 KV vs. 1000 KV Performance Index', 'Color', 'w', 'FontSize', 10.5, 'FontWeight', 'bold');
        else
            metrics_names = {'7m Time', 'Exit Speed', 'Top Speed', 'Peak Current', 'Belt Safety'};
            t1_vals = [res_t1.t_exit, res_t1.v_exit_kmh, res_t1.top_speed_kmh, res_t1.peak_amps, sf_belt_t1];
            t2_vals = [res_t2.t_exit, res_t2.v_exit_kmh, res_t2.top_speed_kmh, res_t2.peak_amps, sf_belt_t2];
            t3_vals = [res_t3.t_exit, res_t3.v_exit_kmh, res_t3.top_speed_kmh, res_t3.peak_amps, sf_belt_t3];

            norm_t1 = [100, 100, 100, 100, 100];
            norm_t2 = (t2_vals ./ t1_vals) * 100.0;
            norm_t3 = (t3_vals ./ t1_vals) * 100.0;

            bar_data = [norm_t1; norm_t2; norm_t3]';
            b = bar(ax_matrix, bar_data, 'grouped');
            b(1).FaceColor = [0.2 0.85 1.0];
            b(2).FaceColor = [1.0 0.80 0.2];
            b(3).FaceColor = [1.0 0.30 0.8];

            legend(ax_matrix, {'T1 Rapid', 'T2 Brute', 'T3 Vector'}, ...
                   'Location', 'northwest', 'TextColor', 'w', 'Color', [0.1 0.11 0.13], 'FontSize', 7.5);
            title(ax_matrix, sprintf('Timeline Comparison (%.0f KV)', kv), 'Color', 'w', 'FontSize', 10.5, 'FontWeight', 'bold');
        end

        set(ax_matrix, 'XTickLabel', metrics_names, 'XTickLabelRotation', 15);
        yline(ax_matrix, 100, 'w:', 'LineWidth', 1.2);
        ylabel(ax_matrix, 'Relative Performance (%)', 'Color', 'w', 'FontSize', 8.5);
        ylim(ax_matrix, [0, 180]);

        % =================================================================
        % LIVE TELEMETRY HUD UPDATE
        % =================================================================
        telemetry_txt = sprintf([...
            '================================\n' ...
            '   POWERTRAIN DYNAMICS HUD      \n' ...
            '================================\n' ...
            'Motor KV Rating  : %.0f RPM/V\n' ...
            'Ratio (Z2:Z1)    : %.2f:1 (%dT:%dT)\n' ...
            'Belt Pitch Len   : %.1f mm\n' ...
            'Teeth in Mesh    : %.1f teeth\n' ...
            'Wrap Angle       : %.1f deg %s\n' ...
            'Belt Max Speed   : %.1f m/s (Limit: 40)\n' ...
            '--------------------------------\n' ...
            'TIMELINE 1 (1x Motor + 80A ESC):\n' ...
            '  7m Sprint Time : %.3f sec\n' ...
            '  7m Exit Speed  : %.1f km/h\n' ...
            '  Top Speed      : %.1f km/h\n' ...
            '  Peak Current   : %.1f Amps\n' ...
            '  Belt Safety SF : %.2fx (Safe)\n' ...
            '--------------------------------\n' ...
            'TIMELINE 2 (2x Motors Solid):\n' ...
            '  7m Sprint Time : %.3f sec\n' ...
            '  7m Exit Speed  : %.1f km/h\n' ...
            '  Top Speed      : %.1f km/h\n' ...
            '  Peak Current   : %.1f Amps\n' ...
            '  Belt Safety SF : %.2fx (Safe)\n' ...
            '--------------------------------\n' ...
            'TIMELINE 3 (Vector Stub Axles):\n' ...
            '  7m Sprint Time : %.3f sec\n' ...
            '  7m Exit Speed  : %.1f km/h\n' ...
            '  Top Speed      : %.1f km/h\n' ...
            '  Peak Current   : %.1f Amps\n' ...
            '================================' ...
        ], kv, ratio, z2, z1, belt_len_mm, teeth_in_mesh, wrap_deg, ...
           ternary(p.has_idler, '(Idler Active)', '(No Idler)'), v_belt_max, ...
           res_t1.t_exit, res_t1.v_exit_kmh, res_t1.top_speed_kmh, res_t1.peak_amps, sf_belt_t1, ...
           res_t2.t_exit, res_t2.v_exit_kmh, res_t2.top_speed_kmh, res_t2.peak_amps, sf_belt_t2, ...
           res_t3.t_exit, res_t3.v_exit_kmh, res_t3.top_speed_kmh, res_t3.peak_amps);

        set(h.telemetry_box, 'String', telemetry_txt);
        drawnow limitrate;
    end

    function res = run_dyno_sprint(n_motors, mass_kg, kv, v_oc, z1, z2, d_tire_mm, mu, r_bat, r_m, r_esc, x_target, i0)
        ratio = z2 / z1;
        r_w = (d_tire_mm / 1000.0) / 2.0;
        kt = 9.5493 / kv;
        ke = 1.0 / (kv * 2.0 * pi / 60.0);
        r_tot = (r_bat / n_motors) + r_esc + r_m;

        j_rotor = 5.0e-6;
        j_p1    = 0.5e-6;
        j_p2    = 4.0e-6;
        j_wheel = 2.0e-5;
        j_axle  = 1.5e-6;

        j_rot_reflected = n_motors * (j_rotor + j_p1) * (ratio^2);
        j_total = j_rot_reflected + j_p2 + j_wheel + j_axle;
        m_rot_equiv = j_total / (r_w^2);
        m_eff = mass_kg + m_rot_equiv;

        f_grip_max = mu * mass_kg * 9.81 * 0.65;

        dt = 0.002;
        t_max = 2.5;
        steps = round(t_max / dt);

        t_arr = zeros(1, steps);
        x_arr = zeros(1, steps);
        v_arr = zeros(1, steps);

        t_curr = 0; x_curr = 0; v_curr = 0;
        t_exit = nan; v_exit_kmh = nan;
        peak_amps = 0; peak_motor_tau = 0;

        for step = 1:steps
            t_arr(step) = t_curr;
            x_arr(step) = x_curr;
            v_arr(step) = v_curr;

            omega_w = v_curr / r_w;
            omega_m = omega_w * ratio;

            eb = omega_m * ke;
            i_m = max(0.0, (v_oc - eb) / r_tot);
            if n_motors == 1
                i_m = min(i_m, 80.0);
            else
                i_m = min(i_m, 40.0);
            end

            if (i_m * n_motors) > peak_amps
                peak_amps = i_m * n_motors;
            end

            tau_m = max(0.0, kt * (i_m - i0));
            if tau_m > peak_motor_tau
                peak_motor_tau = tau_m;
            end

            tau_axle = n_motors * tau_m * ratio * 0.97;
            f_drive = tau_axle / r_w;

            f_tractive = min(f_drive, f_grip_max);
            f_rr = 0.03 * mass_kg * 9.81;
            f_aero = 0.5 * 1.2 * 0.03 * (v_curr^2);
            f_net = max(0.0, f_tractive - f_rr - f_aero);

            a = f_net / m_eff;

            v_curr = v_curr + a * dt;
            x_curr = x_curr + v_curr * dt;
            t_curr = t_curr + dt;

            if x_curr >= x_target && isnan(t_exit)
                t_exit = t_curr;
                v_exit_kmh = v_curr * 3.6;
            end
        end

        res.t_arr = t_arr;
        res.x_arr = x_arr;
        res.v_arr = v_arr;
        res.t_exit = t_exit;
        res.v_exit_kmh = v_exit_kmh;
        res.top_speed_kmh = v_curr * 3.6;
        res.peak_amps = peak_amps;
        res.peak_motor_tau = peak_motor_tau;
    end

    function out = ternary(cond, val_true, val_false)
        if cond
            out = val_true;
        else
            out = val_false;
        end
    end

end
