function rc_kart_timeline1_fulltrack_sim()
%% RC KART TIMELINE 1 FULL RACE TRACK POWERTRAIN & GT2 DRIVETRAIN SIMULATOR
% Team Oorja F1 RC Race (Division B: Build Your Own RC Cars)
% Track: 12.0m x 7.4m Outdoor Redstone Tiles (mu = 0.95, 2-5mm tile seams)
% Circuit: 44.85m Lap, 8-Lap Endurance Race (358.8m total race distance)
%
% TIMELINE 1 SPECIFICATION:
% - Single A2212 Brushless Outrunner + 80A Airplane ESC + Solid 8mm Live Axle
% - GT2 Timing Belt Synchronous Transmission (2mm Pitch)
% - Head-to-Head Comparison: 1400 KV (16T:64T, 4:1) vs. 1000 KV (20T:60T, 3:1)
% - Target Total Vehicle Curb Mass: 600 grams (0.600 kg)
%
% MATLAB UI FEATURES:
% - Instantaneous continuous sliders with interactive callbacks
% - Two-pass forward-acceleration & backward-braking point-mass lap solver
% - 2D Circuit Track Map with colored speed heatmap
% - Velocity Profile v(s) overlay (1400KV vs 1000KV)
% - GT2 Belt Tooth Shear Safety Factor profile across the lap
% - Powertrain Electrical Current & Power Draw
% - Complete 8-Lap Endurance & 9-Sector Telemetry HUD

clear all;
close all;

%% 1. Default Engineering Parameters
p = struct();
p.mass_kg    = 0.600;   % 600g curb mass
p.kv         = 1400.0;  % 1400 KV default
p.voc        = 8.40;    % 2S LiPo Peak Voltage (V)
p.z1         = 16;      % GT2 Pinion teeth
p.z2         = 64;      % GT2 Axle Spur teeth
p.dtire_mm   = 65.0;    % Tire diameter (mm)
p.mu         = 0.95;    % Redstone tile friction coefficient
p.rear_wt    = 0.65;    % 65% dynamic rear weight distribution
p.belt_w_mm  = 6.0;     % GT2 belt width (mm)
p.cdist_mm   = 50.0;    % Axle-to-motor center distance (mm)
p.has_idler  = true;    % 623ZZ idler snubber installed
p.overlay_kv = true;    % Compare 1400KV vs 1000KV
p.flying_lap = true;    % True = flying lap, False = standing start

% Track sector definitions (44.85m lap)
p.lap_length = 44.85;
p.sec_bounds = [0.0, 7.0, 10.1416, 16.1416, 19.2832, 24.2832, 27.4248, 31.9248, 41.3496, 44.85];
p.sec_names  = { ...
    'Main Straight (7.0m)', 'T1 Hairpin (R=1.0m)', 'Back Straight 1 (6.0m)', ...
    'T2 Hairpin (R=1.0m)', 'Back Straight 2 (5.0m)', 'T3 Hairpin (R=1.0m)', ...
    'Top Straight (4.5m)', 'T4 Sweeper (R=3.0m)', 'Front Link (3.50m)'};

%% 2. Pre-Calculate 2D Track Centerline Coordinates
nPtsTrack = 600;
s_track = linspace(0, p.lap_length, nPtsTrack);
x_track = zeros(1, nPtsTrack);
y_track = zeros(1, nPtsTrack);

for i = 1:nPtsTrack
    s = s_track(i);
    if s < 7.0
        x_track(i) = 3.5 + s;
        y_track(i) = 1.0;
    elseif s < 10.1416
        ds = s - 7.0;
        theta = -pi/2 + ds / 1.0;
        x_track(i) = 10.5 + 1.0 * cos(theta);
        y_track(i) = 2.0 + 1.0 * sin(theta);
    elseif s < 16.1416
        ds = s - 10.1416;
        x_track(i) = 10.5 - ds;
        y_track(i) = 3.0;
    elseif s < 19.2832
        ds = s - 16.1416;
        theta = pi/2 - ds / 1.0;
        x_track(i) = 4.5 - 1.0 * sin(theta);
        y_track(i) = 4.0 - 1.0 * cos(theta);
    elseif s < 24.2832
        ds = s - 19.2832;
        x_track(i) = 4.5 + ds;
        y_track(i) = 5.0;
    elseif s < 27.4248
        ds = s - 24.2832;
        theta = -pi/2 + ds / 1.0;
        x_track(i) = 9.5 + 1.0 * cos(theta);
        y_track(i) = 6.0 + 1.0 * sin(theta);
    elseif s < 31.9248
        ds = s - 27.4248;
        x_track(i) = 9.5 - ds;
        y_track(i) = 7.0;
    elseif s < 41.3496
        ds = s - 31.9248;
        theta = pi/2 + ds / 3.0;
        x_track(i) = 5.0 + 3.0 * cos(theta);
        y_track(i) = 4.0 + 3.0 * sin(theta);
    else
        ds = s - 41.3496;
        x_track(i) = 5.0 - (ds / (44.85 - 41.3496)) * 1.5;
        y_track(i) = 1.0;
    end
