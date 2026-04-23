function show_filter_bank_window(fig)
    state = get(fig, 'UserData');
    if isempty(state.Extracted)
        errordlg('Load data first.', 'Filter Bank'); return
    end

    fi  = state.current_file_idx;
    chi = state.current_ch_idx;
    ext = state.Extracted(fi);
    Fs  = state.Files_Data(fi).fqz_param.amplifier_sample_rate;

    win = figure('Name', sprintf('Filter Bank — Ch %s', ext.id_label{chi}), ...
                 'Position', [120 40 1020 800], ...
                 'Color', [0.15 0.15 0.18], ...
                 'NumberTitle', 'off', 'MenuBar', 'none');

    % ---- Parameter controls across the top ----
    ctrl_bg = [0.15 0.15 0.18];
    lbl = @(str, x, w) uicontrol(win, 'Style', 'text', 'String', str, ...
        'Position', [x 748 w 20], 'ForegroundColor', 'w', ...
        'BackgroundColor', ctrl_bg, 'FontSize', 9, 'HorizontalAlignment', 'left');
    edf = @(str, x, w) uicontrol(win, 'Style', 'edit', 'String', str, ...
        'Position', [x 746 w 22], 'FontSize', 9, ...
        'ForegroundColor', 'w', 'BackgroundColor', [0.25 0.25 0.30]);

    lbl('Filter type:', 10, 70);
    ddFilterType = uicontrol(win, 'Style', 'popupmenu', ...
        'String', {'Butterworth','Bessel'}, ...
        'Value', strcmp(state.filter_mode, 'bessel') + 1, ...
        'Position', [80 746 100 22], 'FontSize', 9);

    lbl('Order:', 192, 42);
    efOrder = edf(num2str(state.filter_order), 234, 35);

    lbl('Spike HP (Hz):', 282, 90);
    efHP = edf(num2str(state.highpass), 372, 55);

    lbl('Spike LP (Hz):', 438, 90);
    efLP = edf(num2str(state.lowpass), 528, 55);

    lbl('LFP cutoff (Hz):', 595, 100);
    efLFP = edf(num2str(state.lfp_cutoff), 695, 55);

    lbl('Notch (Hz):', 762, 70);
    efNotch = edf('', 832, 45);

    btnApply = uicontrol(win, 'Style', 'pushbutton', 'String', 'Apply & Redraw', ...
        'Position', [888 744 120 26], ...
        'BackgroundColor', [0.18 0.52 0.80], 'ForegroundColor', 'w', ...
        'FontSize', 9, 'FontWeight', 'bold');

    % Note explaining these affect spike detection
    uicontrol(win, 'Style', 'text', ...
        'String', 'Note: Filter type, order, and spike band settings apply to spike detection when Run Spike Detection is pressed.', ...
        'Position', [10 722 1000 18], ...
        'ForegroundColor', [0.55 0.75 0.35], 'BackgroundColor', ctrl_bg, ...
        'FontSize', 8, 'HorizontalAlignment', 'left');

    % Axes for 4 signal views
    axs = zeros(4,1);
    titles = {'Raw Signal — unfiltered', ...
              'Spike Band (bandpass filtered — used for spike detection)', ...
              'LFP — low-pass filtered', ...
              sprintf('Notch filtered')};
    cols = {[0.60 0.60 0.60], [0.18 0.52 0.80], [0.20 0.75 0.55], [0.95 0.65 0.20]};

panel_h  = 800;
ctrl_h   = 90;
plot_h   = 130;        % reduced from 148 so titles have breathing room
plot_gap = 32;         % increased from 8 to give space for titles
plot_left_px = 65;
plot_w_px    = 935;

    for i = 1:4
    % Position from top down, converting to normalized for axes
    top_px = panel_h - ctrl_h - (i * (plot_h + plot_gap));
    axs(i) = axes('Parent', win, ...
        'Units', 'pixels', ...
        'Position', [plot_left_px, top_px, plot_w_px, plot_h], ...
        'Color', [0.10 0.10 0.13], ...
        'XColor', [0.85 0.85 0.85], 'YColor', [0.85 0.85 0.85], ...
        'FontSize', 8, 'XGrid', 'on', 'YGrid', 'on', ...
        'GridColor', [0.30 0.30 0.30]);
    end

    set(btnApply, 'Callback', @(s,e) draw_filter_bank(fig, win, axs, ext, Fs, ...
        ddFilterType, efOrder, efHP, efLP, efLFP, efNotch, titles, cols, chi));

    draw_filter_bank(fig, win, axs, ext, Fs, ...
        ddFilterType, efOrder, efHP, efLP, efLFP, efNotch, titles, cols, chi);
