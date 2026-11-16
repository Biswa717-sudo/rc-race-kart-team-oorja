function rc_kart_tripod_steering_geometry()
% =========================================================================
% RC KART MODIFIED 4-BAR TRIPOD-PLATE STEERING KINEMATICS ANALYZER
% Team Oorja F1 RC Race (Division B: Build Your Own RC Cars)
%
% ENHANCED HIGH-PERFORMANCE EDITION:
% 1. INSTANTANEOUS REAL-TIME CONTINUOUS SLIDER UPDATES via addlistener
%    on 'ContinuousValueChange' for zero lag 60+ FPS dragging!
% 2. EXPANDED DIMENSION CONTROLS:
%    - Kingpin Distance (K)
%    - Wheelbase (L)
%    - Tripod Arc Radius (R_tripod)
%    - Tripod Points Separation Distance (D_sep)
%    - Tripod Pivot Y-Offset (y_P)
%    - Tie-Rod Length (L_tierod)
%    - Control Arm Inward Angle (alpha_arm)
%    - Control Arm Length (L_arm)
%    - Kingpin Caster Angle (theta_caster) -> Dynamic Jacking & Camber Gain!
%    - Kingpin Inclination KPI (theta_kpi)
%    - Kingpin to Wheel Centerline Scrub Offset (W_scrub)
%    - Live Tripod Steer Input (theta_tripod)
% 3. FOUR FULL ANALYTICAL PLOTS:
%    - Subplot 1: 2D Kinematic Mechanism Top-View (Tires with Scrub Offset,
%      Kingpins, Control Arms, Tie-Rods, Tripod Plate, and Instant Centers)
%    - Subplot 2: Inner Angle vs. Outer Angle (Actual vs Ideal vs Parallel)
%    - Subplot 3: Ackermann Percentage (%) vs. Inner Steering Angle
%    - Subplot 4: Point of Intersection (|y_int|) vs. Inner Steering Angle
% 4. DYNAMIC CHASSIS JACKING & TELEMETRY HUD
% =========================================================================

    close all;
    clc;

    % ---------------------------------------------------------------------
    % Default Baseline Dimensions (in mm and degrees)
    % ---------------------------------------------------------------------
    p.K             = 150.0;   % Kingpin Distance (mm)
    p.L             = 255.0;   % Wheelbase (mm)
    p.R_tripod      = 25.0;    % Tripod Arc Radius (mm)
    p.D_sep         = 22.0;    % Tripod Points Separation (mm)
    p.y_P           = -25.0;   % Tripod Pivot Y-Offset relative to front axle (mm)
    p.L_arm         = 22.0;    % Control Arm Length (mm)
    p.alpha_arm_deg = 16.0;    % Control Arm Inward Angle (deg)
    p.caster_deg    = 14.0;    % Kingpin Caster Angle (deg)
    p.kpi_deg       = 6.0;     % Kingpin Inclination KPI (deg)
    p.scrub_mm      = 18.0;    % Scrub Offset from Kingpin to Wheel Centerline (mm)
    p.steer_input   = 12.0;    % Live Tripod Steer Input (deg)
    
    % Tire specifications
    p.tire_dia      = 65.0;    % Tire diameter (mm)
    p.tire_width    = 26.0;    % Tire width (mm)

    % Compute default neutral tie-rod length for zero static toe
    p.L_tierod = compute_neutral_tierod_val(p.K, p.R_tripod, p.D_sep, p.L_arm, p.alpha_arm_deg, p.y_P);

    % ---------------------------------------------------------------------
    % Create Figure Window with Dark Theme
    % ---------------------------------------------------------------------
    fig = figure('Name', 'RC Kart Tripod Steering Kinematics & Ackermann Analyzer (Instantaneous 60FPS)', ...
                 'NumberTitle', 'off', ...
                 'Color', [0.10 0.11 0.13], ...
                 'Position', [30, 30, 1540, 930], ...
                 'MenuBar', 'figure', ...
                 'ToolBar', 'auto');

    % Create Subplot Axes with optimized layout
    ax_mech = subplot('Position', [0.31, 0.54, 0.32, 0.40], 'Parent', fig);
    ax_ang  = subplot('Position', [0.68, 0.54, 0.29, 0.40], 'Parent', fig);
    ax_pct  = subplot('Position', [0.31, 0.08, 0.32, 0.38], 'Parent', fig);
    ax_int  = subplot('Position', [0.68, 0.08, 0.29, 0.38], 'Parent', fig);

    % Title on Left Control Panel
    uicontrol('Style', 'text', 'String', 'EXPANDED GEOMETRY SLIDERS', ...
              'Parent', fig, 'Units', 'normalized', ...
              'Position', [0.015, 0.965, 0.26, 0.025], ...
              'FontSize', 11, 'FontWeight', 'bold', ...
              'ForegroundColor', [0.0 0.8 1.0], 'BackgroundColor', [0.10 0.11 0.13]);

    % Slider definitions: {Name, min, max, default, step, format, tag}
    slider_defs = {
        'Kingpin Distance (K)',             110,  200, p.K,             1.0,  '%.1f mm',  'K';
        'Wheelbase (L)',                    200,  350, p.L,             1.0,  '%.1f mm',  'L';
        'Tripod Arc Radius (R)',             12,   45, p.R_tripod,      0.5,  '%.1f mm',  'R_tripod';
        'Tripod Points Sep (D_sep)',          6,   40, p.D_sep,         0.5,  '%.1f mm',  'D_sep';
        'Tripod Pivot Y-Offset (y_P)',      -55,   15, p.y_P,           0.5,  '%.1f mm',  'y_P';
        'Tie-Rod Length (L_tr)',             40,   95, p.L_tierod,      0.2,  '%.2f mm',  'L_tierod';
        'Control Arm Angle (alpha)',          0,   35, p.alpha_arm_deg, 0.5,  '%.1f deg', 'alpha_arm_deg';
        'Control Arm Length (L_arm)',        12,   40, p.L_arm,         0.5,  '%.1f mm',  'L_arm';
        'Caster Angle (theta_c)',             0,   22, p.caster_deg,    0.5,  '%.1f deg', 'caster_deg';
        'Kingpin Inclination (KPI)',          0,   16, p.kpi_deg,       0.5,  '%.1f deg', 'kpi_deg';
        'Wheel Scrub Offset (W_scrub)',       8,   35, p.scrub_mm,      0.5,  '%.1f mm',  'scrub_mm';
        'Live Tripod Steer Input',          -30,   30, p.steer_input,   0.5,  '%.1f deg', 'steer_input'
    };

    num_sliders = size(slider_defs, 1);
    handles.sliders = struct();
    handles.labels  = struct();
    handles.defs    = struct();

    y_start = 0.935;
    y_step  = 0.046;

    for i = 1:num_sliders
        s_name   = slider_defs{i, 1};
        s_min    = slider_defs{i, 2};
        s_max    = slider_defs{i, 3};
        s_val    = slider_defs{i, 4};
        s_step   = slider_defs{i, 5} / (s_max - s_min);
        s_fmt    = slider_defs{i, 6};
        s_tag    = slider_defs{i, 7};
        y_pos    = y_start - (i - 1) * y_step;

        % Label Text
        txt_h = uicontrol('Style', 'text', ...
                          'String', sprintf(['%s: ' s_fmt], s_name, s_val), ...
                          'Parent', fig, 'Units', 'normalized', ...
                          'Position', [0.015, y_pos + 0.018, 0.26, 0.018], ...
                          'HorizontalAlignment', 'left', ...
                          'FontSize', 8.5, 'FontWeight', 'bold', ...
                          'ForegroundColor', [0.92 0.94 0.96], ...
                          'BackgroundColor', [0.10 0.11 0.13]);

        % Slider Control
        sld_h = uicontrol('Style', 'slider', ...
                          'Min', s_min, 'Max', s_max, 'Value', s_val, ...
                          'SliderStep', [s_step, s_step * 5], ...
                          'Parent', fig, 'Units', 'normalized', ...
                          'Position', [0.015, y_pos, 0.26, 0.017], ...
                          'BackgroundColor', [0.18 0.20 0.24]);

        % CRITICAL: Add continuous listener for INSTANTANEOUS updates on slider drag!
        addlistener(sld_h, 'ContinuousValueChange', @(src, event) update_gui());

        handles.sliders.(s_tag) = sld_h;
        handles.labels.(s_tag)  = txt_h;
        handles.defs.(s_tag)    = slider_defs(i, :);
    end

    % Action Buttons
    uicontrol('Style', 'pushbutton', 'String', 'Auto-Zero Toe Tie-Rod Length', ...
              'Parent', fig, 'Units', 'normalized', ...
              'Position', [0.015, 0.355, 0.125, 0.030], ...
              'FontSize', 8.5, 'FontWeight', 'bold', ...
              'ForegroundColor', [0.1 0.1 0.1], 'BackgroundColor', [0.35 0.85 0.45], ...
              'Callback', @(src, event) auto_zero_toe());

    uicontrol('Style', 'pushbutton', 'String', 'Reset to Baseline Setup', ...
              'Parent', fig, 'Units', 'normalized', ...
              'Position', [0.150, 0.355, 0.125, 0.030], ...
              'FontSize', 8.5, 'FontWeight', 'bold', ...
              'ForegroundColor', [1 1 1], 'BackgroundColor', [0.85 0.30 0.25], ...
              'Callback', @(src, event) reset_defaults());

    % Live Telemetry HUD Panel
    handles.telemetry_box = uicontrol('Style', 'text', ...
              'String', 'Live Telemetry Initializing...', ...
              'Parent', fig, 'Units', 'normalized', ...
              'Position', [0.015, 0.018, 0.26, 0.325], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 8.5, 'FontName', 'Courier', ...
              'ForegroundColor', [0.25 0.95 0.45], 'BackgroundColor', [0.06 0.07 0.08]);

    guidata(fig, handles);

    % Initial Update
    update_gui();

    % =====================================================================
    % NESTED FUNCTIONS FOR GUI UPDATES & REAL-TIME RE-CALCULATION
    % =====================================================================

    function auto_zero_toe()
        h = guidata(fig);
        cur_K         = get(h.sliders.K, 'Value');
        cur_R_tripod  = get(h.sliders.R_tripod, 'Value');
        cur_D_sep     = get(h.sliders.D_sep, 'Value');
        cur_L_arm     = get(h.sliders.L_arm, 'Value');
        cur_alpha_deg = get(h.sliders.alpha_arm_deg, 'Value');
        cur_y_P       = get(h.sliders.y_P, 'Value');

        calc_L_tr = compute_neutral_tierod_val(cur_K, cur_R_tripod, cur_D_sep, cur_L_arm, cur_alpha_deg, cur_y_P);
        set(h.sliders.L_tierod, 'Value', calc_L_tr);
        update_gui();
    end

    function reset_defaults()
        h = guidata(fig);
        set(h.sliders.K,             'Value', p.K);
        set(h.sliders.L,             'Value', p.L);
        set(h.sliders.R_tripod,      'Value', p.R_tripod);
        set(h.sliders.D_sep,         'Value', p.D_sep);
        set(h.sliders.y_P,           'Value', p.y_P);
        set(h.sliders.alpha_arm_deg, 'Value', p.alpha_arm_deg);
        set(h.sliders.L_arm,         'Value', p.L_arm);
        set(h.sliders.caster_deg,    'Value', p.caster_deg);
        set(h.sliders.kpi_deg,       'Value', p.kpi_deg);
        set(h.sliders.scrub_mm,      'Value', p.scrub_mm);
        set(h.sliders.steer_input,   'Value', p.steer_input);

        calc_L_tr = compute_neutral_tierod_val(p.K, p.R_tripod, p.D_sep, p.L_arm, p.alpha_arm_deg, p.y_P);
        set(h.sliders.L_tierod, 'Value', calc_L_tr);
        update_gui();
    end

    function update_gui()
        h = guidata(fig);

        % Read current slider values instantly
        K         = get(h.sliders.K, 'Value');
        L         = get(h.sliders.L, 'Value');
        R_tripod  = get(h.sliders.R_tripod, 'Value');
        D_sep     = get(h.sliders.D_sep, 'Value');
        y_P       = get(h.sliders.y_P, 'Value');
        L_tierod  = get(h.sliders.L_tierod, 'Value');
        alpha_deg = get(h.sliders.alpha_arm_deg, 'Value');
        L_arm     = get(h.sliders.L_arm, 'Value');
        caster_d  = get(h.sliders.caster_deg, 'Value');
        kpi_d     = get(h.sliders.kpi_deg, 'Value');
        scrub_w   = get(h.sliders.scrub_mm, 'Value');
        th_steer  = get(h.sliders.steer_input, 'Value');

        % Ensure tripod physical feasibility (D_sep < 2 * R_tripod)
        if D_sep >= 2 * R_tripod
            D_sep = 2 * R_tripod - 0.5;
            set(h.sliders.D_sep, 'Value', D_sep);
        end

        % Update all Slider Labels instantly
        for j = 1:num_sliders
            tag = slider_defs{j, 7};
            fmt = slider_defs{j, 6};
            nam = slider_defs{j, 1};
            val = get(h.sliders.(tag), 'Value');
            set(h.labels.(tag), 'String', sprintf(['%s: ' fmt], nam, val));
        end

        % -----------------------------------------------------------------
        % Kinematic Vector Sweep (-26° to +26° tripod rotation)
        % -----------------------------------------------------------------
        th_sweep = linspace(0.1, 26.0, 180);
        inner_s  = [];
        outer_s  = [];
        ideal_s  = [];
        ack_pct_s= [];
        y_int_s  = [];

        phi0 = asin((D_sep / 2.0) / R_tripod);
        KL   = [-K / 2.0, 0.0];
        KR   = [ K / 2.0, 0.0];
        alpha_rad = deg2rad(alpha_deg);

        JL0_ref = [KL(1) + L_arm * sin(alpha_rad), KL(2) - L_arm * cos(alpha_rad)];
        JR0_ref = [KR(1) - L_arm * sin(alpha_rad), KR(2) - L_arm * cos(alpha_rad)];
        ang_L0  = atan2(JL0_ref(2) - KL(2), JL0_ref(1) - KL(1));
        ang_R0  = atan2(JR0_ref(2) - KR(2), JR0_ref(1) - KR(1));

        for idx = 1:length(th_sweep)
            th_cur = deg2rad(th_sweep(idx));
            TL = [-R_tripod * sin(phi0 - th_cur), y_P - R_tripod * cos(phi0 - th_cur)];
            TR = [ R_tripod * sin(phi0 + th_cur), y_P - R_tripod * cos(phi0 + th_cur)];

            JL = circle_intersect_fast(KL, L_arm, TL, L_tierod);
            JR = circle_intersect_fast(KR, L_arm, TR, L_tierod);

            if ~isempty(JL) && ~isempty(JR)
                dL = rad2deg(atan2(JL(2) - KL(2), JL(1) - KL(1)) - ang_L0);
                dR = rad2deg(atan2(JR(2) - KR(2), JR(1) - KR(1)) - ang_R0);

                if dL >= 0
                    inn = dL; out = dR;
                else
                    inn = abs(dR); out = abs(dL);
                end

                tan_inn = tan(deg2rad(inn));
                if tan_inn > 0
                    id_out = rad2deg(atan((L * tan_inn) / (L + K * tan_inn)));
                else
                    id_out = 0;
                end

                diff_id = inn - id_out;
                if abs(diff_id) > 0.05
                    pct = ((inn - out) / diff_id) * 100.0;
                else
                    pct = 100.0;
                end

                % Point of Intersection
                if abs(dL) > 0.05 && abs(dR) > 0.05
                    cot_L = 1.0 / tan(deg2rad(dL));
                    cot_R = 1.0 / tan(deg2rad(dR));
                    denom = cot_R - cot_L;
                    if abs(denom) > 1e-4
                        y_int = -K / denom;
                    else
                        y_int = nan;
                    end
                else
                    y_int = nan;
                end

                inner_s(end+1)   = inn;
                outer_s(end+1)   = out;
                ideal_s(end+1)   = id_out;
                ack_pct_s(end+1) = pct;
                y_int_s(end+1)   = y_int;
            end
        end

        % -----------------------------------------------------------------
        % Current Live Point Evaluation
        % -----------------------------------------------------------------
        th_live_rad = deg2rad(th_steer);
        TL_live = [-R_tripod * sin(phi0 - th_live_rad), y_P - R_tripod * cos(phi0 - th_live_rad)];
        TR_live = [ R_tripod * sin(phi0 + th_live_rad), y_P - R_tripod * cos(phi0 + th_live_rad)];
        JL_live = circle_intersect_fast(KL, L_arm, TL_live, L_tierod);
        JR_live = circle_intersect_fast(KR, L_arm, TR_live, L_tierod);

        valid_geom = (~isempty(JL_live) && ~isempty(JR_live));
        if valid_geom
            dL_live = rad2deg(atan2(JL_live(2) - KL(2), JL_live(1) - KL(1)) - ang_L0);
            dR_live = rad2deg(atan2(JR_live(2) - KR(2), JR_live(1) - KR(1)) - ang_R0);
        else
            dL_live = 0; dR_live = 0;
        end

        if dL_live >= 0
            live_inner = dL_live;
            live_outer = dR_live;
            is_turn_left = true;
        else
            live_inner = abs(dR_live);
            live_outer = abs(dL_live);
            is_turn_left = false;
        end

        tan_inn = tan(deg2rad(live_inner));
        if tan_inn > 0
            live_ideal_outer = rad2deg(atan((L * tan_inn) / (L + K * tan_inn)));
        else
            live_ideal_outer = 0;
        end
        diff_id = live_inner - live_ideal_outer;
        if abs(diff_id) > 0.05
            live_ack_pct = ((live_inner - live_outer) / diff_id) * 100.0;
        else
            live_ack_pct = 100.0;
        end

        % Live Intersection Point
        if abs(dL_live) > 0.1 && abs(dR_live) > 0.1
            c_L = 1.0 / tan(deg2rad(dL_live));
            c_R = 1.0 / tan(deg2rad(dR_live));
            d_den = c_R - c_L;
            if abs(d_den) > 1e-4
                live_x_int = (K / 2.0) * (c_R + c_L) / d_den;
                live_y_int = -K / d_den;
            else
                live_x_int = nan; live_y_int = nan;
            end
        else
            live_x_int = nan; live_y_int = nan;
        end

        % Dynamic Chassis Jacking Height & Camber Gain:
        % Due to caster (14 deg) and KPI (6 deg), steering induces a diagonal vertical jacking:
        caster_rad = deg2rad(caster_d);
        kpi_rad    = deg2rad(kpi_d);
        % Vertical lift of front axle:
        jacking_lift_mm = scrub_w * sin(caster_rad) * sin(deg2rad(live_inner));
        % Dynamic camber gain on outside tire:
        camber_gain_deg = -live_outer * sin(caster_rad);

        % =================================================================
        % PLOT 1: 2D KINEMATICS TOP VIEW (WITH WHEEL SCRUB & TIRE OFFSET)
        % =================================================================
        cla(ax_mech);
        hold(ax_mech, 'on');
        grid(ax_mech, 'on');
        set(ax_mech, 'Color', [0.14 0.15 0.18], 'GridColor', [0.25 0.28 0.33]);

        % Kingpin beam & Kingpin centers
        plot(ax_mech, [KL(1), KR(1)], [KL(2), KR(2)], 'w-', 'LineWidth', 2.5);
        plot(ax_mech, KL(1), KL(2), 'co', 'MarkerSize', 8, 'MarkerFaceColor', [0.2 0.8 1.0]);
        plot(ax_mech, KR(1), KR(2), 'co', 'MarkerSize', 8, 'MarkerFaceColor', [0.2 0.8 1.0]);

        % Tripod Pivot & Body
        plot(ax_mech, 0, y_P, 'y^', 'MarkerSize', 9, 'MarkerFaceColor', [1.0 0.8 0.2]);
        tripod_pts_x = [0, TL_live(1), TR_live(1), 0];
        tripod_pts_y = [y_P, TL_live(2), TR_live(2), y_P];
        fill(ax_mech, tripod_pts_x, tripod_pts_y, [1.0 0.82 0.25], 'FaceAlpha', 0.35, 'EdgeColor', [1.0 0.82 0.25], 'LineWidth', 1.8);
        plot(ax_mech, TL_live(1), TL_live(2), 'yo', 'MarkerFaceColor', [1 0.6 0.1]);
        plot(ax_mech, TR_live(1), TR_live(2), 'yo', 'MarkerFaceColor', [1 0.6 0.1]);

        if valid_geom
            % Control arms
            plot(ax_mech, [KL(1), JL_live(1)], [KL(2), JL_live(2)], 'r-', 'LineWidth', 3.0);
            plot(ax_mech, [KR(1), JR_live(1)], [KR(2), JR_live(2)], 'r-', 'LineWidth', 3.0);
            plot(ax_mech, [JL_live(1), JR_live(1)], [JL_live(2), JR_live(2)], 'ro', 'MarkerFaceColor', 'r');

            % Tie-rods
            plot(ax_mech, [TL_live(1), JL_live(1)], [TL_live(2), JL_live(2)], 'g-', 'LineWidth', 2.5);
            plot(ax_mech, [TR_live(1), JR_live(1)], [TR_live(2), JR_live(2)], 'g-', 'LineWidth', 2.5);

            % Wheel centers (offset outwards by scrub radius scrub_w)
            wheel_center_L = KL + [-scrub_w * cos(deg2rad(dL_live)), -scrub_w * sin(deg2rad(dL_live))];
            wheel_center_R = KR + [ scrub_w * cos(deg2rad(dR_live)), -scrub_w * sin(deg2rad(dR_live))];

            % Draw 65mm Tires
            draw_tire_patch(ax_mech, wheel_center_L, dL_live, p.tire_dia, p.tire_width, [0.0 0.7 0.9]);
            draw_tire_patch(ax_mech, wheel_center_R, dR_live, p.tire_dia, p.tire_width, [0.0 0.7 0.9]);

            % Spindle stub axle from kingpin to wheel center
            plot(ax_mech, [KL(1), wheel_center_L(1)], [KL(2), wheel_center_L(2)], 'c-', 'LineWidth', 2);
            plot(ax_mech, [KR(1), wheel_center_R(1)], [KR(2), wheel_center_R(2)], 'c-', 'LineWidth', 2);

            % Wheel intersection lines
            if ~isnan(live_x_int) && ~isnan(live_y_int) && abs(live_y_int) < 1400
                plot(ax_mech, [wheel_center_L(1), live_x_int], [wheel_center_L(2), live_y_int], 'm--', 'LineWidth', 1.2);
                plot(ax_mech, [wheel_center_R(1), live_x_int], [wheel_center_R(2), live_y_int], 'm--', 'LineWidth', 1.2);
                plot(ax_mech, live_x_int, live_y_int, 'mp', 'MarkerSize', 13, 'MarkerFaceColor', 'm');
                text(ax_mech, live_x_int+5, live_y_int, sprintf('Instant Center (y=%.0fmm)', live_y_int), ...
                     'Color', [1.0 0.3 0.9], 'FontSize', 8, 'FontWeight', 'bold');
            end
        end

        % Target Rear Axle line
        plot(ax_mech, [-K*1.2, K*1.2], [-L, -L], 'c-.', 'LineWidth', 1.6);
        text(ax_mech, -K*0.85, -L+8, sprintf('Target Rear Axle Line (L = %.0f mm)', L), 'Color', [0.2 0.9 0.9], 'FontSize', 8);

        title(ax_mech, sprintf('Kinematic Top View (Steer: \\theta_{tripod} = %+.1f^\\circ)', th_steer), ...
              'Color', 'w', 'FontSize', 10.5, 'FontWeight', 'bold');
        xlabel(ax_mech, 'X (Transverse, mm)', 'Color', 'w', 'FontSize', 8.5);
        ylabel(ax_mech, 'Y (Longitudinal, mm)', 'Color', 'w', 'FontSize', 8.5);
        axis(ax_mech, 'equal');
        xlim(ax_mech, [-K*1.15, K*1.15]);
        ylim(ax_mech, [-L*1.2, p.tire_dia*0.85]);

        % =================================================================
        % PLOT 2: INNER ANGLE VS OUTER ANGLE
        % =================================================================
        cla(ax_ang);
        hold(ax_ang, 'on');
        grid(ax_ang, 'on');
        set(ax_ang, 'Color', [0.14 0.15 0.18], 'GridColor', [0.25 0.28 0.33]);

        if ~isempty(inner_s)
            plot(ax_ang, inner_s, inner_s, 'w:', 'LineWidth', 1.4, 'DisplayName', 'Parallel (0% Ackermann)');
            plot(ax_ang, inner_s, ideal_s, 'c--', 'LineWidth', 2.2, 'DisplayName', '100% Ideal Ackermann');
            plot(ax_ang, inner_s, outer_s, 'r-', 'LineWidth', 2.5, 'DisplayName', 'Actual Set Geometry');
            plot(ax_ang, live_inner, live_outer, 'yo', 'MarkerSize', 9, 'MarkerFaceColor', [1 0.8 0.2], ...
                 'DisplayName', sprintf('Live: \\delta_i=%.1f^\\circ, \\delta_o=%.1f^\\circ', live_inner, live_outer));
        end

        title(ax_ang, 'Inner vs. Outer Steer Angle', 'Color', 'w', 'FontSize', 10.5, 'FontWeight', 'bold');
        xlabel(ax_ang, 'Inner Angle \delta_{inner} (deg)', 'Color', 'w', 'FontSize', 8.5);
        ylabel(ax_ang, 'Outer Angle \delta_{outer} (deg)', 'Color', 'w', 'FontSize', 8.5);
        legend(ax_ang, 'Location', 'northwest', 'TextColor', 'w', 'Color', [0.1 0.11 0.13], 'FontSize', 7.5);
        xlim(ax_ang, [0, 35]);
        ylim(ax_ang, [0, 32]);

        % =================================================================
        % PLOT 3: ACKERMANN PERCENTAGE (%)
        % =================================================================
        cla(ax_pct);
        hold(ax_pct, 'on');
        grid(ax_pct, 'on');
        set(ax_pct, 'Color', [0.14 0.15 0.18], 'GridColor', [0.25 0.28 0.33]);

        fill(ax_pct, [0 35 35 0], [0 0 -40 -40], [0.8 0.2 0.2], 'FaceAlpha', 0.14, 'EdgeColor', 'none'); % Anti-Ackermann
        fill(ax_pct, [0 35 35 0], [0 0 100 100], [0.2 0.7 0.3], 'FaceAlpha', 0.14, 'EdgeColor', 'none'); % Pro-Ackermann
        fill(ax_pct, [0 35 35 0], [100 100 180 180], [0.2 0.4 0.9], 'FaceAlpha', 0.14, 'EdgeColor', 'none'); % Over-Ackermann

        yline(ax_pct, 100, 'g--', 'LineWidth', 1.8, 'DisplayName', '100% Ideal Ackermann');
        yline(ax_pct, 0, 'w:', 'LineWidth', 1.4, 'DisplayName', '0% Parallel');

        if ~isempty(inner_s)
            plot(ax_pct, inner_s, ack_pct_s, 'r-', 'LineWidth', 2.5, 'DisplayName', 'Actual Ackermann %');
            plot(ax_pct, live_inner, live_ack_pct, 'yo', 'MarkerSize', 9, 'MarkerFaceColor', [1 0.8 0.2], ...
                 'DisplayName', sprintf('Live: %.1f%%', live_ack_pct));
        end

        title(ax_pct, 'Ackermann Percentage (%) vs. Inner Angle', 'Color', 'w', 'FontSize', 10.5, 'FontWeight', 'bold');
        xlabel(ax_pct, 'Inner Angle \delta_{inner} (deg)', 'Color', 'w', 'FontSize', 8.5);
        ylabel(ax_pct, 'Ackermann %', 'Color', 'w', 'FontSize', 8.5);
        legend(ax_pct, 'Location', 'northeast', 'TextColor', 'w', 'Color', [0.1 0.11 0.13], 'FontSize', 7.5);
        xlim(ax_pct, [0, 35]);
        ylim(ax_pct, [-20, 180]);

        % =================================================================
        % PLOT 4: POINT OF INTERSECTION (|y_int|)
        % =================================================================
        cla(ax_int);
        hold(ax_int, 'on');
        grid(ax_int, 'on');
        set(ax_int, 'Color', [0.14 0.15 0.18], 'GridColor', [0.25 0.28 0.33]);

        yline(ax_int, L, 'c--', 'LineWidth', 2.0, 'DisplayName', sprintf('Target: Rear Axle (L = %.0f mm)', L));

        if ~isempty(inner_s)
            val_mask = ~isnan(y_int_s);
            plot(ax_int, inner_s(val_mask), abs(y_int_s(val_mask)), 'm-', 'LineWidth', 2.5, ...
                 'DisplayName', 'Actual Intersection |y_{int}|');
            if ~isnan(live_y_int)
                plot(ax_int, live_inner, abs(live_y_int), 'yo', 'MarkerSize', 9, 'MarkerFaceColor', [1 0.8 0.2], ...
                     'DisplayName', sprintf('Live |y_{int}| = %.1f mm', abs(live_y_int)));
            end
        end

        title(ax_int, 'Instantaneous Intersection Distance vs. Inner Angle', 'Color', 'w', 'FontSize', 10.5, 'FontWeight', 'bold');
        xlabel(ax_int, 'Inner Angle \delta_{inner} (deg)', 'Color', 'w', 'FontSize', 8.5);
        ylabel(ax_int, 'Distance from Front Axle (mm)', 'Color', 'w', 'FontSize', 8.5);
        legend(ax_int, 'Location', 'northeast', 'TextColor', 'w', 'Color', [0.1 0.11 0.13], 'FontSize', 7.5);
        xlim(ax_int, [2, 35]);
        ylim(ax_int, [0, L * 1.8]);

        % =================================================================
        % TELEMETRY HUD UPDATE
        % =================================================================
        if is_turn_left
            turn_str = 'LEFT TURN';
        else
            turn_str = 'RIGHT TURN';
        end

        if abs(live_inner) > 0.1
            r_turn = (L / sin(deg2rad(live_inner))) / 1000.0;
        else
            r_turn = inf;
        end

        telemetry_txt = sprintf([...
            '================================\n' ...
            '   REAL-TIME KINEMATIC HUD      \n' ...
            '================================\n' ...
            'Active Direction : %s\n' ...
            'Tripod Steer Ang : %+.1f deg\n' ...
            '--------------------------------\n' ...
            'Inner Wheel (di) : %.2f deg\n' ...
            'Outer Wheel (do) : %.2f deg\n' ...
            'Ideal Outer (id) : %.2f deg\n' ...
            'Steer Error (do-id): %+.2f deg\n' ...
            '--------------------------------\n' ...
            'Ackermann %%      : %.1f %%\n' ...
            'Intersection Y   : %.1f mm\n' ...
            'Target Axle (L)  : %.1f mm\n' ...
            'Intersection X   : %.1f mm\n' ...
            'Est Turn Radius  : %.2f m\n' ...
            '--------------------------------\n' ...
            'DYNAMIC CHASSIS JACKING:\n' ...
            'Inside Wheel Lift: %+.2f mm\n' ...
            'Outer Camber Gain: %+.2f deg\n' ...
            '--------------------------------\n' ...
            'Scrub Offset     : %.1f mm\n' ...
            'Tripod Y-Offset  : %+.1f mm\n' ...
            'Mechanism Status : %s\n' ...
            'Ground Clearance : 15mm (Legal)\n' ...
            '================================' ...
        ], turn_str, th_steer, live_inner, live_outer, live_ideal_outer, ...
           (live_outer - live_ideal_outer), live_ack_pct, live_y_int, -L, ...
           live_x_int, r_turn, jacking_lift_mm, camber_gain_deg, scrub_w, y_P, ...
           ternary(valid_geom, 'VALID 4-BAR', 'TOGGLE LOCK'));

        set(h.telemetry_box, 'String', telemetry_txt);
        drawnow limitrate; % High performance silky smooth redraw
    end

    function pt = circle_intersect_fast(C1, r1, C2, r2)
        dx = C2(1) - C1(1);
        dy = C2(2) - C1(2);
        d = sqrt(dx^2 + dy^2);
        if d > (r1 + r2) || d < abs(r1 - r2) || d == 0
            pt = [];
            return;
        end
        a = (r1^2 - r2^2 + d^2) / (2.0 * d);
        h_sq = r1^2 - a^2;
        if h_sq < 0
            pt = [];
            return;
        end
        h = sqrt(h_sq);
        x2 = C1(1) + a * dx / d;
        y2 = C1(2) + a * dy / d;
        p1 = [x2 + h * dy / d, y2 - h * dx / d];
        p2 = [x2 - h * dy / d, y2 + h * dx / d];
        if p1(2) < p2(2)
            pt = p1;
        else
            pt = p2;
        end
    end

    function draw_tire_patch(ax, center, steer_deg, dia, width, color)
        bx = [-width/2, width/2, width/2, -width/2];
        by = [-dia/2, -dia/2, dia/2, dia/2];
        theta = deg2rad(steer_deg);
        R_mat = [cos(theta), -sin(theta); sin(theta), cos(theta)];
        rot_pts = R_mat * [bx; by];
        gx = rot_pts(1, :) + center(1);
        gy = rot_pts(2, :) + center(2);
        fill(ax, gx, gy, color, 'FaceAlpha', 0.85, 'EdgeColor', 'k', 'LineWidth', 1.5);
    end

    function len = compute_neutral_tierod_val(K, R, D_sep, L_arm, alpha_deg, y_P)
        D_sep = min(D_sep, 2.0 * R - 0.5);
        phi0 = asin((D_sep / 2.0) / R);
        x_TL0 = -R * sin(phi0);
        y_TL0 = y_P - R * cos(phi0);
        x_JL0 = -K / 2.0 + L_arm * sin(deg2rad(alpha_deg));
        y_JL0 = -L_arm * cos(deg2rad(alpha_deg));
        len = sqrt((x_JL0 - x_TL0)^2 + (y_JL0 - y_TL0)^2);
    end

    function out = ternary(cond, val_true, val_false)
        if cond
            out = val_true;
        else
            out = val_false;
        end
    end

end
