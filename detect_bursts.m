function burst_results = detect_bursts(spike_times, max_isi_ms, min_spikes_per_burst)
% DETECT_BURSTS  ISI-threshold burst detection.
%
% INPUTS:
%   spike_times          — vector of spike timestamps (s)
%   max_isi_ms           — max inter-spike interval within a burst (ms)
%   min_spikes_per_burst — minimum spikes to count as a burst
%
% OUTPUTS:
%   burst_results.starts      — burst start times (s)
%   burst_results.ends        — burst end times (s)
%   burst_results.n_spikes    — spike count per burst
%   burst_results.duration_ms — burst duration (ms)
%   burst_results.ibi_ms      — inter-burst intervals (ms)
%   burst_results.intra_rate  — mean intra-burst firing rate (Hz) per burst

    if length(spike_times) < min_spikes_per_burst
        burst_results = empty_burst_results();
        return
    end

    spike_times = sort(spike_times(:));
    isis_ms     = diff(spike_times) * 1000;
    in_burst    = isis_ms <= max_isi_ms;

    starts = []; ends = []; n_spikes = [];

    i = 1;
    while i <= length(in_burst)
        if in_burst(i)
            burst_start = i;
            while i <= length(in_burst) && in_burst(i)
                i = i + 1;
            end
            burst_end = i;   % last spike index in burst
            count     = burst_end - burst_start + 1;
            if count >= min_spikes_per_burst
                starts   = [starts;   spike_times(burst_start)];
                ends     = [ends;     spike_times(burst_end)];
                n_spikes = [n_spikes; count];
            end
        end
        i = i + 1;
    end

    if isempty(starts)
        burst_results = empty_burst_results();
        return
    end

    duration_ms = (ends - starts) * 1000;
    intra_rate  = (n_spikes - 1) ./ (ends - starts);
    intra_rate(~isfinite(intra_rate)) = 0;

    ibi_ms = [];
    if length(starts) > 1
        ibi_ms = (starts(2:end) - ends(1:end-1)) * 1000;
    end

    burst_results.starts      = starts;
    burst_results.ends        = ends;
    burst_results.n_spikes    = n_spikes;
    burst_results.duration_ms = duration_ms;
    burst_results.ibi_ms      = ibi_ms;
    burst_results.intra_rate  = intra_rate;
    burst_results.count       = length(starts);
end

function br = empty_burst_results()
    br.starts = []; br.ends = []; br.n_spikes = [];
    br.duration_ms = []; br.ibi_ms = [];
    br.intra_rate = []; br.count = 0;
end
