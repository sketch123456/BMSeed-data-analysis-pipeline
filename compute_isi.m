function isi_results = compute_isi(spike_times)
% COMPUTE_ISI  Inter-spike interval analysis for a single channel.
%
% OUTPUTS:
%   isi_results.intervals_ms  — all ISI values (ms)
%   isi_results.mean_ms       — mean ISI (ms)
%   isi_results.cv            — coefficient of variation
%   isi_results.violation_rate — fraction of ISIs < 1 ms (refractory violations)
%   isi_results.mean_rate_hz  — mean firing rate (Hz)

    if length(spike_times) < 2
        isi_results.intervals_ms   = [];
        isi_results.mean_ms        = NaN;
        isi_results.cv             = NaN;
        isi_results.violation_rate = NaN;
        isi_results.mean_rate_hz   = NaN;
        return
    end

    intervals_ms = diff(sort(spike_times)) * 1000;

    isi_results.intervals_ms   = intervals_ms;
    isi_results.mean_ms        = mean(intervals_ms);
    isi_results.cv             = std(intervals_ms) / mean(intervals_ms);
    isi_results.violation_rate = mean(intervals_ms < 1.0);
    isi_results.mean_rate_hz   = 1000 / mean(intervals_ms);
end
