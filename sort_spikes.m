function sort_results = sort_spikes(signal, spike_indices, Fs, method, n_units, snippet_ms)
% SORT_SPIKES  Assign detected spikes to putative units via PCA + clustering.
%
% INPUTS:
%   signal        — filtered single-channel signal (uV)
%   spike_indices — sample indices from detect_spikes
%   Fs            — sampling rate (Hz)
%   method        — 'kmeans' or 'gmm'
%   n_units       — number of clusters to fit
%   snippet_ms    — total waveform window in ms (e.g. 2.0)
%
% OUTPUTS:
%   sort_results.labels         — unit assignment per spike (1..n_units)
%   sort_results.features       — Nx2 PCA scores
%   sort_results.snippets       — NxM waveform matrix
%   sort_results.mean_waveforms — n_units x M mean waveform per unit
%   sort_results.std_waveforms  — n_units x M SD waveform per unit
%   sort_results.centroids      — n_units x 2 centroids in PCA space

    half_win = round((snippet_ms / 1000) * Fs / 2);

    % ---- Extract snippets ----
    valid = (spike_indices > half_win) & ...
            (spike_indices <= length(signal) - half_win);
    spike_indices = spike_indices(valid);
    N = length(spike_indices);
    M = 2 * half_win + 1;

    snippets = zeros(N, M);
    for i = 1:N
        idx = spike_indices(i);
        snippets(i, :) = signal(idx - half_win : idx + half_win);
    end

    % ---- PCA ----
    centered = snippets - mean(snippets, 1);
    C = (centered' * centered) / (size(centered, 1) - 1);
    [V, D] = eig(C);
    % eig returns eigenvalues in ascending order — flip to descending
    [~, order] = sort(diag(D), 'descend');
    V = V(:, order);
    scores = centered * V;
    features   = scores(:, 1:min(3, size(scores, 2)));
    features2d = scores(:, 1:2);

    % ---- Clustering ----
    if strcmp(method, 'kmeans') || N < 10
        labels = kmeans(features, n_units, 'Replicates', 5);
    elseif strcmp(method, 'gmm')
        try
            gm     = fitgmdist(features, n_units, ...
                               'RegularizationValue', 0.01, ...
                               'Replicates', 5);
            labels = cluster(gm, features);
        catch
            warning('GMM failed — falling back to k-means.');
            labels = kmeans(features, n_units, 'Replicates', 5);
        end
    end

    % ---- Per-unit stats ----
    mean_waveforms = zeros(n_units, M);
    std_waveforms  = zeros(n_units, M);
    centroids      = zeros(n_units, 2);
    for u = 1:n_units
        mask = labels == u;
        if any(mask)
            mean_waveforms(u,:) = mean(snippets(mask,:), 1);
            std_waveforms(u,:)  = std(snippets(mask,:), 0, 1);
            centroids(u,:)      = mean(features2d(mask,:), 1);
        end
    end

    sort_results.labels         = labels;
    sort_results.features       = features2d;
    sort_results.snippets       = snippets;
    sort_results.mean_waveforms = mean_waveforms;
    sort_results.std_waveforms  = std_waveforms;
    sort_results.centroids      = centroids;
    sort_results.n_units        = n_units;
    sort_results.M              = M;
end
