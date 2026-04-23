function show_features_window(fig)
    state = get(fig, 'UserData');
    if ~state.spikes_computed
        errordlg('Run spike detection first.', 'Feature Extraction'); return
    end

    fi  = state.current_file_idx;
    chi = state.current_ch_idx;
    ext = state.Extracted(fi);
    Fs  = state.Files_Data(fi).fqz_param.amplifier_sample_rate;

    spike_idx = state.spikes_indices{chi};
    if isempty(spike_idx)
        errordlg('No spikes on this channel.', 'Feature Extraction'); return
    end

    % Default snippet to match sorting if available
    default_snip = '2.0';
    if isfield(state, 'sort_results') && numel(state.sort_results) >= chi && ...
       ~isempty(state.sort_results{chi})
        default_snip = num2str(state.sort_results{chi}.snip_ms);
    end

    win = figure('Name', sprintf('Feature Extraction — Ch %s', ext.id_label{chi}), ...
                 'Position', [150 60 1060 740], ...
                 'Color', [0.15 0.15 0.18], ...
                 'NumberTitle', 'off', 'MenuBar', 'none');

    ctrl_bg = [0.15 0.15 0.18];

    uicontrol(win, 'Style', 'text', 'String', 'Snippet window (ms):', ...
        'Position', [10 710 135 18], 'ForegroundColor', 'w', ...
        'BackgroundColor', ctrl_bg, 'FontSize', 9, 'HorizontalAlignment', 'left');
    efSnip = uicontrol(win, 'Style', 'edit', 'String', default_snip, ...
        'Position', [147 708 45 22], 'FontSize', 9, ...
        'ForegroundColor', 'w', 'BackgroundColor', [0.25 0.25 0.30]);

    btnRun = uicontrol(win, 'Style', 'pushbutton', 'String', 'Run', ...
        'Position', [205 706 70 26], ...
        'BackgroundColor', [0.18 0.52 0.80], 'ForegroundColor', 'w', ...
        'FontSize', 9, 'FontWeight', 'bold');

    % 2x3 grid of axes
    ax_w = 455;
    ax_h = 160;   % Reduced height slightly (from 175) to make room for labels
    xs = [65 550]; % Shifted right slightly to prevent left-side clipping

    % New Y-positions: increased the gaps between these numbers
    % These represent the bottom-left corner of each plot
    ys = [480 255 30];

    axs = zeros(6,1);
    for i = 1:6
        r = ceil(i/2);
        c = mod(i-1,2) + 1;
        axs(i) = axes('Parent', win, 'Units', 'pixels', ...
            'Position', [xs(c), ys(r), ax_w, ax_h]);
    end

    set(btnRun, 'Callback', @(s,e) draw_features(axs, ext, spike_idx, Fs, efSnip, chi));
    draw_features(axs, ext, spike_idx, Fs, efSnip, chi);
end

function draw_features(axs, ext, spike_idx, Fs, efSnip, chi)
    snip_ms = str2double(get(efSnip, 'String'));
    feat    = extract_features(ext.data(:, chi), spike_idx, Fs, snip_ms);

    fields  = {'peak_amp','valley_amp','width_ms','rise_ms','decay_ms','energy'};
    xlabels = {'Peak Amplitude (uV)', 'Valley Amplitude (uV)', ...
               'Spike Width at Half-Max (ms)', ...
               'Rise Time — crossing to trough (ms)', ...
               'Decay Time — trough to half-max (ms)', ...
               'Waveform Energy'};
    titles  = {'Peak Amplitude','Valley Amplitude','Spike Width', ...
               'Rise Time','Decay Time','Energy'};
    colors  = {[0.18 0.52 0.80],[0.20 0.75 0.55],[0.95 0.65 0.20], ...
               [0.75 0.35 0.65],[0.85 0.35 0.25],[0.55 0.75 0.25]};

    ax_style = {'Color', [0.10 0.10 0.13], ...
                'XColor', [0.85 0.85 0.85], 'YColor', [0.85 0.85 0.85], ...
                'FontSize', 9, 'XGrid', 'on', 'YGrid', 'on', ...
                'GridColor', [0.35 0.35 0.35]};

    for i = 1:6
        cla(axs(i));
        vals = feat.(fields{i});
        vals = vals(isfinite(vals));
        if isempty(vals), continue; end

        [counts, edges] = hist(vals, 25);
        bar(axs(i), edges, counts, 1.0, 'FaceColor', colors{i}, 'EdgeColor', 'none');
        set(axs(i), ax_style{:});
        title(axs(i), titles{i}, 'Color', 'w', 'FontSize', 9);
        xlabel(axs(i), xlabels{i}, 'Color', [0.85 0.85 0.85], 'FontSize', 8);
        ylabel(axs(i), 'Spike Count', 'Color', [0.85 0.85 0.85], 'FontSize', 9);

        hold(axs(i), 'on');
        m  = mean(vals);
        yl = ylim(axs(i));
        plot(axs(i), [m m], [0 yl(2)], 'w--', 'LineWidth', 1.2);
        text(axs(i), m, yl(2)*0.88, sprintf(' mean=%.2f', m), ...
             'Color', 'w', 'FontSize', 7);
        hold(axs(i), 'off');
    end
end
