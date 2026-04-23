function show_sorting_window(fig)
    state = get(fig, 'UserData');
    if ~state.spikes_computed
        errordlg('Run spike detection first.', 'Spike Sorting'); return
    end

    fi  = state.current_file_idx;
    chi = state.current_ch_idx;
    ext = state.Extracted(fi);
    Fs  = state.Files_Data(fi).fqz_param.amplifier_sample_rate;

    spike_idx = state.spikes_indices{chi};
    if isempty(spike_idx)
        errordlg('No spikes detected on this channel.', 'Spike Sorting'); return
    end

    % Estimate n_units before building UI so we can set the default
    snip_ms_default = 3.0;
    half_win = round((snip_ms_default / 1000) * Fs / 2);
    sig      = ext.data(:, chi);
    valid    = (spike_idx > half_win) & (spike_idx <= length(sig) - half_win);
    si_valid = spike_idx(valid);
    N = length(si_valid);
    M = 2 * half_win + 1;

    snippets = zeros(N, M);
    for i = 1:N
        snippets(i,:) = sig(si_valid(i) - half_win : si_valid(i) + half_win);
    end
    centered = snippets - mean(snippets, 1);
    [V, D]   = eig(centered' * centered);
    [~, ord] = sort(diag(D), 'descend');
    V        = V(:, ord);
    features = centered * V(:, 1:min(3, size(V,2)));

    [suggested_n,confidence] = estimate_n_units(features, 6);

    % Build UI
    win = figure('Name', sprintf('Spike Sorting — Ch %s', ext.id_label{chi}), ...
                 'Position', [200 150 960 560], ...
                 'Color', [0.15 0.15 0.18], ...
                 'NumberTitle', 'off', 'MenuBar', 'none');

    uicontrol(win, 'Style', 'text', 'String', 'Method:', ...
        'Position', [10 530 60 18], 'ForegroundColor', 'w', ...
        'BackgroundColor', [0.15 0.15 0.18], 'FontSize', 9);
    ddMethod = uicontrol(win, 'Style', 'popupmenu', ...
        'String', {'kmeans','gmm'}, 'Value', 1, ...
        'Position', [70 528 100 22], 'FontSize', 9);

    uicontrol(win, 'Style', 'text', 'String', 'Units:', ...
        'Position', [185 530 45 18], 'ForegroundColor', 'w', ...
        'BackgroundColor', [0.15 0.15 0.18], 'FontSize', 9);
    efUnits = uicontrol(win, 'Style', 'edit', ...
        'String', num2str(suggested_n), ...   % <-- elbow estimate as default
        'Position', [230 528 35 22], 'FontSize', 9);

    % Label showing the suggestion
    uicontrol(win, 'Style', 'text', ...
        'String', sprintf('(suggested: %d, Conf: %0.f%%)', suggested_n, confidence), ...
        'Position', [268 530 100 18], 'ForegroundColor', [0.55 0.75 0.35], ...
        'BackgroundColor', [0.15 0.15 0.18], 'FontSize', 8);

    uicontrol(win, 'Style', 'text', 'String', 'Snippet (ms):', ...
        'Position', [375 530 85 18], 'ForegroundColor', 'w', ...
        'BackgroundColor', [0.15 0.15 0.18], 'FontSize', 9);
    efSnip = uicontrol(win, 'Style', 'edit', 'String', '3.0', ...
        'Position', [460 528 40 22], 'FontSize', 9);

    btnRun = uicontrol(win, 'Style', 'pushbutton', 'String', 'Run', ...
        'Position', [512 526 60 26], ...
        'BackgroundColor', [0.18 0.52 0.80], 'ForegroundColor', 'w', ...
        'FontSize', 9, 'FontWeight', 'bold');

    ax1 = axes('Parent', win, 'Position', [0.04 0.10 0.44 0.82], ...
               'Color', [0.10 0.10 0.13], ...
               'XColor', [0.7 0.7 0.7], 'YColor', [0.7 0.7 0.7]);
    ax2 = axes('Parent', win, 'Position', [0.54 0.10 0.44 0.82], ...
               'Color', [0.10 0.10 0.13], ...
               'XColor', [0.7 0.7 0.7], 'YColor', [0.7 0.7 0.7]);

    set(btnRun, 'Callback', @(s,e) run_and_plot(fig, win, ax1, ax2, ...
        ext, spike_idx, Fs, ddMethod, efUnits, efSnip, chi));

    run_and_plot(fig, win, ax1, ax2, ext, spike_idx, Fs, ddMethod, efUnits, efSnip, chi);
end

function run_and_plot(fig, win, ax1, ax2, ext, spike_idx, Fs, ddMethod, efUnits, efSnip, chi)
    methods  = {'kmeans','gmm'};
    method   = methods{get(ddMethod, 'Value')};
    n_units  = max(2, round(str2double(get(efUnits, 'String'))));
    snip_ms  = str2double(get(efSnip, 'String'));

    sig = ext.data(:, chi);
    sr  = sort_spikes(sig, spike_idx, Fs, method, n_units, snip_ms);

    unit_colors = lines(n_units);
    t_snip = linspace(-snip_ms/2, snip_ms/2, sr.M);

    % ---- PCA scatter ----
    cla(ax1);
    hold(ax1, 'on');
    for u = 1:n_units
        mask = sr.labels == u;
        if ~any(mask), continue; end
        scatter(ax1, sr.features(mask,1), sr.features(mask,2), 20, ...
                'MarkerFaceColor', unit_colors(u,:), ...
                'MarkerEdgeColor', 'none', ...
                'MarkerFaceAlpha', 0.7);
    end
    scatter(ax1, sr.centroids(:,1), sr.centroids(:,2), 80, ...
            unit_colors, 'p', 'filled', 'MarkerEdgeColor', 'w');
    legend_strs = arrayfun(@(u) sprintf('Unit %d  (n=%d)', u, sum(sr.labels==u)), ...
                           1:n_units, 'UniformOutput', false);
    legend(ax1, legend_strs, 'TextColor', 'w', 'Color', [0.2 0.2 0.2], ...
           'Location', 'best');
    title(ax1, 'PCA Feature Space', 'Color', 'w');
    xlabel(ax1, 'PC1'); ylabel(ax1, 'PC2');
    hold(ax1, 'off');

    % ---- Mean waveforms ± SD, all units ----
    cla(ax2);
    hold(ax2, 'on');
    for u = 1:n_units
        mu  = sr.mean_waveforms(u,:);
        sd  = sr.std_waveforms(u,:);
        col = unit_colors(u,:);
        % SD band
        fill(ax2, [t_snip, fliplr(t_snip)], ...
             [mu + sd, fliplr(mu - sd)], col, ...
             'FaceAlpha', 0.25, 'EdgeColor', 'none');
        % Mean line
        plot(ax2, t_snip, mu, 'Color', col, 'LineWidth', 2);
    end
    h = line(ax2, [0 0], get(ax2, 'YLim'), 'Color', [0.5 0.5 0.5], 'LineStyle', '--');
    title(ax2, 'Mean Waveforms \pm SD', 'Color', 'w');
    xlabel(ax2, 'Time (ms)'); ylabel(ax2, 'Amplitude (uV)');
    hold(ax2, 'off');

    % Save sort results back to state
    state = get(fig, 'UserData');
    state.sort_results{chi} = sr;
    state.sort_results{chi}.snip_ms = snip_ms;
    set(fig, 'UserData', state);
end