end
p.s_track = s_track;
p.x_track = x_track;
p.y_track = y_track;

%% 3. Build UI Figure and Axes
fig = figure('Name', 'Timeline 1 Full Race Track Powertrain Simulator (1400KV vs 1000KV)', ...
             'Color', [0.07 0.08 0.10], 'Position', [40, 40, 1550, 850], ...
             'NumberTitle', 'off', 'MenuBar', 'none');

% Axes Layout
ax_track = axes('Parent', fig, 'Position', [0.05, 0.54, 0.30, 0.41], 'Color', [0.09 0.10 0.13]);
ax_belt  = axes('Parent', fig, 'Position', [0.05, 0.08, 0.30, 0.38], 'Color', [0.09 0.10 0.13]);
ax_vel   = axes('Parent', fig, 'Position', [0.38, 0.54, 0.35, 0.41], 'Color', [0.09 0.10 0.13]);
ax_power = axes('Parent', fig, 'Position', [0.38, 0.08, 0.35, 0.38], 'Color', [0.09 0.10 0.13]);

% Style axes
for ax = [ax_track, ax_belt, ax_vel, ax_power]
    set(ax, 'XColor', [0.55 0.57 0.62], 'YColor', [0.55 0.57 0.62], 'GridColor', [0.18 0.20 0.25], 'FontSize', 8);
    grid(ax, 'on');
    box(ax, 'on');
end

% Telemetry HUD Static Text Panel
uicontrol('Style', 'frame', 'Position', [1180, 460, 345, 375], 'BackgroundColor', [0.09 0.10 0.13]);
hud_text_box = uicontrol('Style', 'text', 'Position', [1185, 465, 335, 365], ...
                         'BackgroundColor', [0.09 0.10 0.13], 'ForegroundColor', [0.0 1.0 0.8], ...
                         'FontName', 'FixedWidth', 'FontSize', 8, 'HorizontalAlignment', 'left');

%% 4. Top Quick Preset Buttons
uicontrol('Style', 'pushbutton', 'String', '1400KV (4:1)', 'Position', [1180, 840, 105, 25], ...
          'BackgroundColor', [0.14 0.16 0.20], 'ForegroundColor', [0.0 1.0 0.8], 'FontWeight', 'bold', ...
          'Callback', @(~,~) preset_1400());

uicontrol('Style', 'pushbutton', 'String', '1000KV (3:1)', 'Position', [1295, 840, 105, 25], ...
          'BackgroundColor', [0.14 0.16 0.20], 'ForegroundColor', [0.0 1.0 0.8], 'FontWeight', 'bold', ...
          'Callback', @(~,~) preset_1000());

btn_over = uicontrol('Style', 'pushbutton', 'String', 'Overlay Both', 'Position', [1410, 840, 115, 25], ...
                     'BackgroundColor', [0.12 0.25 0.40], 'ForegroundColor', [0.0 1.0 0.8], 'FontWeight', 'bold', ...
                     'Callback', @(~,~) toggle_overlay());