end

function draw_filter_bank(fig, win, axs, ext, Fs, ddFilterType, efOrder, efHP, efLP, efLFP, efNotch, titles, cols, chi)
    filter_types = {'butter','bessel'};
    fmode  = filter_types{get(ddFilterType, 'Value')};
    forder = max(1, round(str2double(get(efOrder,  'String'))));
    hp     = str2double(get(efHP,    'String'));
    lp     = str2double(get(efLP,    'String'));
    lfp_co = str2double(get(efLFP,   'String'));
    notch  = str2double(get(efNotch, 'String'));

    % Validate
    nyq = Fs / 2;
    lp  = min(lp,  nyq * 0.95);
    lfp_co = min(lfp_co, nyq * 0.95);

    sig  = ext.data(:, chi);
    time = ext.time;

    % Spike band filter
    if strcmp(fmode, 'butter')
        [b, a]   = butter(forder, [hp lp] / nyq, 'bandpass');
        spike_band = filtfilt(b, a, sig);
    else
        [b1,a1] = besself(forder, 2*pi*hp, 'high');
        [bz1,az1] = bilinear(b1,a1,Fs);
        [b2,a2] = besself(forder, 2*pi*lp);
        [bz2,az2] = bilinear(b2,a2,Fs);
        spike_band = filtfilt(bz1,az1,sig);
        spike_band = filtfilt(bz2,az2,spike_band);
    end

    % LFP
    [b_lfp, a_lfp] = butter(forder, lfp_co / nyq, 'low');
    lfp_sig = filtfilt(b_lfp, a_lfp, sig);

    % Notch
    notch_str = strtrim(get(efNotch, 'String'));
    if isempty(notch_str) || isnan(str2double(notch_str)) || str2double(notch_str) <= 0
    notch_sig = sig;   % pass through unchanged
    titles{4} = 'Notch filter — disabled (leave field blank to disable)';
    else
    notch = str2double(notch_str);
    bw = notch * 0.05;
    notch_lo = max(1, notch - bw);
    notch_hi = min(nyq * 0.99, notch + bw);
    [b_n, a_n] = butter(2, [notch_lo notch_hi] / nyq, 'stop');
    notch_sig = filtfilt(b_n, a_n, sig);
    titles{4} = sprintf('Notch filtered — %g Hz line noise removed', notch);
    end

    signals = {sig, spike_band, lfp_sig, notch_sig};

    for i = 1:4
        cla(axs(i));
        plot(axs(i), time, signals{i}, 'Color', cols{i}, 'LineWidth', 0.8);
        set(axs(i), 'Color', [0.10 0.10 0.13], ...
            'XColor', [0.85 0.85 0.85], 'YColor', [0.85 0.85 0.85], ...
            'FontSize', 8, 'XGrid', 'on', 'YGrid', 'on', ...
            'GridColor', [0.30 0.30 0.30]);
        title(axs(i), titles{i}, 'Color', 'w', 'FontSize', 10);
        ylabel(axs(i), sprintf('uV  (Vrms=%.2f)', rms(signals{i})), ...
               'Color', [0.85 0.85 0.85], 'FontSize', 8);
        xlim(axs(i), [time(1) time(end)]);
    end
    xlabel(axs(4), 'Time (s)', 'Color', [0.85 0.85 0.85], 'FontSize', 9);

    % Save params back to state so cb_RunSpikes picks them up
    state = get(fig, 'UserData');
    state.filter_mode  = fmode;
    state.filter_order = forder;
    state.highpass     = hp;
    state.lowpass      = lp;
    state.lfp_cutoff   = lfp_co;
    if ~isempty(notch_str) && ~isnan(str2double(notch_str)) && str2double(notch_str) > 0
    state.notch_freq = str2double(notch_str);
    end
    set(fig, 'UserData', state);
end
