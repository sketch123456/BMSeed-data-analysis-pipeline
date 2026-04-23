function [spike_times, spike_indices, threshold] = detect_spikes(signal, filter_mode, filter_order, highp, lowp, time, Fs, mode, thresh_param, refrac_ms)
% Detects spikes in a single-channel MEA recording.
%
% INPUTS:
%   signal       — vector of voltage values (uV), one per sample
%   time         — vector of timestamps (s), same length as signal
%   Fs           — sampling rate (Hz)
%   mode         — 'relative' or 'absolute'
%   thresh_param — multiplier (relative) or voltage threshold (absolute)
%   refrac_ms    — refractory period in milliseconds
%
% OUTPUTS:
%   spike_times   — timestamps of detected spikes (s)
%   spike_indices — sample indices of detected spikes
%   threshold     — the threshold value used (uV)


    filtered = signal;
    % ---- Stage 2: Threshold computation ----
    if strcmp(mode, 'relative')
        noise_sd  = median(abs(filtered)) / 0.6745;
        threshold = -thresh_param * noise_sd;
    elseif strcmp(mode, 'absolute')
        if thresh_param >= 0
            disp('Warning: positive threshold entered. Spikes are negative deflections.');
        end
        threshold = thresh_param;

    elseif strcmp(mode, 'peak')
        vrms_filtered = rms(filtered);
        threshold = -thresh_param * vrms_filtered;
        refrac_samples_fp = round(refrac_ms / 1000 * Fs);
        warning('off', 'all');
        [~, locs] = findpeaks(-filtered, ...
                          'MinPeakHeight',    abs(threshold), ...
                          'MinPeakDistance',  refrac_samples_fp, ...
                          'DoubleSided');
        warning('on','all');
        spike_indices = locs(:);
        spike_times = time(spike_indices);
        spike_times = spike_times(:);
        return
    elseif strcmp(mode,'relative_vrms')
        vrms_filtered = rms(filtered);
        threshold = -thresh_param * vrms_filtered;
    else
        disp('Invalid mode. Defaulting to relative threshold, multiplier 4.');
        noise_sd  = median(abs(filtered)) / 0.6745;
        threshold = -4 * noise_sd;
    end

    % ---- Stage 3: Crossing detection ----
    below   = filtered < threshold;
    indices = find(diff([false; below]) == 1);

    % ---- Stage 4: Refractory enforcement ----
    refrac_samples = refrac_ms / (Fs / 1000);
    valid = [];
    last  = -Inf;

    for i = indices
        if (i - last) >= refrac_samples
            valid = [valid, i];
            last  = i;
        end
    end

    % ---- Assemble outputs ----
    spike_indices = valid(:);
    spike_times   = time(spike_indices);
    spike_times   = spike_times(:);

end