%% 5. Interactive Sliders (Lower Right Control Panel)
slider_defs = { ...
    'mass',    'Total Mass (g)',       400, 900,  600,  '%.0f g'; ...
    'kv',      'Motor KV (RPM/V)',     800, 1800, 1400, '%.0f KV'; ...
    'voc',     '2S Voltage (V)',       6.8, 8.4,  8.40, '%.2f V'; ...
    'z1',      'Pinion Teeth (Z1)',    12,  26,   16,   '%.0f T'; ...
    'z2',      'Spur Teeth (Z2)',      40,  80,   64,   '%.0f T'; ...
    'mu',      'Tire Grip (mu)',       0.6, 1.1,  0.95, '%.2f'; ...
    'dtire',   'Tire Dia (mm)',        50,  75,   65,   '%.1f mm'; ...
    'rear_wt', 'Rear Wt Dist (%)',     50,  80,   65,   '%.0f %%'; ...
    'belt_w',  'GT2 Belt Width (mm)',  4,   10,   6,    '%.0f mm'; ...
    'cdist',   'Center Dist (mm)',     35,  75,   50,   '%.0f mm'};

sliders = struct();
labels  = struct();
y_start = 410;
y_step  = 35;

for k = 1:size(slider_defs, 1)
    key     = slider_defs{k, 1};
    name    = slider_defs{k, 2};
    v_min   = slider_defs{k, 3};
    v_max   = slider_defs{k, 4};
    v_init  = slider_defs{k, 5};
    v_fmt   = slider_defs{k, 6};
    y_p     = y_start - (k-1)*y_step;
    
    uicontrol('Style', 'text', 'String', name, 'Position', [1180, y_p + 15, 180, 15], ...
              'BackgroundColor', [0.07 0.08 0.10], 'ForegroundColor', [0.75 0.77 0.82], ...
              'FontSize', 7.5, 'HorizontalAlignment', 'left');
          
    labels.(key) = uicontrol('Style', 'text', 'String', sprintf(v_fmt, v_init), 'Position', [1450, y_p + 15, 75, 15], ...
                             'BackgroundColor', [0.07 0.08 0.10], 'ForegroundColor', [0.0 1.0 0.8], ...
                             'FontSize', 7.5, 'HorizontalAlignment', 'right');
                         
    sliders.(key) = uicontrol('Style', 'slider', 'Min', v_min, 'Max', v_max, 'Value', v_init, ...
                              'Position', [1180, y_p, 345, 15], 'Callback', @(~,~) run_simulation());
end

% Toggle Buttons (Bottom)
btn_idler = uicontrol('Style', 'pushbutton', 'String', 'Idler: ON (210°)', 'Position', [1180, 18, 165, 26], ...
                      'BackgroundColor', [0.12 0.25 0.20], 'ForegroundColor', [0.0 1.0 0.8], 'FontWeight', 'bold', ...
                      'Callback', @(~,~) toggle_idler());

btn_lap = uicontrol('Style', 'pushbutton', 'String', 'Mode: Flying Lap', 'Position', [1360, 18, 165, 26], ...
                    'BackgroundColor', [0.14 0.16 0.20], 'ForegroundColor', [1.0 0.84 0.0], 'FontWeight', 'bold', ...
                    'Callback', @(~,~) toggle_lap());

%% 6. Initial Execution
run_simulation();

%% ============================================================================
%  CALLBACK FUNCTIONS
%  ============================================================================
    function preset_1400()
        set(sliders.kv, 'Value', 1400.0);
        set(sliders.z1, 'Value', 16.0);
        set(sliders.z2, 'Value', 64.0);
        run_simulation();
    end

    function preset_1000()
        set(sliders.kv, 'Value', 1000.0);
        set(sliders.z1, 'Value', 20.0);
        set(sliders.z2, 'Value', 60.0);
        run_simulation();
    end

    function toggle_overlay()
        p.overlay_kv = ~p.overlay_kv;
        if p.overlay_kv
            set(btn_over, 'BackgroundColor', [0.12 0.25 0.40]);
        else
            set(btn_over, 'BackgroundColor', [0.14 0.16 0.20]);
        end
        run_simulation();
    end

    function toggle_idler()
        p.has_idler = ~p.has_idler;
        if p.has_idler
            set(btn_idler, 'String', 'Idler: ON (210°)', 'BackgroundColor', [0.12 0.25 0.20]);
        else
            set(btn_idler, 'String', 'Idler: OFF (144°)', 'BackgroundColor', [0.25 0.12 0.15]);
        end
        run_simulation();
    end

    function toggle_lap()
        p.flying_lap = ~p.flying_lap;
        if p.flying_lap
            set(btn_lap, 'String', 'Mode: Flying Lap', 'ForegroundColor', [1.0 0.84 0.0]);
        else
            set(btn_lap, 'String', 'Mode: Standing Start', 'ForegroundColor', [0.0 0.9 1.0]);
        end
        run_simulation();
    end

