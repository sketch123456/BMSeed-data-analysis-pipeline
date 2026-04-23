function features = extract_features(signal, spike_indices, Fs, snippet_ms)
% EXTRACT_FEATURES  Per-spike waveform feature extraction.
%
% OUTPUTS:
%   features — struct with Nx1 vectors:
%     .peak_amp     trough amplitude (uV)
%     .valley_amp   post-spike peak (uV)
%     .width_ms     spike width at half-maximum (ms)
%     .rise_ms      time from crossing to trough (ms)
%     .decay_ms     time from trough to return to threshold (ms)
%     .energy       sum of squared amplitudes over snippet

    half_win = round((snippet_ms / 1000) * Fs / 2);
    valid = (spike_indices > half_win) & ...
            (spike_indices <= length(signal) - half_win);
    spike_indices = spike_indices(valid);
    N = length(spike_indices);

    peak_amp  = zeros(N,1);
    valley_amp = zeros(N,1);
    width_ms  = zeros(N,1);
    rise_ms   = zeros(N,1);
    decay_ms  = zeros(N,1);
    energy    = zeros(N,1);

    dt_ms = (1/Fs) * 1000;

    for i = 1:N
        idx   = spike_indices(i);
        snip  = signal(idx - half_win : idx + half_win);
        center = half_win + 1;

        [trough_val, trough_loc] = min(snip);
        peak_amp(i) = trough_val;

        % Valley: max after trough
        post = snip(trough_loc:end);
        valley_amp(i) = max(post);

        % Width at half-max
        half_max = trough_val / 2;
        before_trough = snip(1:trough_loc);
        after_trough  = snip(trough_loc:end);
        cross_before = find(before_trough >= half_max, 1, 'last');
        cross_after  = find(after_trough  >= half_max, 1, 'first');
        if ~isempty(cross_before) && ~isempty(cross_after)
            width_ms(i) = (trough_loc - cross_before + cross_after - 1) * dt_ms;
        end

        % Rise: threshold crossing to trough
        before = snip(1:trough_loc);
        cross_thresh = find(before < half_max, 1, 'first');
        if ~isempty(cross_thresh)
            rise_ms(i) = (trough_loc - cross_thresh) * dt_ms;
        end

        % Decay: trough back to half-max
        if ~isempty(cross_after)
            decay_ms(i) = cross_after * dt_ms;
        end

        energy(i) = sum(snip .^ 2);
    end

    features.peak_amp  = peak_amp;
    features.valley_amp = valley_amp;
    features.width_ms  = width_ms;
    features.rise_ms   = rise_ms;
    features.decay_ms  = decay_ms;
    features.energy    = energy;
    features.N         = N;
end
