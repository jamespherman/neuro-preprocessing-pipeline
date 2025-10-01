function success = generate_anticorrelation_report(job, config)
% GENERATE_ANTICORRELATION_REPORT Calculates and saves a report of anti-correlated clusters.
%
%   This function takes the output from a Kilosort job and calculates the
%   pairwise Pearson correlation between all identified neural clusters.
%   It bins the spike times into 5-second non-overlapping windows to do
%   this. The primary purpose is to identify pairs of clusters that may be
%   candidates for merging, which often exhibit strong negative
%   correlations.
%
%   Inputs:
%       job    - A row from the session manifest table, containing metadata
%                for the current processing job.
%       config - A struct containing the pipeline's configuration parameters,
%                such as data paths and the sampling rate.
%
%   Output:
%       success - A boolean (true/false) indicating whether the report
%                 was generated and saved successfully.
%
%   The function saves a CSV file named:
%   '{unique_id}_anticorrelation_report.csv' in the 'diagnostics'
%   sub-folder of the session's output directory. This report contains
%   three columns: ClusterID_1, ClusterID_2, and the calculated
%   'Correlation' value, sorted in ascending order of correlation.

success = false; % Default to failure

try
    %% --- 1. Setup Paths ---
    session_output_dir = fullfile(config.processedDataDir, job.unique_id);
    diagnostics_dir = fullfile(session_output_dir, 'diagnostics');
    if ~isfolder(diagnostics_dir)
        mkdir(diagnostics_dir);
    end

    % Input files from Kilosort
    spike_times_file = fullfile(session_output_dir, 'spike_times.npy');
    spike_clusters_file = fullfile(session_output_dir, 'spike_clusters.npy');
    cluster_info_file = fullfile(session_output_dir, 'cluster_info.tsv');

    % Output file
    output_csv_path = fullfile(diagnostics_dir, ...
        sprintf('%s_anticorrelation_report.csv', job.unique_id));

    %% --- 2. Load Data ---
    spike_times_samples = utils.readNPY(spike_times_file);
    spike_clusters = utils.readNPY(spike_clusters_file);
    cluster_info = readtable(cluster_info_file, 'FileType', 'text', 'Delimiter', '\t');

    %% --- 3. Define Time Bins ---
    % Determine session duration and create 5-second bins
    max_time_samples = double(max(spike_times_samples));
    session_duration_sec = max_time_samples / config.samplingRate;
    bin_width_sec = 5;
    bin_edges = 0:bin_width_sec:session_duration_sec;
    n_bins = numel(bin_edges) - 1;

    %% --- 4. Calculate Binned Firing Rates ---
    unique_cluster_ids = unique(spike_clusters);
    n_clusters = numel(unique_cluster_ids);
    binned_firing_rates = zeros(n_clusters, n_bins);

    for i = 1:n_clusters
        cluster_id = unique_cluster_ids(i);

        % Select spike times for the current cluster
        cluster_spike_indices = (spike_clusters == cluster_id);
        cluster_spike_times_samples = spike_times_samples(cluster_spike_indices);

        % Convert spike times to seconds
        cluster_spike_times_sec = double(cluster_spike_times_samples) / config.samplingRate;

        % Bin spike counts and calculate firing rate
        spike_counts = histcounts(cluster_spike_times_sec, bin_edges);
        binned_firing_rates(i, :) = spike_counts / bin_width_sec;
    end

    %% --- 5. Compute Correlation Matrix ---
    % Transpose is needed because corr() expects columns to be variables
    correlation_matrix = corr(binned_firing_rates');

    %% --- 6. Extract and Sort Anti-correlated Pairs ---
    % Use tril to get the lower triangle, avoiding duplicates and self-correlations
    [row, col] = find(tril(correlation_matrix, -1) < 0);

    if isempty(row)
        fprintf('No anti-correlated cluster pairs found for %s.\n', job.unique_id);
        % Still create an empty report for consistency
        anticorrelated_pairs = table('Size', [0 3], ...
                                     'VariableTypes', {'uint32', 'uint32', 'double'}, ...
                                     'VariableNames', {'ClusterID_1', 'ClusterID_2', 'Correlation'});
    else
        correlations = zeros(numel(row), 1);
        for i = 1:numel(row)
            correlations(i) = correlation_matrix(row(i), col(i));
        end

        % Create a table with the results
        anticorrelated_pairs = table(unique_cluster_ids(col), unique_cluster_ids(row), correlations, ...
            'VariableNames', {'ClusterID_1', 'ClusterID_2', 'Correlation'});

        % Sort the table by the correlation value in ascending order
        anticorrelated_pairs = sortrows(anticorrelated_pairs, 'Correlation');
    end

    %% --- 7. Write Output File ---
    writetable(anticorrelated_pairs, output_csv_path);
    fprintf('Successfully generated anti-correlation report for %s.\n', job.unique_id);

    success = true; % Mark as successful

catch ME
    fprintf(2, 'ERROR generating anti-correlation report for %s:\n%s\n', ...
        job.unique_id, ME.message);
    success = false; % Ensure success is false in case of an error
end

end