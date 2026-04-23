function show_network_window(fig)
    state = get(fig, 'UserData');
    if ~state.spikes_computed
        errordlg('Run spike detection first.', 'Network Activity'); return
    end

    fi  = state.current_file_idx;
    ext = state.Extracted(fi);

    win = figure('Name', 'Network Activity — All Channels', ...
                 'Position', [100 80 1040 650], ...
                 'Color', [0.15 0.15 0.18], ...
                 'NumberTitle', 'off', 'MenuBar', 'none');

    ctrl_bg = [0.15 0.15 0.18];

    uicontrol(win, 'Style', 'text', 'String', 'Firing rate bin (ms):', ...
        'Position', [10 620 135 18], 'ForegroundColor', 'w', ...
        'BackgroundColor', ctrl_bg, 'FontSize', 9, 'HorizontalAlignment', 'left');
    efBin = uicontrol(win, 'Style', 'edit', 'String', '50', ...
        'Position', [147 618 45 22], 'FontSize', 9, ...
        'ForegroundColor', 'w', 'BackgroundColor', [0.25 0.25 0.30]);

    uicontrol(win, 'Style', 'text', 'String', 'Synchrony window (ms):', ...
        'Position', [210 620 148 18], 'ForegroundColor', 'w', ...
        'BackgroundColor', ctrl_bg, 'FontSize', 9, 'HorizontalAlignment', 'left');
    efSync = uicontrol(win, 'Style', 'edit', 'String', '5', ...
        'Position', [360 618 45 22], 'FontSize', 9, ...
        'ForegroundColor', 'w', 'BackgroundColor', [0.25 0.25 0.30]);

    btnRun = uicontrol(win, 'Style', 'pushbutton', 'String', 'Run', ...
        'Position', [418 616 70 26], ...
        'BackgroundColor', [0.18 0.52 0.80], 'ForegroundColor', 'w', ...
        'FontSize', 9, 'FontWeight', 'bold');

    ax1 = axes('Parent', win, 'Units', 'pixels', 'Position', [65 360 940 240]);
    ax2 = axes('Parent', win, 'Units', 'pixels', 'Position', [65 55  440 265]);
    ax3 = axes('Parent', win, 'Units', 'pixels', 'Position', [565 55 440 265]);

    set(btnRun, 'Callback', @(s,e) draw_network(ax1, ax2, ax3, state, ext, efBin, efSync));
    draw_network(ax1, ax2, ax3, state, ext, efBin, efSync);
end

function draw_network(ax1, ax2, ax3, state, ext, efBin, efSync)
    bin_ms   = str2double(get(efBin,  'String'));
    sync_win = str2double(get(efSync, 'String')) / 1000;

    net = compute_network_activity(state.spikes, ext.time, bin_ms, sync_win);

    ax_style = {'Color', [0.10 0.10 0.13], ...
                'XColor', [0.85 0.85 0.85], 'YColor', [0.85 0.85 0.85], ...
                'FontSize', 9, 'XGrid', 'on', 'YGrid', 'on', ...
                'GridColor', [0.35 0.35 0.35]};

    % Population firing rate
    cla(ax1);
    bin_centers = net.bin_edges(1:end-1) + diff(net.bin_edges)/2;
    plot(ax1, bin_centers, net.population_rate, ...
         'Color', [0.18 0.52 0.80], 'LineWidth', 1.2);
    set(ax1, ax_style{:});
    title(ax1, sprintf('Population Firing Rate — mean spikes/sec across all active channels (%g ms bins)', bin_ms), ...
          'Color', 'w', 'FontSize', 10);
    xlabel(ax1, 'Time (s)', 'Color', [0.85 0.85 0.85], 'FontSize', 9);
    ylabel(ax1, 'Firing Rate (Hz)', 'Color', [0.85 0.85 0.85], 'FontSize', 9);

    % Synchrony heatmap
    cla(ax2);
    imagesc(ax2, net.sync_index);
    colormap(ax2, hot(256));
    cb = colorbar(ax2);
    ylabel(cb, 'Synchrony Index', 'Color', [0.85 0.85 0.85], 'FontSize', 8);
    set(cb, 'Color', [0.85 0.85 0.85], 'FontSize', 8);
    set(ax2, 'XColor', [0.85 0.85 0.85], 'YColor', [0.85 0.85 0.85], 'FontSize', 8);
    title(ax2, sprintf('Pairwise Synchrony — spikes within %g ms of each other', sync_win*1000), ...
          'Color', 'w', 'FontSize', 10);
    xlabel(ax2, 'Channel Index', 'Color', [0.85 0.85 0.85], 'FontSize', 9);
    ylabel(ax2, 'Channel Index', 'Color', [0.85 0.85 0.85], 'FontSize', 9);

    % Synchrony distribution
    cla(ax3);
    vals = net.sync_index(triu(true(size(net.sync_index)), 1));
    vals = vals(vals > 0);
    if ~isempty(vals)
        [counts, edges] = hist(vals, 20);
        bar(ax3, edges, counts, 1.0, 'FaceColor', [0.20 0.75 0.55], 'EdgeColor', 'none');
    end
    set(ax3, ax_style{:});
    title(ax3, 'Synchrony Distribution across all channel pairs', ...
          'Color', 'w', 'FontSize', 10);
    xlabel(ax3, 'Synchrony Index', 'Color', [0.85 0.85 0.85], 'FontSize', 9);
    ylabel(ax3, 'Channel Pairs', 'Color', [0.85 0.85 0.85], 'FontSize', 9);
end
