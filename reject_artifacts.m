function [clean_indices, artifact_mask] = reject_artifacts(signal, spike_indices, Fs, snippet_ms, amp_limit_uv, common_mode_signals)
% REJECT_ARTIFACTS  Flag spikes likely caused by artifacts.
%
% INPUTS:
%   signal              — single-channel filtered signal (uV)
%   spike_indices       — candidate spike sample indices
%   Fs                  — sampling rate (Hz)
%   snippet_ms          — snippet window (ms)
%   amp_limit_uv        — absolute amplitude above which a spike is artifact
%   common_mode_signals — matrix [n_samples x n_other_chs] for common-mode
%                         detection; pass [] to skip
%
% OUTPUTS:
%   clean_indices — spike_indices with artifacts removed
%   artifact_mask — logical vector, true = artifact, same length as spike_indices

    half_win = round((snippet_ms / 1000) * Fs / 2);
    N = length(spike_indices);
    artifact_mask = false(N, 1);

    for i = 1:N
        idx = spike_indices(i);
        if idx <= half_win || idx > length(signal) - half_win
            artifact_mask(i) = true;
            continue
        end
        snip = signal(idx - half_win : idx + half_win);

        % Rule 1: amplitude exceeds physiological limit
        if abs(min(snip)) > amp_limit_uv || abs(max(snip)) > amp_limit_uv
            artifact_mask(i) = true;
            continue
        end

        % Rule 2: common-mode artifact — spike appears simultaneously on
        % a large fraction of other channels
        if ~isempty(common_mode_signals)
            n_other = size(common_mode_signals, 2);
            coincident = 0;
            for j = 1:n_other
                other_snip = common_mode_signals(idx - half_win : idx + half_win, j);
                if abs(min(other_snip)) > amp_limit_uv * 0.5
                    coincident = coincident + 1;
                end
            end
            if coincident / n_other > 0.5
                artifact_mask(i) = true;
            end
        end
    end

    clean_indices = spike_indices(~artifact_mask);
end
