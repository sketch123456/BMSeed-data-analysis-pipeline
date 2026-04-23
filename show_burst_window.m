function show_burst_window(fig)
    state = get(fig, 'UserData');
    if ~state.spikes_computed
        errordlg('Run spike detection first.', 'Burst Detection'); return
    end

    fi  = state.current_file_idx;
    chi = state.current_ch_idx;
    ext = state.Extracted(fi);

    st = state.spikes{chi};
    if isempty(st)
        errordlg('No spikes on this channel.', 'Burst Detection'); return
    end

    win = figure('Name', sprintf('Burst Detection — Ch %s', ext.id_label{chi}), ...
                 'Position', [200 150 980 640], ...
                 'Color', [0.15 0.15 0.18], ...
                 'NumberTitle', 'off', 'MenuBar', 'none');

    ctrl_bg = [0.15 0.15 0.18];

    uicontrol(win, 'Style', 'text', 'String', 'Max ISI within burst (ms):', ...
        'Position', [10 608 160 18], 'ForegroundColor', 'w', ...
        'BackgroundColor', ctrl_bg, 'FontSize', 9, 'HorizontalAlignment', 'left');
    efMaxISI = uicontrol(win, 'Style', 'edit', 'String', '100', ...
        'Position', [172 606 50 22], 'FontSize', 9, ...
        'ForegroundColor', 'w', 'BackgroundColor', [0.25 0.25 0.30]);

    uicontrol(win, 'Style', 'text', 'String', 'Min spikes per burst:', ...
        'Position', [240 608 135 18], 'ForegroundColor', 'w', ...
        'BackgroundColor', ctrl_bg, 'FontSize', 9, 'HorizontalAlignment', 'left');
    efMinSpk = uicontrol(win, 'Style', 'edit', 'String', '3', ...
        'Position', [378 606 40 22], 'FontSize', 9, ...
        'ForegroundColor', 'w', 'BackgroundColor', [0.25 0.25 0.30]);

    btnRun = uicontrol(win, 'Style', 'pushbutton', 'String', 'Run', ...
        'Position', [432 604 70 26], ...
        'BackgroundColor', [0.18 0.52 0.80], 'ForegroundColor', 'w', ...
        'FontSize', 9, 'FontWeight', 'bold');

    % Summary label created once here, passed into draw_burst
    lblSummary = uicontrol(win, 'Style', 'text', 'String', '', ...
        'Units', 'pixels', 'Position', [10 4 960 18], ...
        'ForegroundColor', [0.85 0.85 0.85], ...
        'BackgroundColor', ctrl_bg, 'FontSize', 8, ...
        'HorizontalAlignment', 'left');

    ax1 = axes('Parent', win, 'Units', 'pixels', 'Position', [65 355 900 228]);
    ax2 = axes('Parent', win, 'Units', 'pixels', 'Position', [65 68  425 248]);
    ax3 = axes('Parent', win, 'Units', 'pixels', 'Position', [535 68 425 248]);

    set(btnRun, 'Callback', @(s,e) draw_burst(ax1, ax2, ax3, ext, st, ...
        efMaxISI, efMinSpk, lblSummary, chi));
    draw_burst(ax1, ax2, ax3, ext, st, efMaxISI, efMinSpk, lblSummary, chi);
end

function draw_burst(ax1, ax2, ax3, ext, st, efMaxISI, efMinSpk, lblSummary, chi)
    max_isi_ms = str2double(get(efMaxISI, 'String'));
    min_spk    = max(2, round(str2double(get(efMinSpk, 'String'))));
    br = detect_bursts(st, max_isi_ms, min_spk);

    ax_style = {'Color', [0.10 0.10 0.13], ...
                'XColor', [0.85 0.85 0.85], 'YColor', [0.85 0.85 0.85], ...
                'FontSize', 9, 'XGrid', 'on', 'YGrid', 'on', ...
                'GridColor', [0.35 0.35 0.35]};

    cla(ax1);
    hold(ax1, 'on');
    plot(ax1, ext.time, ext.data(:, chi), ...
         'Color', [0.5 0.5 0.55], 'LineWidth', 0.6);

    % Note: ext doesn't carry current_ch_idx — pass the signal directly
    % See note below about fixing this
    yl = ylim(ax1);
    for b = 1:br.count
        patch(ax1, [br.starts(b) br.ends(b) br.ends(b) br.starts(b)], ...
              [yl(1) yl(1) yl(2) yl(2)], [0.18 0.52 0.80], ...
              'FaceAlpha', 0.25, 'EdgeColor', [0.18 0.52 0.80], 'LineWidth', 1);
    end
    plot(ax1, st, ones(size(st)) * yl(2) * 0.90, 'r|', 'MarkerSize', 8);
    hold(ax1, 'off');
    set(ax1, ax_style{:});
    title(ax1, sprintf('Signal with Burst Epochs — %d bursts   (blue=burst, red ticks=spikes)', br.count), ...
          'Color', 'w', 'FontSize', 10);
    xlabel(ax1, 'Time (s)', 'Color', [0.85 0.85 0.85], 'FontSize', 9);
    ylabel(ax1, 'Amplitude (uV)', 'Color', [0.85 0.85 0.85], 'FontSize', 9);

    cla(ax2);
    if ~isempty(br.ibi_ms) && length(br.ibi_ms) > 1
        [counts, edges] = hist(br.ibi_ms, 20);
        bar(ax2, edges, counts, 1.0, 'FaceColor', [0.20 0.75 0.55], 'EdgeColor', 'none');
    else
        text(0.5, 0.5, 'Not enough bursts', 'Units', 'normalized', ...
             'Color', 'w', 'HorizontalAlignment', 'center', 'Parent', ax2);
    end
    set(ax2, ax_style{:});
    title(ax2, 'Inter-Burst Interval', 'Color', 'w', 'FontSize', 10);
    xlabel(ax2, 'IBI (ms)', 'Color', [0.85 0.85 0.85], 'FontSize', 9);
    ylabel(ax2, 'Count', 'Color', [0.85 0.85 0.85], 'FontSize', 9);

    cla(ax3);
    if ~isempty(br.duration_ms)
        [counts, edges] = hist(br.duration_ms, 20);
        bar(ax3, edges, counts, 1.0, 'FaceColor', [0.95 0.65 0.20], 'EdgeColor', 'none');
    else
        text(0.5, 0.5, 'No bursts detected', 'Units', 'normalized', ...
             'Color', 'w', 'HorizontalAlignment', 'center', 'Parent', ax3);
    end
    set(ax3, ax_style{:});
    title(ax3, 'Burst Duration', 'Color', 'w', 'FontSize', 10);
    xlabel(ax3, 'Duration (ms)', 'Color', [0.85 0.85 0.85], 'FontSize', 9);
    ylabel(ax3, 'Count', 'Color', [0.85 0.85 0.85], 'FontSize', 9);

    if br.count > 0
        set(lblSummary, 'String', sprintf( ...
            'Bursts: %d    Mean duration: %.1f ms    Mean IBI: %.1f ms    Mean intra-burst rate: %.1f Hz', ...
            br.count, mean(br.duration_ms), mean(br.ibi_ms), mean(br.intra_rate)));
    else
        set(lblSummary, 'String', 'No bursts detected with current parameters — try increasing Max ISI or decreasing Min Spikes.');
    end
end
