function show_quality_window(fig)
    state = get(fig, 'UserData');
    if ~state.spikes_computed
        errordlg('Run spike detection first.', 'Quality Metrics'); return
    end

    fi  = state.current_file_idx;
    chi = state.current_ch_idx;
    ext = state.Extracted(fi);
    Fs  = state.Files_Data(fi).fqz_param.amplifier_sample_rate;

    spike_idx = state.spikes_indices{chi};
    if isempty(spike_idx)
        errordlg('No spikes on this channel.', 'Quality Metrics'); return
    end

    default_snip = '2.0';
    if isfield(state, 'sort_results') && numel(state.sort_results) >= chi && ...
       ~isempty(state.sort_results{chi})
        default_snip = num2str(state.sort_results{chi}.snip_ms);
    end

    win = figure('Name', sprintf('Quality Metrics — Ch %s', ext.id_label{chi}), ...
                 'Position', [250 180 600 560], ...
                 'Color', [0.15 0.15 0.18], ...
                 'NumberTitle', 'off', 'MenuBar', 'none');

    ctrl_bg = [0.15 0.15 0.18];

    uicontrol(win, 'Style', 'text', 'String', 'Snippet window (ms):', ...
        'Position', [10 530 135 18], 'ForegroundColor', 'w', ...
        'BackgroundColor', ctrl_bg, 'FontSize', 9, 'HorizontalAlignment', 'left');
    efSnip = uicontrol(win, 'Style', 'edit', 'String', default_snip, ...
        'Position', [147 528 45 22], 'FontSize', 9, ...
        'ForegroundColor', 'w', 'BackgroundColor', [0.25 0.25 0.30]);

    btnRun = uicontrol(win, 'Style', 'pushbutton', 'String', 'Run', ...
        'Position', [205 526 70 26], ...
        'BackgroundColor', [0.18 0.52 0.80], 'ForegroundColor', 'w', ...
        'FontSize', 9, 'FontWeight', 'bold');

    ax = axes('Parent', win, 'Position', [0.03 0.03 0.94 0.88]);
    axis(ax, 'off');
    set(ax, 'Color', [0.15 0.15 0.18]);

    set(btnRun, 'Callback', @(s,e) draw_quality(fig, win, ax, ext, spike_idx, Fs, efSnip, chi));
    draw_quality(fig, win, ax, ext, spike_idx, Fs, efSnip, chi);
end

function draw_quality(fig, win, ax, ext, spike_idx, Fs, efSnip, chi)
    snip_ms = str2double(get(efSnip, 'String'));

    sort_labels = [];
    state = get(fig, 'UserData');
    if isfield(state, 'sort_results') && numel(state.sort_results) >= chi && ...
       ~isempty(state.sort_results{chi})
        sort_labels = state.sort_results{chi}.labels;
    end

    qm = compute_quality_metrics(ext.data(:,chi), spike_idx, sort_labels, Fs, snip_ms);

    cla(ax);
    axis(ax, 'off');

    text(ax, 0.05, 0.97, sprintf('Quality Metrics — %s — %d spikes', ...
         ext.id_label{chi}, length(spike_idx)), ...
         'Color', 'w', 'FontSize', 12, 'FontWeight', 'bold', 'Units', 'normalized');
    text(ax, 0.05, 0.91, repmat('-', 1, 55), ...
         'Color', [0.35 0.35 0.40], 'FontSize', 8, 'Units', 'normalized');

    metrics = {};

    if isfinite(qm.snr)
        metrics{end+1} = {'SNR', sprintf('%.2f', qm.snr), ...
            'peak amplitude / noise SD   (>4 good, >2 marginal)', ...
            qm.snr >= 4, qm.snr >= 2};
    else
        metrics{end+1} = {'SNR', 'N/A', '', false, false};
    end

    if isfinite(qm.isi_violation_pct)
        metrics{end+1} = {'ISI Violations', sprintf('%.3f%%', qm.isi_violation_pct), ...
            'spikes within 1 ms of each other   (<0.5% good, <2% marginal)', ...
            qm.isi_violation_pct < 0.5, qm.isi_violation_pct < 2.0};
    else
        metrics{end+1} = {'ISI Violations', 'N/A', '', false, false};
    end

    if isfinite(qm.presence_ratio)
        metrics{end+1} = {'Presence Ratio', sprintf('%.3f', qm.presence_ratio), ...
            'fraction of 100ms bins with at least one spike   (>0.9 good)', ...
            qm.presence_ratio >= 0.9, qm.presence_ratio >= 0.5};
    else
        metrics{end+1} = {'Presence Ratio', 'N/A', '', false, false};
    end

    if isempty(sort_labels)
        metrics{end+1} = {'Isolation Distance', 'Run sorting first', ...
            'requires spike sorting to be completed first', false, false};
    else
        n_units = max(sort_labels);
        for u = 1:n_units
            if isfinite(qm.isolation_dist(u))
                val_str = sprintf('%.1f', qm.isolation_dist(u));
                pass    = qm.isolation_dist(u) >= 20;
                warn    = qm.isolation_dist(u) >= 10;
                desc    = sprintf('Unit %d — cluster separation in PCA space   (>20 good, >10 marginal)', u);
            else
                val_str = 'NaN — too few spikes or overlapping clusters';
                pass = false; warn = false;
                desc = sprintf('Unit %d', u);
            end
            metrics{end+1} = {sprintf('Isolation Dist U%d', u), val_str, desc, pass, warn};
        end
    end

    row_h   = 0.10;
    y_start = 0.86;

    for i = 1:length(metrics)
        m    = metrics{i};
        pass = m{4}; warn = m{5};
        if pass,     val_color = [0.20 0.80 0.45];
        elseif warn, val_color = [0.95 0.75 0.20];
        else,        val_color = [0.85 0.35 0.28];
        end
        y = y_start - (i-1) * row_h;
        text(ax, 0.05, y,         m{1}, 'Color', [0.65 0.65 0.70], ...
             'FontSize', 10, 'FontWeight', 'bold', 'Units', 'normalized');
        text(ax, 0.48, y,         m{2}, 'Color', val_color, ...
             'FontSize', 11, 'FontWeight', 'bold', 'Units', 'normalized');
        text(ax, 0.05, y - 0.045, m{3}, 'Color', [0.42 0.42 0.48], ...
             'FontSize', 7,  'Units', 'normalized');
    end
end
