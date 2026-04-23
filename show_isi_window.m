function show_isi_window(fig)
    state = get(fig, 'UserData');
    if ~state.spikes_computed
        errordlg('Run spike detection first.', 'ISI Analysis'); return
    end
    h      = getappdata(fig, 'handles');
    refrac = str2double(get(h.efRefrac, 'String'));   % reads from the GUI field
    fi  = state.current_file_idx;
    chi = state.current_ch_idx;
    ext = state.Extracted(fi);

    st = state.spikes{chi};
    if length(st) < 2
        errordlg('Not enough spikes for ISI analysis (need at least 2).', 'ISI Analysis'); return
    end

    isi = compute_isi(st);

    win = figure('Name', sprintf('ISI Analysis — Ch %s', ext.id_label{chi}), ...
                 'Position', [200 150 860 520], ...
                 'Color', [0.15 0.15 0.18], ...
                 'NumberTitle', 'off', 'MenuBar', 'none');

    % Left: ISI histogram
    ax1 = axes('Parent', win, 'Position', [0.07 0.14 0.56 0.74]);
    [counts, edges] = hist(isi.intervals_ms, 50);
    bar(ax1, edges, counts, 1.0, 'FaceColor', [0.18 0.52 0.80], 'EdgeColor', 'none');
    hold(ax1, 'on');
    drawnow();

    y_max = max(counts) * 1.15;
    if y_max == 0, y_max = 1; end
    ylim(ax1, [0 y_max]);

    patch(ax1, [0 refrac refrac 0], [0 0 y_max y_max], [0.85 0.25 0.25], ...
      'FaceAlpha', 0.30, 'EdgeColor', 'none');
    plot(ax1, [refrac refrac], [0 y_max], 'r--', 'LineWidth', 1.8);
    text(ax1, refrac * 1.4, y_max * 0.90, sprintf('%.1f ms refractory boundary', refrac), ...
     'Color', [1 0.5 0.5], 'FontSize', 8);

    hold(ax1, 'off');

    set(ax1, 'Color', [0.10 0.10 0.13], ...
             'XColor', [0.85 0.85 0.85], 'YColor', [0.85 0.85 0.85], ...
             'FontSize', 9, 'XGrid', 'on', 'YGrid', 'on', ...
             'GridColor', [0.35 0.35 0.35]);
    title(ax1, 'Inter-Spike Interval Histogram — time between consecutive spikes on this channel', ...
          'Color', 'w', 'FontSize', 9);
    xlabel(ax1, 'ISI (ms)   [red zone = refractory period violations, physiologically impossible]', ...
           'Color', [0.85 0.85 0.85], 'FontSize', 8);
    ylabel(ax1, 'Spike Pair Count', 'Color', [0.85 0.85 0.85], 'FontSize', 9);

    % Right: stats panel
    ax2 = axes('Parent', win, 'Position', [0.70 0.14 0.27 0.74]);
    axis(ax2, 'off');
    set(ax2, 'Color', [0.12 0.12 0.15]);

    if isi.violation_rate > 0.01
        viol_color = [0.95 0.35 0.25];
        viol_note  = '  ← HIGH';
    else
        viol_color = [0.20 0.75 0.45];
        viol_note  = '  ← OK';
    end

    if isi.cv < 0.5
        cv_note = '  ← regular';
    elseif isi.cv < 1.0
        cv_note = '  ← irregular';
    else
        cv_note = '  ← bursty';
    end

    entries = {
        'SPIKE COUNT',       sprintf('%d',          length(st)),          'w';
        'Mean ISI',          sprintf('%.2f ms',     isi.mean_ms),         'w';
        'Firing Rate',       sprintf('%.2f Hz',     isi.mean_rate_hz),    'w';
        'CV of ISI',         sprintf('%.3f%s',      isi.cv, cv_note),     'w';
        'ISI Violations',    sprintf('%.2f%%%s',    isi.violation_rate*100, viol_note), viol_color;
        'Min ISI',           sprintf('%.2f ms',     min(isi.intervals_ms)), 'w';
        'Max ISI',           sprintf('%.2f ms',     max(isi.intervals_ms)), 'w';
    };

    descriptions = {
        'total detected spikes';
        'average time between spikes';
        '1000 / mean ISI';
        '<0.5 regular, 0.5-1 irregular, >1 bursty';
        'ISIs under 1 ms (should be ~0%)';
        'shortest interval between any two spikes';
        'longest interval between any two spikes';
    };

    for i = 1:size(entries,1)
        y = 0.96 - (i-1) * 0.128;
        text(ax2, 0.0, y,      entries{i,1}, 'Color', [0.60 0.60 0.65], ...
             'FontSize', 8,  'Units', 'normalized', 'FontWeight', 'bold');
        text(ax2, 0.0, y-0.05, entries{i,2}, 'Color', entries{i,3}, ...
             'FontSize', 10, 'Units', 'normalized', 'FontWeight', 'bold');
        text(ax2, 0.0, y-0.085, descriptions{i}, 'Color', [0.45 0.45 0.50], ...
             'FontSize', 7,  'Units', 'normalized');
    end
end
