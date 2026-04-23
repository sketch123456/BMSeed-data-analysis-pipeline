function [n,conf] = estimate_n_units(features, max_units)
% ESTIMATE_N_UNITS  Elbow method to find optimal cluster count.
%
% Runs k-means for k=1..max_units, computes within-cluster sum of squares
% (inertia) for each, then finds the elbow point using maximum curvature.

    max_units = min(max_units, size(features, 1) - 1);
    if max_units < 2
        n = 1;
        conf = 0;
        return
    end

    inertia = zeros(max_units, 1);
    for k = 1:max_units
        if k == 1
            inertia(k) = sum(sum((features - mean(features, 1)).^2));
        else
            labels = kmeans(features, k, 'Replicates', 3);
            total  = 0;
            for u = 1:k
                mask = labels == u;
                if any(mask)
                    total = total + sum(sum((features(mask,:) - mean(features(mask,:), 1)).^2));
                end
            end
            inertia(k) = total;
        end
    end

    % Find elbow: point of maximum curvature
    % Normalize inertia to 0-1 range first
    inertia_norm = (inertia - min(inertia)) / (max(inertia) - min(inertia) + 1e-10);
    ks = (1:max_units)';
    ks_norm = (ks - 1) / (max_units - 1);

    % Distance from each point to the line connecting first and last point
    p1 = [ks_norm(1),   inertia_norm(1)];
    p2 = [ks_norm(end), inertia_norm(end)];
    line_vec = p2 - p1;
    line_len = norm(line_vec);

    dists = zeros(max_units, 1);
    for i = 1:max_units
        pt  = [ks_norm(i), inertia_norm(i)];
        dists(i) = abs(cross2d(line_vec, p1 - pt)) / line_len;
    end

    [max_dist, n] = max(dists);
    if max_dist > 0
        % Calculate how much the elbow "pops" relative to the noise
        conf = (max_dist / sum(dists)) * 100;

        % Rescale so that a "perfectly straight line" doesn't give high conf
        % A value above 30% usually indicates a very strong elbow.
        conf = min(100, conf * 2);
    else
        conf = 0;
    end

    n = max(1, n);
  end
