function show_waveform_window(fig)
    state = get(fig, 'UserData');
    if ~state.spikes_computed
        errordlg('Run spike detection first.', 'Waveform Viewer'); return
    end

    fi  = state.current_file_idx;
    chi = state.current_ch_idx;
    ext = state.Extracted(fi);
    Fs  = state.Files_Data(fi).fqz_param.amplifier_sample_rate;

    spike_idx = state.spikes_indices{chi};
    if isempty(spike_idx)
        errordlg('No spikes on this channel.', 'Waveform Viewer'); return
    end

    win = figure('Name', sprintf('Waveform Viewer — Ch %s', ext.id_label{chi}), ...
                 'Position', [200 150 860 540], ...
                 'Color', [0.15 0.15 0.18], ...
                 'NumberTitle', 'off', 'MenuBar', 'none');

    % Snippet window control
    uicontrol(win, 'Style', 'text', 'String', 'Snippet window (ms):', ...
        'Position', [10 510 140 20], 'ForegroundColor', 'w', ...
        'BackgroundColor', [0.15 0.15 0.18], 'FontSize', 9);
    efSnip = uicontrol(win, 'Style', 'edit', 'String', '3.0', ...
        'Position', [155 510 45 22], 'FontSize', 9);

    uicontrol(win, 'Style', 'text', 'String', 'Max overlays:', ...
        'Position', [215 510 90 20], 'ForegroundColor', 'w', ...
        'BackgroundColor', [0.15 0.15 0.18], 'FontSize', 9);
    efMaxOverlay = uicontrol(win, 'Style', 'edit', 'String', '150', ...
        'Position', [308 510 45 22], 'FontSize', 9);

    btnRun = uicontrol(win, 'Style', 'pushbutton', 'String', 'Redraw', ...
        'Position', [365 508 70 26], ...
        'BackgroundColor', [0.18 0.52 0.80], 'ForegroundColor', 'w', ...
        'FontSize', 9, 'FontWeight', 'bold');

    ax = axes('Parent', win, 'Position', [0.08 0.10 0.88 0.82]);

    set(btnRun, 'Callback', @(s,e) draw_waveforms(ax, ext, spike_idx, Fs, efSnip, efMaxOverlay, chi));
    draw_waveforms(ax, ext, spike_idx, Fs, efSnip, efMaxOverlay, chi);
end

function draw_waveforms(ax, ext, spike_idx, Fs, efSnip, efMaxOverlay, chi)
    snip_ms     = str2double(get(efSnip, 'String'));
    max_overlay = round(str2double(get(efMaxOverlay, 'String')));
    half_win    = round((snip_ms / 1000) * Fs / 2);

    sig   = ext.data(:, chi);
    valid = (spike_idx > half_win) & (spike_idx <= length(sig) - half_win);
    spike_idx = spike_idx(valid);
    N = length(spike_idx);
    M = 2 * half_win + 1;
    t_snip = linspace(-snip_ms/2, snip_ms/2, M);

    snippets = zeros(N, M);
    for i = 1:N
        snippets(i,:) = sig(spike_idx(i) - half_win : spike_idx(i) + half_win);
    end
    mu = mean(snippets, 1);
    sd = std(snippets, 0, 1);

    cla(ax);
    hold(ax, 'on');

    n_draw = min(N, max_overlay);
    for i = 1:n_draw
        plot(ax, t_snip, snippets(i,:), 'Color', [0.20 0.35 0.52], 'LineWidth', 0.5);
    end

    fill(ax, [t_snip, fliplr(t_snip)], [mu+sd, fliplr(mu-sd)], ...
         [0.95 0.65 0.20], 'FaceAlpha', 0.30, 'EdgeColor', 'none');
    plot(ax, t_snip, mu, 'Color', [0.95 0.65 0.20], 'LineWidth', 2.5);

    % Zero crossing marker
    plot(ax, [0 0], ylim(ax), 'Color', [0.6 0.6 0.6], ...
         'LineStyle', '--', 'LineWidth', 1.0);

    hold(ax, 'off');
    set(ax, 'Color', [0.10 0.10 0.13], ...
            'XColor', [0.85 0.85 0.85], 'YColor', [0.85 0.85 0.85], ...
            'FontSize', 9, 'XGrid', 'on', 'YGrid', 'on', ...
            'GridColor', [0.35 0.35 0.35]);
    title(ax, sprintf('Waveform Overlays — %d spikes shown (of %d total)   orange = mean \\pm SD   blue = individual spikes', ...
          n_draw, N), 'Color', 'w', 'FontSize', 9);
    xlabel(ax, 'Time relative to spike crossing (ms)   [0 = threshold crossing point]', ...
           'Color', [0.85 0.85 0.85], 'FontSize', 9);
    ylabel(ax, 'Amplitude (uV)', 'Color', [0.85 0.85 0.85], 'FontSize', 9);
end
