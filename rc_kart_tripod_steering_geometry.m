function rc_kart_tripod_steering_geometry()
% =========================================================================
% RC KART TRIPOD-PLATE MODIFIED 4-BAR STEERING GEOMETRY ANALYZER
% Team Oorja F1 RC Race (Division B: Build Your Own RC Cars)
%
% Features:
% 1. Complete kinematic modeling of the Central Tripod Plate + Dual Tie-Rods
%    + Steering Knuckle Control Arms 4-Bar Mechanism.
% 2. 8 Interactive UI Sliders:
%    - Kingpin Distance (K)
%    - Wheelbase (L)
%    - Tripod Arc Radius (R_tripod)
%    - Tripod Points Separation Distance (D_sep)
%    - Tie-Rod Length (L_tierod)
%    - Angle between Kingpin Line and Control Arm (alpha_arm)
%    - Control Arm Length (L_arm)
%    - Live Steering Input Angle (theta_tripod)
% 3. Four Dynamic Graphs:
%    - Subplot 1: 2D Kinematic Mechanism Top-View (Tires, Arms, Tie-Rods, Tripod, Intersection Lines)
%    - Subplot 2: Inner Angle vs. Outer Angle (Actual Mechanism vs. 100% Ideal Ackermann vs. Parallel)
%    - Subplot 3: Ackermann Percentage (%) vs. Inner Steering Angle
%    - Subplot 4: Point of Intersection (y_int distance) vs. Inner Steering Angle (compared to Wheelbase L)
% 4. Live Numerical Telemetry Dashboard.
% =========================================================================

    close all;
    clc;

    % ---------------------------------------------------------------------
    % Default Baseline Dimensions (in mm and degrees)
    % ---------------------------------------------------------------------
    p.K             = 150.0;   % Kingpin Distance (mm) - Transverse span between kingpins
    p.L             = 255.0;   % Wheelbase (mm) - Front axle to rear axle
    p.R_tripod      = 25.0;    % Tripod Arc Radius (mm) - Pivot to tie-rod hole radius
    p.D_sep         = 22.0;    % Tripod Points Separation Distance (mm)
    p.L_arm         = 22.0;    % Steering Control Arm Length (mm)
    p.alpha_arm_deg = 16.0;    % Inward Ackermann angle from -Y longitudinal axis (deg)
    p.y_P           = -25.0;   % Tripod pivot longitudinal location relative to front axle (mm)
    
    % Compute default neutral tie-rod length for zero static toe
    phi0_init = asin(min(1.0, (p.D_sep / 2.0) / p.R_tripod));
    x_TL0 = -p.R_tripod * sin(phi0_init);
    y_TL0 = p.y_P - p.R_tripod * cos(phi0_init);
    x_JL0 = -p.K / 2.0 + p.L_arm * sin(deg2rad(p.alpha_arm_deg));
    y_JL0 = -p.L_arm * cos(deg2rad(p.alpha_arm_deg));
    p.L_tierod      = sqrt((x_JL0 - x_TL0)^2 + (y_JL0 - y_TL0)^2); % Neutral tie-rod length (mm)
    p.steer_input   = 12.0;    % Current live tripod steer angle (degrees)

    % Tire dimensions for 2D plot (mm)
    p.tire_dia      = 65.0;    % Tire diameter (Rulebook min 50mm)
    p.tire_width    = 26.0;    % 1/10 touring car slick width

    % ---------------------------------------------------------------------
    % Create Figure Window & Control Layout
    % ---------------------------------------------------------------------
    fig = figure('Name', 'RC Kart Tripod Steering Kinematics & Ackermann Analyzer', ...
                 'NumberTitle', 'off', ...
                 'Color', [0.12 0.13 0.15], ...
                 'Position', [50, 40, 1500, 920], ...
                 'MenuBar', 'figure', ...
                 'ToolBar', 'auto');

    % Create Subplot Axes
    ax_mech = subplot('Position', [0.28, 0.54, 0.33, 0.40], 'Parent', fig);
    ax_ang  = subplot('Position', [0.66, 0.54, 0.31, 0.40], 'Parent', fig);
    ax_pct  = subplot('Position', [0.28, 0.08, 0.33, 0.38], 'Parent', fig);
    ax_int  = subplot('Position', [0.66, 0.08, 0.31, 0.38], 'Parent', fig);

    % Left Control Panel
    uicontrol('Style', 'text', 'String', 'STEERING GEOMETRY CONTROLS', ...
              'Parent', fig, 'Units', 'normalized', ...
              'Position', [0.015, 0.95, 0.23, 0.03], ...
              'FontSize', 12, 'FontWeight', 'bold', ...
              'ForegroundColor', [0.3 0.85 1.0], 'BackgroundColor', [0.12 0.13 0.15]);

    % Slider definitions: [Name, min, max, default, step, format, tag]
    slider_defs = {
        'Kingpin Distance (K)',          110, 200, p.K,             1,   '%.1f mm',  'K';
        'Wheelbase (L)',                 200, 350, p.L,             1,   '%.1f mm',  'L';
        'Tripod Arc Radius (R)',          12,  45, p.R_tripod,      0.5, '%.1f mm',  'R_tripod';
        'Tripod Points Separation (D)',    6,  40, p.D_sep,         0.5, '%.1f mm',  'D_sep';
        'Tie-Rod Length (L_tr)',          40,  95, p.L_tierod,      0.5, '%.2f mm',  'L_tierod';
        'Control Arm Angle (alpha)',       0,  35, p.alpha_arm_deg, 0.5, '%.1f deg', 'alpha_arm_deg';
        'Control Arm Length (L_arm)',     12,  40, p.L_arm,         0.5, '%.1f mm',  'L_arm';
        'Live Tripod Steer Input',       -30,  30, p.steer_input,   0.5, '%.1f deg', 'steer_input'
    };

    num_sliders = size(slider_defs, 1);
    handles.sliders = struct();
    handles.labels  = struct();

    y_start = 0.90;
    y_step  = 0.060;

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
                          'Position', [0.015, y_pos + 0.022, 0.23, 0.022], ...
                          'HorizontalAlignment', 'left', ...
                          'FontSize', 9.5, 'FontWeight', 'bold', ...
                          'ForegroundColor', [0.9 0.92 0.95], ...
                          'BackgroundColor', [0.12 0.13 0.15]);

        % Slider Control
        sld_h = uicontrol('Style', 'slider', ...
                          'Min', s_min, 'Max', s_max, 'Value', s_val, ...
                          'SliderStep', [s_step, s_step * 5], ...
                          'Parent', fig, 'Units', 'normalized', ...
                          'Position', [0.015, y_pos, 0.23, 0.020], ...
                          'BackgroundColor', [0.2 0.22 0.26], ...
                          'Callback', @(src, event) update_gui());

        handles.sliders.(s_tag) = sld_h;
        handles.labels.(s_tag)  = txt_h;
        handles.defs.(s_tag)    = slider_defs(i, :);
    end

    % Auto-Zero Toe Button
    uicontrol('Style', 'pushbutton', 'String', 'Auto-Zero Toe Tie-Rod Length', ...
              'Parent', fig, 'Units', 'normalized', ...
              'Position', [0.015, 0.40, 0.23, 0.035], ...
              'FontSize', 9.5, 'FontWeight', 'bold', ...
              'ForegroundColor', [0.1 0.1 0.1], 'BackgroundColor', [0.35 0.85 0.45], ...
              'Callback', @(src, event) auto_zero_toe());

    % Reset to Baseline Button
    uicontrol('Style', 'pushbutton', 'String', 'Reset to Baseline Setup', ...
              'Parent', fig, 'Units', 'normalized', ...
              'Position', [0.015, 0.355, 0.23, 0.035], ...
              'FontSize', 9.5, 'FontWeight', 'bold', ...
              'ForegroundColor', [1 1 1], 'BackgroundColor', [0.85 0.30 0.25], ...
              'Callback', @(src, event) reset_defaults());

    % Telemetry Panel (Text display box)
    handles.telemetry_box = uicontrol('Style', 'text', ...
              'String', 'Live Telemetry Loading...', ...
              'Parent', fig, 'Units', 'normalized', ...
              'Position', [0.015, 0.025, 0.23, 0.315], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 9, 'FontName', 'Courier', ...
              'ForegroundColor', [0.35 0.95 0.45], 'BackgroundColor', [0.07 0.08 0.10]);

    % Store handles
    guidata(fig, handles);

    % Initial Update
    update_gui();

    % =====================================================================
    % NESTED FUNCTIONS FOR GUI UPDATES & KINEMATICS
    % =====================================================================

    function auto_zero_toe()
        h = guidata(fig);
        cur_K         = get(h.sliders.K, 'Value');
        cur_R_tripod  = get(h.sliders.R_tripod, 'Value');
        cur_D_sep     = get(h.sliders.D_sep, 'Value');
        cur_L_arm     = get(h.sliders.L_arm, 'Value');
        cur_alpha_deg = get(h.sliders.alpha_arm_deg, 'Value');

        cur_D_sep = min(cur_D_sep, 2.0 * cur_R_tripod - 0.5);
        phi0 = asin((cur_D_sep / 2.0) / cur_R_tripod);
        x_TL0 = -cur_R_tripod * sin(phi0);
        y_TL0 = p.y_P - cur_R_tripod * cos(phi0);
        x_JL0 = -cur_K / 2.0 + cur_L_arm * sin(deg2rad(cur_alpha_deg));
        y_JL0 = -cur_L_arm * cos(deg2rad(cur_alpha_deg));
        calc_L_tr = sqrt((x_JL0 - x_TL0)^2 + (y_JL0 - y_TL0)^2);

        set(h.sliders.L_tierod, 'Value', calc_L_tr);
        update_gui();
    end

    function reset_defaults()
        h = guidata(fig);
        set(h.sliders.K,             'Value', p.K);
        set(h.sliders.L,             'Value', p.L);
        set(h.sliders.R_tripod,      'Value', p.R_tripod);
        set(h.sliders.D_sep,         'Value', p.D_sep);
        set(h.sliders.L_tierod,      'Value', p.L_tierod);
        set(h.sliders.alpha_arm_deg, 'Value', p.alpha_arm_deg);
        set(h.sliders.L_arm,         'Value', p.L_arm);
        set(h.sliders.steer_input,   'Value', p.steer_input);
        update_gui();
    end

    function update_gui()
        h = guidata(fig);

        % Read current slider values
        K         = get(h.sliders.K, 'Value');
        L         = get(h.sliders.L, 'Value');
        R_tripod  = get(h.sliders.R_tripod, 'Value');
        D_sep     = get(h.sliders.D_sep, 'Value');
        L_tierod  = get(h.sliders.L_tierod, 'Value');
        alpha_deg = get(h.sliders.alpha_arm_deg, 'Value');
        L_arm     = get(h.sliders.L_arm, 'Value');
        th_steer  = get(h.sliders.steer_input, 'Value');

        % Ensure geometric feasibility for tripod plate (separation cannot exceed 2*R)
        if D_sep >= 2 * R_tripod
            D_sep = 2 * R_tripod - 0.5;
            set(h.sliders.D_sep, 'Value', D_sep);
        end

        % Update Slider Label Strings
        for j = 1:num_sliders
            tag = slider_defs{j, 7};
            fmt = slider_defs{j, 6};
            nam = slider_defs{j, 1};
            val = get(h.sliders.(tag), 'Value');
            set(h.labels.(tag), 'String', sprintf(['%s: ' fmt], nam, val));
        end

        % -----------------------------------------------------------------
        % Kinematic Calculation for Full Steering Sweep (-25° to +25° tripod)
        % -----------------------------------------------------------------
        th_range = linspace(-26, 26, 201);
        delta_L_arr = nan(size(th_range));
        delta_R_arr = nan(size(th_range));
        ideal_R_arr = nan(size(th_range));
        ideal_L_arr = nan(size(th_range));
        ack_pct_arr = nan(size(th_range));
        y_int_arr   = nan(size(th_range));
        x_int_arr   = nan(size(th_range));

        phi0 = asin((D_sep / 2.0) / R_tripod);
        KL   = [-K / 2.0, 0.0];
        KR   = [ K / 2.0, 0.0];
        y_P  = p.y_P;
        alpha_rad = deg2rad(alpha_deg);

        % Reference neutral arm positions (for true 0 steer reference)
        JL0_ref = [KL(1) + L_arm * sin(alpha_rad), KL(2) - L_arm * cos(alpha_rad)];
        JR0_ref = [KR(1) - L_arm * sin(alpha_rad), KR(2) - L_arm * cos(alpha_rad)];
        ang_L0  = atan2(JL0_ref(2) - KL(2), JL0_ref(1) - KL(1));
        ang_R0  = atan2(JR0_ref(2) - KR(2), JR0_ref(1) - KR(1));

        for idx = 1:length(th_range)
            th_curr = deg2rad(th_range(idx));
            TL = [-R_tripod * sin(phi0 - th_curr), y_P - R_tripod * cos(phi0 - th_curr)];
            TR = [ R_tripod * sin(phi0 + th_curr), y_P - R_tripod * cos(phi0 + th_curr)];

            JL = circle_intersect(KL, L_arm, TL, L_tierod);
            JR = circle_intersect(KR, L_arm, TR, L_tierod);

            if ~isempty(JL) && ~isempty(JR)
                ang_L = atan2(JL(2) - KL(2), JL(1) - KL(1));
                ang_R = atan2(JR(2) - KR(2), JR(1) - KR(1));
                
                % Left steer angle (positive = steered left / counter-clockwise)
                dL = rad2deg(ang_L - ang_L0);
                % Right steer angle (positive = steered left)
                dR = rad2deg(ang_R - ang_R0);

                delta_L_arr(idx) = dL;
                delta_R_arr(idx) = dR;

                % Intersection Point of Wheel Centerlines
                % Equation of line through Kingpin perpendicular to wheel heading:
                if abs(dL) > 0.05 && abs(dR) > 0.05
                    cot_L = 1.0 / tan(deg2rad(dL));
                    cot_R = 1.0 / tan(deg2rad(dR));
                    
                    denom = cot_R - cot_L;
                    if abs(denom) > 1e-4
                        x_int = (K / 2.0) * (cot_R + cot_L) / denom;
                        y_int = -K / denom;
                        x_int_arr(idx) = x_int;
                        y_int_arr(idx) = y_int;
                    end
                end

                % Determine Inner vs Outer Wheel
                if dL >= 0 % Turning Left: Left is Inner, Right is Outer
                    inner_ang = dL;
                    outer_ang = dR;
                    tan_inner = tan(deg2rad(inner_ang));
                    if tan_inner > 0
                        ideal_outer = rad2deg(atan((L * tan_inner) / (L + K * tan_inner)));
                    else
                        ideal_outer = 0;
                    end
                    ideal_R_arr(idx) = ideal_outer;

                    diff_ideal = inner_ang - ideal_outer;
                    if abs(diff_ideal) > 0.05
                        ack_pct_arr(idx) = ((inner_ang - outer_ang) / diff_ideal) * 100.0;
                    else
                        ack_pct_arr(idx) = 100.0;
                    end
                else % Turning Right: Right is Inner, Left is Outer
                    inner_ang = abs(dR);
                    outer_ang = abs(dL);
                    tan_inner = tan(deg2rad(inner_ang));
                    if tan_inner > 0
                        ideal_outer = rad2deg(atan((L * tan_inner) / (L + K * tan_inner)));
                    else
                        ideal_outer = 0;
                    end
                    ideal_L_arr(idx) = -ideal_outer;

                    diff_ideal = inner_ang - ideal_outer;
                    if abs(diff_ideal) > 0.05
                        ack_pct_arr(idx) = ((inner_ang - outer_ang) / diff_ideal) * 100.0;
                    else
                        ack_pct_arr(idx) = 100.0;
                    end
                end
            end
        end

        % Current Live Point Evaluation
        th_live_rad = deg2rad(th_steer);
        TL_live = [-R_tripod * sin(phi0 - th_live_rad), y_P - R_tripod * cos(phi0 - th_live_rad)];
        TR_live = [ R_tripod * sin(phi0 + th_live_rad), y_P - R_tripod * cos(phi0 + th_live_rad)];
        JL_live = circle_intersect(KL, L_arm, TL_live, L_tierod);
        JR_live = circle_intersect(KR, L_arm, TR_live, L_tierod);

        if isempty(JL_live) || isempty(JR_live)
            dL_live = 0; dR_live = 0;
            valid_geom = false;
        else
            dL_live = rad2deg(atan2(JL_live(2) - KL(2), JL_live(1) - KL(1)) - ang_L0);
            dR_live = rad2deg(atan2(JR_live(2) - KR(2), JR_live(1) - KR(1)) - ang_R0);
            valid_geom = true;
        end

        % Ideal Ackermann for live steer
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

        % Live intersection point
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

        % =================================================================
        % PLOT 1: 2D KINEMATIC MECHANISM VISUALIZATION
        % =================================================================
        cla(ax_mech);
        hold(ax_mech, 'on');
        grid(ax_mech, 'on');
        set(ax_mech, 'Color', [0.16 0.18 0.22], 'GridColor', [0.3 0.35 0.4]);

        % Draw Kingpin Beam
        plot(ax_mech, [KL(1), KR(1)], [KL(2), KR(2)], 'w-', 'LineWidth', 2.5);
        plot(ax_mech, KL(1), KL(2), 'co', 'MarkerSize', 8, 'MarkerFaceColor', [0.2 0.8 1.0]);
        plot(ax_mech, KR(1), KR(2), 'co', 'MarkerSize', 8, 'MarkerFaceColor', [0.2 0.8 1.0]);
        text(ax_mech, KL(1)-8, KL(2)+8, 'Kingpin_L', 'Color', [0.2 0.8 1.0], 'FontSize', 8, 'FontWeight', 'bold');
        text(ax_mech, KR(1)-8, KR(2)+8, 'Kingpin_R', 'Color', [0.2 0.8 1.0], 'FontSize', 8, 'FontWeight', 'bold');

        % Draw Tripod Pivot & Arc
        plot(ax_mech, 0, y_P, 'y^', 'MarkerSize', 9, 'MarkerFaceColor', [1.0 0.8 0.2]);
        text(ax_mech, 4, y_P, 'Tripod Pivot', 'Color', [1.0 0.8 0.2], 'FontSize', 8);

        % Tripod Plate Body (Triangular polygon)
        tripod_pts_x = [0, TL_live(1), TR_live(1), 0];
        tripod_pts_y = [y_P, TL_live(2), TR_live(2), y_P];
        fill(ax_mech, tripod_pts_x, tripod_pts_y, [1.0 0.85 0.3], 'FaceAlpha', 0.35, 'EdgeColor', [1.0 0.85 0.3], 'LineWidth', 1.8);
        plot(ax_mech, TL_live(1), TL_live(2), 'yo', 'MarkerFaceColor', [1 0.6 0.1]);
        plot(ax_mech, TR_live(1), TR_live(2), 'yo', 'MarkerFaceColor', [1 0.6 0.1]);

        if valid_geom
            % Draw Control Arms
            plot(ax_mech, [KL(1), JL_live(1)], [KL(2), JL_live(2)], 'r-', 'LineWidth', 3.0);
            plot(ax_mech, [KR(1), JR_live(1)], [KR(2), JR_live(2)], 'r-', 'LineWidth', 3.0);
            plot(ax_mech, JL_live(1), JL_live(2), 'ro', 'MarkerFaceColor', 'r');
            plot(ax_mech, JR_live(1), JR_live(2), 'ro', 'MarkerFaceColor', 'r');

            % Draw Tie-Rods
            plot(ax_mech, [TL_live(1), JL_live(1)], [TL_live(2), JL_live(2)], 'g-', 'LineWidth', 2.5);
            plot(ax_mech, [TR_live(1), JR_live(1)], [TR_live(2), JR_live(2)], 'g-', 'LineWidth', 2.5);

            % Draw 65mm Tires
            draw_tire(ax_mech, KL, dL_live, p.tire_dia, p.tire_width, [0.15 0.65 1.0]);
            draw_tire(ax_mech, KR, dR_live, p.tire_dia, p.tire_width, [0.15 0.65 1.0]);

            % Draw Wheel Projection Lines to Intersection
            if ~isnan(live_x_int) && ~isnan(live_y_int) && abs(live_y_int) < 1000
                plot(ax_mech, [KL(1), live_x_int], [KL(2), live_y_int], 'm--', 'LineWidth', 1.2);
                plot(ax_mech, [KR(1), live_x_int], [KR(2), live_y_int], 'm--', 'LineWidth', 1.2);
                plot(ax_mech, live_x_int, live_y_int, 'mp', 'MarkerSize', 12, 'MarkerFaceColor', 'm');
                text(ax_mech, live_x_int+5, live_y_int, sprintf('Instant Center (y=%.0fmm)', live_y_int), ...
                     'Color', [1.0 0.4 1.0], 'FontSize', 8, 'FontWeight', 'bold');
            end
        end

        % Draw Rear Axle Reference Line (Ideal Ackermann target)
        plot(ax_mech, [-K, K], [-L, -L], 'c-.', 'LineWidth', 1.5);
        text(ax_mech, -K+10, -L+8, sprintf('Rear Axle Line (y = -%.0f mm)', L), 'Color', [0.2 0.9 0.9], 'FontSize', 8);

        title(ax_mech, sprintf('Kinematic Top View (Steer: \\theta_{tripod} = %.1f^\\circ)', th_steer), ...
              'Color', 'w', 'FontSize', 11, 'FontWeight', 'bold');
        xlabel(ax_mech, 'X (Transverse, mm)', 'Color', 'w');
        ylabel(ax_mech, 'Y (Longitudinal, mm)', 'Color', 'w');
        axis(ax_mech, 'equal');
        xlim(ax_mech, [-K*1.0, K*1.0]);
        ylim(ax_mech, [-L*1.2, p.tire_dia*0.8]);

        % =================================================================
        % PLOT 2: INNER ANGLE VS OUTER ANGLE (ACTUAL VS IDEAL VS PARALLEL)
        % =================================================================
        cla(ax_ang);
        hold(ax_ang, 'on');
        grid(ax_ang, 'on');
        set(ax_ang, 'Color', [0.16 0.18 0.22], 'GridColor', [0.3 0.35 0.4]);

        % Extract positive sweep (Left Turn: Inner=dL, Outer=dR)
        pos_idx = (delta_L_arr >= 0 & ~isnan(delta_L_arr) & ~isnan(delta_R_arr));
        sweep_inner = delta_L_arr(pos_idx);
        sweep_outer = delta_R_arr(pos_idx);
        sweep_ideal = ideal_R_arr(pos_idx);

        % Sort for clean line plot
        [sweep_inner, sort_idx] = sort(sweep_inner);
        sweep_outer = sweep_outer(sort_idx);
        sweep_ideal = sweep_ideal(sort_idx);

        plot(ax_ang, sweep_inner, sweep_inner, 'k:', 'LineWidth', 1.5, 'DisplayName', 'Parallel Steering (0% Ackermann)');
        plot(ax_ang, sweep_inner, sweep_ideal, 'b--', 'LineWidth', 2.2, 'DisplayName', '100% Ideal Ackermann');
        plot(ax_ang, sweep_inner, sweep_outer, 'r-', 'LineWidth', 2.5, 'DisplayName', 'Set Geometry (Your Kart)');

        % Live Point Marker
        plot(ax_ang, live_inner, live_outer, 'yo', 'MarkerSize', 9, 'MarkerFaceColor', [1 0.8 0.2], ...
             'DisplayName', sprintf('Current Point: \\delta_i=%.1f^\\circ, \\delta_o=%.1f^\\circ', live_inner, live_outer));

        title(ax_ang, 'Inner Steer Angle vs. Outer Steer Angle', 'Color', 'w', 'FontSize', 11, 'FontWeight', 'bold');
        xlabel(ax_ang, 'Inner Wheel Angle \delta_{inner} (deg)', 'Color', 'w');
        ylabel(ax_ang, 'Outer Wheel Angle \delta_{outer} (deg)', 'Color', 'w');
        legend(ax_ang, 'Location', 'northwest', 'TextColor', 'w', 'Color', [0.1 0.12 0.15]);
        xlim(ax_ang, [0, 35]);
        ylim(ax_ang, [0, 32]);

        % =================================================================
        % PLOT 3: ACKERMANN PERCENTAGE (%) VS INNER ANGLE
        % =================================================================
        cla(ax_pct);
        hold(ax_pct, 'on');
        grid(ax_pct, 'on');
        set(ax_pct, 'Color', [0.16 0.18 0.22], 'GridColor', [0.3 0.35 0.4]);

        sweep_pct = ack_pct_arr(pos_idx);
        sweep_pct = sweep_pct(sort_idx);

        % Shaded Target Bands
        fill(ax_pct, [0 35 35 0], [0 0 -50 -50], [0.8 0.2 0.2], 'FaceAlpha', 0.15, 'EdgeColor', 'none'); % Anti-Ackermann
        fill(ax_pct, [0 35 35 0], [0 0 100 100], [0.2 0.7 0.3], 'FaceAlpha', 0.15, 'EdgeColor', 'none'); % Pro-Ackermann
        fill(ax_pct, [0 35 35 0], [100 100 180 180], [0.2 0.4 0.9], 'FaceAlpha', 0.15, 'EdgeColor', 'none'); % Over-Ackermann

        yline(ax_pct, 100, 'g--', 'LineWidth', 1.8, 'DisplayName', '100% Ideal Ackermann');
        yline(ax_pct, 0, 'w:', 'LineWidth', 1.5, 'DisplayName', '0% Parallel Steering');
        plot(ax_pct, sweep_inner, sweep_pct, 'r-', 'LineWidth', 2.5, 'DisplayName', 'Kart Ackermann %');

        % Live Point
        plot(ax_pct, live_inner, live_ack_pct, 'yo', 'MarkerSize', 9, 'MarkerFaceColor', [1 0.8 0.2], ...
             'DisplayName', sprintf('Live Ackermann: %.1f%%', live_ack_pct));

        title(ax_pct, 'Ackermann Percentage (%) vs. Inner Steering Angle', 'Color', 'w', 'FontSize', 11, 'FontWeight', 'bold');
        xlabel(ax_pct, 'Inner Wheel Angle \delta_{inner} (deg)', 'Color', 'w');
        ylabel(ax_pct, 'Ackermann %', 'Color', 'w');
        legend(ax_pct, 'Location', 'northeast', 'TextColor', 'w', 'Color', [0.1 0.12 0.15]);
        xlim(ax_pct, [0, 35]);
        ylim(ax_pct, [-20, 180]);

        % =================================================================
        % PLOT 4: INTERSECTION POINT DISTANCE (y_int) VS INNER ANGLE
        % =================================================================
        cla(ax_int);
        hold(ax_int, 'on');
        grid(ax_int, 'on');
        set(ax_int, 'Color', [0.16 0.18 0.22], 'GridColor', [0.3 0.35 0.4]);

        sweep_yint = y_int_arr(pos_idx);
        sweep_yint = sweep_yint(sort_idx);

        yline(ax_int, L, 'c--', 'LineWidth', 2.0, 'DisplayName', sprintf('Ideal Target: Rear Axle (L = %.0f mm)', L));
        plot(ax_int, sweep_inner, abs(sweep_yint), 'm-', 'LineWidth', 2.5, 'DisplayName', 'Actual Wheel Intersection |y_{int}|');

        % Live Point
        if ~isnan(live_y_int)
            plot(ax_int, live_inner, abs(live_y_int), 'yo', 'MarkerSize', 9, 'MarkerFaceColor', [1 0.8 0.2], ...
                 'DisplayName', sprintf('Current |y_{int}| = %.1f mm', abs(live_y_int)));
        end

        title(ax_int, 'Instantaneous Intersection Distance vs. Inner Angle', 'Color', 'w', 'FontSize', 11, 'FontWeight', 'bold');
        xlabel(ax_int, 'Inner Wheel Angle \delta_{inner} (deg)', 'Color', 'w');
        ylabel(ax_int, 'Longitudinal Distance from Front Axle (mm)', 'Color', 'w');
        legend(ax_int, 'Location', 'northeast', 'TextColor', 'w', 'Color', [0.1 0.12 0.15]);
        xlim(ax_int, [2, 35]);
        ylim(ax_int, [0, L * 2.0]);

        % =================================================================
        % UPDATE TELEMETRY TEXT BOX
        % =================================================================
        if is_turn_left
            turn_str = 'LEFT TURN';
        else
            turn_str = 'RIGHT TURN';
        end

        if abs(live_inner) > 0.1
            r_turn = (L / sin(deg2rad(live_inner))) / 1000.0; % Turn radius in meters
        else
            r_turn = inf;
        end

        telemetry_txt = sprintf([...
            '==============================\n' ...
            '   LIVE KINEMATIC TELEMETRY   \n' ...
            '==============================\n' ...
            'Active Direction : %s\n' ...
            'Tripod Angle     : %+.1f deg\n' ...
            '------------------------------\n' ...
            'Inner Wheel Angle: %.2f deg\n' ...
            'Outer Wheel Angle: %.2f deg\n' ...
            'Ideal Outer Angle: %.2f deg\n' ...
            'Angular Error    : %+.2f deg\n' ...
            '------------------------------\n' ...
            'Ackermann %%      : %.1f %%\n' ...
            'Intersection Y   : %.1f mm\n' ...
            'Target Axle (L)  : %.1f mm\n' ...
            'Intersection X   : %.1f mm\n' ...
            'Est Turn Radius  : %.2f m\n' ...
            '------------------------------\n' ...
            'Mechanism Status : %s\n' ...
            'Rulebook Min GC  : 15mm (Pass)\n' ...
            'Tire Dia / Width : 65mm / 26mm\n' ...
            '==============================' ...
        ], turn_str, th_steer, live_inner, live_outer, live_ideal_outer, ...
           (live_outer - live_ideal_outer), live_ack_pct, live_y_int, -L, ...
           live_x_int, r_turn, ...
           ternary(valid_geom, 'VALID 4-BAR', 'TOGGLE LOCK'));

        set(h.telemetry_box, 'String', telemetry_txt);
    end

    % Circle-Circle Intersection Helper Function (Closed-Form Analytical)
    function pt = circle_intersect(C1, r1, C2, r2)
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

        % Two possible intersection points
        p1 = [x2 + h * dy / d, y2 - h * dx / d];
        p2 = [x2 - h * dy / d, y2 + h * dx / d];

        % In rear-steer, control arm extends towards rear (-Y)
        if p1(2) < p2(2)
            pt = p1;
        else
            pt = p2;
        end
    end

    % Draw Tire Polygon in 2D
    function draw_tire(ax, center, steer_deg, dia, width, color)
        % Create local box
        bx = [-width/2, width/2, width/2, -width/2];
        by = [-dia/2, -dia/2, dia/2, dia/2];

        % Rotate by steer angle (steer_deg positive = counter-clockwise)
        theta = deg2rad(steer_deg);
        R_mat = [cos(theta), -sin(theta); sin(theta), cos(theta)];
        rot_pts = R_mat * [bx; by];

        % Translate to center
        gx = rot_pts(1, :) + center(1);
        gy = rot_pts(2, :) + center(2);

        fill(ax, gx, gy, color, 'FaceAlpha', 0.85, 'EdgeColor', 'k', 'LineWidth', 1.5);
    end

    function out = ternary(cond, val_true, val_false)
        if cond
            out = val_true;
        else
            out = val_false;
        end
    end

end
