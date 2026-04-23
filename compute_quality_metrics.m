function qm = compute_quality_metrics(signal, spike_indices, sort_labels, Fs, snippet_ms)
% COMPUTE_QUALITY_METRICS  SNR, ISI violation rate, isolation distance.
%
% OUTPUTS:
%   qm.snr               — signal-to-noise ratio (peak / noise SD)
%   qm.isi_violation_pct — percent of ISIs < 1 ms
%   qm.isolation_dist    — isolation distance per unit (requires sort_labels)
%   qm.presence_ratio    — fraction of 100ms bins containing at least one spike

    half_win = round((snippet_ms / 1000) * Fs / 2);
    valid = (spike_indices > half_win) & ...
            (spike_indices <= length(signal) - half_win);
    spike_indices = spike_indices(valid);
    N = length(spike_indices);
    M = 2 * half_win + 1;

    if N < 2
        qm.snr = NaN; qm.isi_violation_pct = NaN;
        qm.isolation_dist = NaN; qm.presence_ratio = NaN;
        return
    end

    snippets = zeros(N, M);
    for i = 1:N
        idx = spike_indices(i);
        snippets(i,:) = signal(idx - half_win : idx + half_win);
    end

    % ---- SNR: peak amplitude / noise SD ----
    mean_wf   = mean(snippets, 1);
    peak_amp  = abs(min(mean_wf));
    noise_sd  = std(signal - mean(signal));
    qm.snr    = peak_amp / noise_sd;

    % ---- ISI violations ----
    spike_times_s = spike_indices / Fs;
    isis_ms = diff(sort(spike_times_s)) * 1000;
    qm.isi_violation_pct = 100 * mean(isis_ms < 1.0);

    % ---- Isolation distance (per unit if sorted) ----
    if ~isempty(sort_labels) && ~all(isnan(sort_labels))
    n_units  = max(sort_labels);
    iso_dist = nan(n_units, 1);

    centered = snippets - mean(snippets, 1);
    [V, D]   = eig(centered' * centered);
    [~, ord] = sort(diag(D), 'descend');
    V        = V(:, ord);
    features = centered * V(:, 1:min(3, size(V,2)));

    for u = 1:n_units
        in_mask  = sort_labels == u;
        out_mask = ~in_mask;

        if sum(in_mask) < 4 || sum(out_mask) < sum(in_mask)
            iso_dist(u) = NaN;
            continue
        end

        C = cov(features(in_mask, :));

        if rcond(C) < 1e-10
            iso_dist(u) = NaN;
            continue
        end

        diffs        = features(out_mask, :) - mean(features(in_mask, :), 1);
        dists        = sum((diffs / C) .* diffs, 2);
        sorted_dists = sort(dists);
        n_in         = sum(in_mask);

        if n_in <= length(sorted_dists)
            iso_dist(u) = sorted_dists(n_in);
        else
            iso_dist(u) = NaN;
        end
    end
    qm.isolation_dist = iso_dist;
else
    qm.isolation_dist = NaN;
end

    % ---- Presence ratio ----
    total_time_s = length(signal) / Fs;
    bin_s        = 0.1;
    n_bins       = floor(total_time_s / bin_s);
    occupied     = 0;
    for b = 1:n_bins
        t0 = (b-1) * bin_s * Fs;
        t1 = b * bin_s * Fs;
        if any(spike_indices >= t0 & spike_indices < t1)
            occupied = occupied + 1;
        end
    end
    qm.presence_ratio = occupied / n_bins;
end