%% ============================================================================
%  SIMULATION & RENDERING LOOP
%  ============================================================================
    function run_simulation()
        % Read UI slider inputs
        p.mass_kg   = get(sliders.mass, 'Value') / 1000.0;
        p.kv        = get(sliders.kv, 'Value');
        p.voc       = get(sliders.voc, 'Value');
        p.z1        = round(get(sliders.z1, 'Value'));
        p.z2        = round(get(sliders.z2, 'Value'));
        p.mu        = get(sliders.mu, 'Value');
        p.dtire_mm  = get(sliders.dtire, 'Value');
        p.rear_wt   = get(sliders.rear_wt, 'Value') / 100.0;
        p.belt_w_mm = get(sliders.belt_w, 'Value');
        p.cdist_mm  = get(sliders.cdist, 'Value');

        % Update slider label texts
        set(labels.mass,    'String', sprintf('%.0f g', p.mass_kg * 1000));
        set(labels.kv,      'String', sprintf('%.0f KV', p.kv));
        set(labels.voc,     'String', sprintf('%.2f V', p.voc));
        set(labels.z1,      'String', sprintf('%.0f T', p.z1));
        set(labels.z2,      'String', sprintf('%.0f T', p.z2));
        set(labels.mu,      'String', sprintf('%.2f', p.mu));
        set(labels.dtire,   'String', sprintf('%.1f mm', p.dtire_mm));
        set(labels.rear_wt, 'String', sprintf('%.0f %%', p.rear_wt * 100));
        set(labels.belt_w,  'String', sprintf('%.0f mm', p.belt_w_mm));
        set(labels.cdist,   'String', sprintf('%.0f mm', p.cdist_mm));

        % Run Primary Lap Solver
        res_prim = solve_track_core(p.mass_kg, p.kv, p.voc, p.z1, p.z2, ...
                                    p.dtire_mm, p.mu, p.rear_wt, p.belt_w_mm, p.cdist_mm, p.has_idler);

        % Run Benchmark Lap Solver (1000KV with 20T:60T)
        res_bench = solve_track_core(p.mass_kg, 1000.0, p.voc, 20, 60, ...
                                     p.dtire_mm, p.mu, p.rear_wt, p.belt_w_mm, p.cdist_mm, p.has_idler);

        % Select Active Lap Mode (Flying vs Standing)
        if p.flying_lap
            dat_p = res_prim.fly;
            dat_b = res_bench.fly;
        else
            dat_p = res_prim.std;
            dat_b = res_bench.std;
        end
        s_ax = res_prim.s;

        %% PLOT 1: 2D Track Speed Heatmap
        cla(ax_track);
        hold(ax_track, 'on');
        title(ax_track, 'Team Oorja Track (12m x 7.4m) Speed Map', 'Color', [0.0 1.0 0.8], 'FontSize', 9, 'FontWeight', 'bold');
        xlabel(ax_track, 'Track X [meters]', 'FontSize', 7.5);
        ylabel(ax_track, 'Track Y [meters]', 'FontSize', 7.5);
        axis(ax_track, 'equal');
        xlim(ax_track, [-0.5, 12.5]);
        ylim(ax_track, [-0.5, 8.0]);

        % Track Lane Boundaries (0.6m track width)
        plot(ax_track, p.x_track, p.y_track, 'Color', [0.18 0.20 0.25], 'LineWidth', 12);
        plot(ax_track, p.x_track, p.y_track, 'Color', [0.09 0.10 0.13], 'LineWidth', 9);

        % Interpolate speed and scatter color
        v_interp = interp1(s_ax, dat_p.v_kmh, p.s_track, 'linear', 'extrap');
        scatter(ax_track, p.x_track, p.y_track, 20, v_interp, 'filled');
        colormap(ax_track, 'turbo');
        caxis(ax_track, [10.0, 35.0]);

        % Track Annotations
        plot(ax_track, 3.5, 1.0, 'Marker', '>', 'MarkerFaceColor', [0.0 1.0 0.8], 'MarkerSize', 7);
        text(ax_track, 3.5, 0.4, 'START/FINISH', 'Color', [0.0 1.0 0.8], 'FontSize', 6.5, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
        text(ax_track, 10.6, 2.0, 'T1 (1.0m)', 'Color', [1.0 0.6 0.0], 'FontSize', 6.5);
        text(ax_track, 4.4, 4.0, 'T2 (1.0m)', 'Color', [1.0 0.6 0.0], 'FontSize', 6.5, 'HorizontalAlignment', 'right');
        text(ax_track, 9.6, 6.0, 'T3 (1.0m)', 'Color', [1.0 0.6 0.0], 'FontSize', 6.5);
        text(ax_track, 1.8, 4.0, sprintf('T4 Sweeper\n(R=3.0m)'), 'Color', [0.0 0.9 1.0], 'FontSize', 6.5, 'HorizontalAlignment', 'center');

        %% PLOT 2: Velocity Profile v(s)
        cla(ax_vel);
        hold(ax_vel, 'on');
        lap_mode_str = 'Flying Lap';
        if ~p.flying_lap, lap_mode_str = 'Standing Start'; end
        title(ax_vel, sprintf('Lap Velocity Profile v(s) (%s)', lap_mode_str), ...
              'Color', [0.0 1.0 0.8], 'FontSize', 9, 'FontWeight', 'bold');
        xlabel(ax_vel, 'Lap Distance [meters]', 'FontSize', 7.5);
        ylabel(ax_vel, 'Velocity [km/h]', 'FontSize', 7.5);
        xlim(ax_vel, [0, p.lap_length]);
        ylim(ax_vel, [0, 42]);

        % Sector vertical lines
        for b = p.sec_bounds
            plot(ax_vel, [b, b], [0, 42], '--', 'Color', [0.18 0.20 0.25], 'LineWidth', 0.8);
        end

        % Apex speed limits
        plot(ax_vel, [0, p.lap_length], [10.99, 10.99], ':', 'Color', [1.0 0.6 0.0], 'LineWidth', 1.2);
        plot(ax_vel, [0, p.lap_length], [19.04, 19.04], ':', 'Color', [0.0 0.9 1.0], 'LineWidth', 1.2);

        % Primary Curve
        plot(ax_vel, s_ax, dat_p.v_kmh, 'Color', [0.0 1.0 0.8], 'LineWidth', 2.0);

        % Benchmark Overlay
        if p.overlay_kv
            plot(ax_vel, s_ax, dat_b.v_kmh, '--', 'Color', [1.0 0.3 0.55], 'LineWidth', 1.8);
            legend(ax_vel, {sprintf('Current: %.0fKV (%.3fs)', p.kv, dat_p.t_lap), ...
                            sprintf('Bench: 1000KV (%.3fs)', dat_b.t_lap)}, ...
                   'Location', 'southwest', 'TextColor', [0.8 0.8 0.8], 'Color', [0.1 0.1 0.14], 'FontSize', 7);
        end

        %% PLOT 3: GT2 Belt Tooth Shear Safety Factor
        cla(ax_belt);
        hold(ax_belt, 'on');
        title(ax_belt, sprintf('GT2 Belt Safety Factor (TIM=%.1f T, Wrap=%.0f°)', dat_p.tim, dat_p.phi_wrap_deg), ...
              'Color', [0.0 1.0 0.8], 'FontSize', 9, 'FontWeight', 'bold');
        xlabel(ax_belt, 'Lap Distance [meters]', 'FontSize', 7.5);
        ylabel(ax_belt, 'Tooth Shear Safety Factor', 'FontSize', 7.5);
        xlim(ax_belt, [0, p.lap_length]);
        ylim(ax_belt, [0, 10]);

        plot(ax_belt, [0, p.lap_length], [1.0, 1.0], '-', 'Color', [1.0 0.2 0.25], 'LineWidth', 1.5);
        plot(ax_belt, [0, p.lap_length], [2.5, 2.5], ':', 'Color', [1.0 0.84 0.0], 'LineWidth', 1.0);

        plot(ax_belt, s_ax, dat_p.belt_sf_arr, 'Color', [0.0 1.0 0.8], 'LineWidth', 1.8);
        if p.overlay_kv
            plot(ax_belt, s_ax, dat_b.belt_sf_arr, '--', 'Color', [1.0 0.3 0.55], 'LineWidth', 1.6);
            legend(ax_belt, {'Ratcheting Limit (1.0x)', 'Safe Target (2.5x)', ...
                            sprintf('%.0fKV', p.kv), '1000KV (20T:60T)'}, ...
                   'Location', 'southeast', 'TextColor', [0.8 0.8 0.8], 'Color', [0.1 0.1 0.14], 'FontSize', 6.8);
        end

        %% PLOT 4: Powertrain Current Draw
        cla(ax_power);
        hold(ax_power, 'on');
        title(ax_power, 'Powertrain Electrical Draw (Current Profile)', 'Color', [0.0 1.0 0.8], 'FontSize', 9, 'FontWeight', 'bold');
        xlabel(ax_power, 'Lap Distance [meters]', 'FontSize', 7.5);
        ylabel(ax_power, 'Motor Current [Amps]', 'FontSize', 7.5);
        xlim(ax_power, [0, p.lap_length]);
        ylim(ax_power, [0, 80]);

        plot(ax_power, s_ax, dat_p.current_arr, 'Color', [1.0 0.84 0.0], 'LineWidth', 1.8);
        if p.overlay_kv
            plot(ax_power, s_ax, dat_b.current_arr, '--', 'Color', [1.0 0.3 0.55], 'LineWidth', 1.6);
            legend(ax_power, {sprintf('%.0fKV (Peak: %.1fA)', p.kv, dat_p.peak_amps), ...
                              sprintf('1000KV (Peak: %.1fA)', dat_b.peak_amps)}, ...
                   'Location', 'northeast', 'TextColor', [0.8 0.8 0.8], 'Color', [0.1 0.1 0.14], 'FontSize', 7);
        end

        %% HUD Text Output
        t8_p = res_prim.std.t_lap + 7.0 * res_prim.fly.t_lap;
        t8_b = res_bench.std.t_lap + 7.0 * res_bench.fly.t_lap;
        mah8_p = res_prim.std.mah_lap + 7.0 * res_prim.fly.mah_lap;
        mah8_b = res_bench.std.mah_lap + 7.0 * res_bench.fly.mah_lap;

        hud_str = sprintf([...
            'TIMELINE 1 FULL-TRACK TELEMETRY HUD\n' ...
            '=========================================\n' ...
            'Setup: 1x Motor + 80A ESC + Solid Axle\n' ...
            'Mass: %.0fg | 2S Pack: %.2fV\n\n' ...
            '%-17s | %-10s | %s\n' ...
            '-----------------------------------------\n' ...
            '%-17s | %-10.0f | 1000 KV\n' ...
            '%-17s | %d:%d (%.1f:1) | 20:60 (3:1)\n' ...
            '%-17s | %5.3f s    | %5.3f s\n' ...
            '%-17s | %5.3f s    | %5.3f s\n' ...
            '%-17s | %5.2f s    | %5.2f s\n' ...
            '%-17s | %5.2f min  | %5.2f min\n' ...
            '%-17s | %5.1f km/h | %5.1f km/h\n' ...
            '%-17s | %5.1f A    | %5.1f A\n' ...
            '%-17s | %5.1f W    | %5.1f W\n' ...
            '%-17s | %5.1f mAh  | %5.1f mAh\n' ...
            '%-17s | %5.1f T    | %5.1f T\n' ...
            '%-17s | %5.2f x    | %5.2f x\n' ...
            '-----------------------------------------\n' ...
            'SECTORS (FLYING LAP):\n'], ...
            p.mass_kg*1000, p.voc, ...
            'METRIC', 'CURRENT', '1000KV BENCH', ...
            'Motor KV', p.kv, ...
            'Gearing', p.z1, p.z2, p.z2/p.z1, ...
            'Flying Lap', dat_p.t_lap, dat_b.t_lap, ...
            'Standing Lap', res_prim.std.t_lap, res_bench.std.t_lap, ...
            '8-Lap Endurance', t8_p, t8_b, ...
            '8-Lap Minutes', t8_p/60.0, t8_b/60.0, ...
            'Main Straight Top', dat_p.top_speed_kmh, dat_b.top_speed_kmh, ...
            'Peak Amps', dat_p.peak_amps, dat_b.peak_amps, ...
            'Avg Power', dat_p.avg_power, dat_b.avg_power, ...
            '8-Lap Drain', mah8_p, mah8_b, ...
            'Teeth in Mesh', dat_p.tim, dat_b.tim, ...
            'Min Belt SF', min(dat_p.belt_sf_arr), min(dat_b.belt_sf_arr));

        for i = 1:length(p.sec_names)
            hud_str = [hud_str, sprintf('S%d %-14s: %5.3fs | %5.3fs (%+5.3fs)\n', ...
                       i, p.sec_names{i}(1:min(14, end)), dat_p.sector_times(i), dat_b.sector_times(i), ...
                       dat_p.sector_times(i) - dat_b.sector_times(i))];
        end

        set(hud_text_box, 'String', hud_str);
    end

%% ============================================================================
%  PHYSICAL POINT-MASS TWO-PASS LAP SOLVER
%  ============================================================================
    function res = solve_track_core(mass_kg, kv, v_oc, z1, z2, dtire_mm, mu, rear_wt, belt_w_mm, cdist_mm, has_idler)
        N = 1200;
        s_single = linspace(0, p.lap_length, N);
        ds = s_single(2) - s_single(1);

        % 2 laps concatenated for cyclic convergence
        N2 = 2 * N;
        s_2lap = [s_single, s_single + p.lap_length];

        R_2lap = inf(1, N2);
        for j = 0:1
            offset = j * p.lap_length;
            for i = 1:N
                idx = j * N + i;
                si = s_2lap(idx) - offset;
                if si >= p.sec_bounds(2) && si < p.sec_bounds(3)
                    R_2lap(idx) = 1.0;
                elseif si >= p.sec_bounds(4) && si < p.sec_bounds(5)
                    R_2lap(idx) = 1.0;
                elseif si >= p.sec_bounds(6) && si < p.sec_bounds(7)
                    R_2lap(idx) = 1.0;
                elseif si >= p.sec_bounds(8) && si < p.sec_bounds(9)
                    R_2lap(idx) = 3.0;
                end
            end
        end

        g = 9.81;
        r_bat = 0.015;
        r_esc = 0.003;
        if kv >= 1200
            rm = 0.100;
            i0 = 0.70;
        else
            rm = 0.130;
            i0 = 0.50;
        end
        r_tot = r_bat + r_esc + rm;

        kt = 9.5493 / kv;
        ke = 1.0 / (kv * 2.0 * pi / 60.0);
        ratio = double(z2) / double(z1);
        r_w = (dtire_mm / 1000.0) / 2.0;

        % Rotational inertia
        j_rotor = 5.0e-6;
        j_p1    = 0.5e-6;
        j_p2    = 4.0e-6;
        j_wheel = 2.0e-5;
        j_axle  = 1.5e-6;
        j_total = (j_rotor + j_p1) * (ratio^2) + j_p2 + j_wheel + j_axle;
        m_eff = mass_kg + j_total / (r_w^2);

        % Grip limit
        f_grip_max = mu * mass_kg * g * rear_wt;
        v_max_curve = sqrt(mu * g * R_2lap);

        % Belt geometry
        pitch = 2.0;
        d1 = (z1 * pitch) / pi;
        d2 = (z2 * pitch) / pi;
        r_pinion = (d1 / 1000.0) / 2.0;
        sin_phi = max(-1.0, min(1.0, (d2 - d1) / (2.0 * cdist_mm)));
        phi_wrap_deg = 180.0 - 2.0 * asind(sin_phi);
        if has_idler
            phi_wrap_deg = min(230.0, phi_wrap_deg + 65.0);
        end
        tim = z1 * (phi_wrap_deg / 360.0);
        f_shear_allowable = 2.4 * belt_w_mm;

        % Forward Pass
        v_fwd = zeros(1, N2);
        v_fwd(1) = 0.05;
        for i = 1:(N2 - 1)
            v = v_fwd(i);
            omega_w = v / r_w;
            omega_m = omega_w * ratio;
            eb = omega_m * ke;
            i_m = max(0.0, min(80.0, (v_oc - eb) / r_tot));
            tau_m = max(0.0, kt * (i_m - i0));
            tau_axle = tau_m * ratio * 0.97;
            f_drive = tau_axle / r_w;
            f_tractive = min(f_drive, f_grip_max);
            f_rr = 0.03 * mass_kg * g;
            f_aero = 0.5 * 1.2 * 0.03 * (v^2);
            a_fwd = max(0.0, (f_tractive - f_rr - f_aero) / m_eff);

            v_next_sq = v^2 + 2.0 * a_fwd * ds;
            v_fwd(i+1) = min(sqrt(max(0.0, v_next_sq)), v_max_curve(i+1));
        end

        % Backward Pass
        v_bwd = zeros(1, N2);
        v_bwd(end) = v_fwd(end);
        for i = N2:-1:2
            v = v_bwd(i);
            f_rr = 0.03 * mass_kg * g;
            f_aero = 0.5 * 1.2 * 0.03 * (v^2);
            a_brake = (mu * g * mass_kg + f_rr + f_aero) / mass_kg;

            v_prev_sq = v^2 + 2.0 * a_brake * ds;
            v_bwd(i-1) = min(sqrt(max(0.0, v_prev_sq)), v_max_curve(i-1));
        end

        v_prof_2lap = max(0.05, min(v_fwd, v_bwd));
        v_std = v_prof_2lap(1:N);
        v_fly = v_prof_2lap((N+1):end);

        res = struct();
        res.s = s_single;
        res.std = analyze_lap_data(v_std);
        res.fly = analyze_lap_data(v_fly);

        function ld = analyze_lap_data(v_prof)
            dt = ds ./ v_prof;
            t_lap = sum(dt);

            current_arr = zeros(1, N);
            power_arr   = zeros(1, N);
            copper_loss = zeros(1, N);
            belt_sf_arr = zeros(1, N);

            for idx = 1:N
                v = v_prof(idx);
                omega_w = v / r_w;
                omega_m = omega_w * ratio;
                eb = omega_m * ke;

                if idx < N
                    a_req = (v_prof(idx+1)^2 - v_prof(idx)^2) / (2.0 * ds);
                else
                    a_req = 0.0;
                end

                if a_req > 0.01
                    f_req = a_req * m_eff + 0.03 * mass_kg * g + 0.5 * 1.2 * 0.03 * (v^2);
                    tau_axle_req = f_req * r_w;
                    tau_m_req = tau_axle_req / (ratio * 0.97);
                    i_req = tau_m_req / kt + i0;
                    i_m = min(80.0, max(0.0, min(i_req, (v_oc - eb) / r_tot)));
                    tau_m = max(0.0, kt * (i_m - i0));
                else
                    i_m = 0.0;
                    tau_m = 0.0;
                end

                current_arr(idx) = i_m;
                v_load = v_oc - i_m * r_bat;
                power_arr(idx) = v_load * i_m;
                copper_loss(idx) = (i_m^2) * rm;

                ft = tau_m / r_pinion;
                f_tooth = ft / max(1.0, tim);
                if ft > 0.1
                    belt_sf_arr(idx) = f_shear_allowable / max(0.01, f_tooth);
                else
                    belt_sf_arr(idx) = 10.0;
                end
            end

            ld = struct();
            ld.v_kmh       = v_prof * 3.6;
            ld.t_lap       = t_lap;
            ld.current_arr = current_arr;
            ld.power_arr   = power_arr;
            ld.belt_sf_arr = belt_sf_arr;
            ld.mah_lap     = sum(current_arr .* dt) / 3.6;
            ld.avg_power   = sum(power_arr .* dt) / t_lap;
            ld.avg_heat    = sum(copper_loss .* dt) / t_lap;
            ld.peak_amps   = max(current_arr);
            ld.top_speed_kmh = max(v_prof) * 3.6;
            ld.tim         = tim;
            ld.phi_wrap_deg = phi_wrap_deg;

            % Sector Times
            sec_times = zeros(1, length(p.sec_bounds) - 1);
            for m = 1:(length(p.sec_bounds) - 1)
                mask = (s_single >= p.sec_bounds(m)) & (s_single < p.sec_bounds(m+1));
                sec_times(m) = sum(dt(mask));
            end
            ld.sector_times = sec_times;
        end
    end
end
