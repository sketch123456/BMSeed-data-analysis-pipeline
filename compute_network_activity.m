function net = compute_network_activity(all_spike_times, time, bin_ms, sync_win_s)
% COMPUTE_NETWORK_ACTIVITY  Population firing rate + cross-channel synchrony.
%
% INPUTS:
%   all_spike_times — cell array {1 x n_chs}, each cell a spike time vector
%   time            — time vector (s) from Extracted
%   bin_ms          — bin width for firing rate (ms)
%
% OUTPUTS:
%   net.population_rate — firing rate (Hz) over time bins
%   net.bin_edges       — bin edge times (s)
%   net.sync_index      — pairwise synchrony matrix (n_chs x n_chs)
%   net.xcorr_pairs     — cell of xcorr vectors for each channel pair

    n_chs  = length(all_spike_times);
    bin_s  = bin_ms / 1000;
    edges  = time(1) : bin_s : time(end);
    n_bins = length(edges) - 1;

    % ---- Population firing rate ----
    pop_counts = zeros(1, n_bins);
    for k = 1:n_chs
        st = all_spike_times{k};
        if isempty(st), continue; end
        counts = histc(st, edges);
        counts = counts(1:end-1);
        pop_counts = pop_counts + counts;
    end
    net.population_rate = pop_counts / (n_chs * bin_s);
    net.bin_edges       = edges;

    % ---- Pairwise synchrony index ----
    % Synchrony: fraction of spikes within 5 ms of any spike on the other channel
    sync_mat   = zeros(n_chs, n_chs);
    for i = 1:n_chs
        for j = i+1:n_chs
            si = sort(all_spike_times{i});
            sj = sort(all_spike_times{j});
            if isempty(si) || isempty(sj)
                continue
            end
            count = 0;
            claimed = zeros(1,length(sj));
            for s = 1:length(si)
                matches = find(abs(sj - si(s)) <= sync_win_s & ~claimed);
                if ~isempty(matches)
                  claimed(matches(1)) = true;
                  count = count + 1;
                end
            end
            val = count / (length(si) + length(sj) - sum(claimed));
            sync_mat(i,j) = val;
            sync_mat(j,i) = val;
        end
    end
    net.sync_index = sync_mat;
end
