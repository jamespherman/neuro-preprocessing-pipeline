function success = consolidate_session(job, config)
    % CONSOLIDATE_SESSION - Merges behavioral data with Kilosort output.
    %
    % Inputs:
    %   job - A struct representing a single job from the manifest.
    %   config - A struct with global configuration.
    %
    % Outputs:
    %   success - A boolean flag indicating success or failure.

    success = false; % Default to failure

    try
        % Construct paths
        kilosortDir = fullfile(config.kilosortOutputDir, job.unique_id);
        behavioralDataPath = fullfile(config.intermediateDir, [job.unique_id '_intermediate_data.mat']);
        outputDir = config.analysisOutputDir;

        % Create output directory if it doesn't exist
        if ~exist(outputDir, 'dir')
            mkdir(outputDir);
        end

        % Load intermediate behavioral data
        if ~exist(behavioralDataPath, 'file')
            error('Intermediate behavioral data file not found: %s', behavioralDataPath);
        end
        load(behavioralDataPath, 'trialInfo', 'eventTimes');

        % Load Kilosort output files
        spike_times_path = fullfile(kilosortDir, 'spike_times.npy');
        spike_clusters_path = fullfile(kilosortDir, 'spike_clusters.npy');
        cluster_info_path = fullfile(kilosortDir, 'cluster_info.tsv');

        if ~exist(spike_times_path, 'file') || ~exist(spike_clusters_path, 'file') || ~exist(cluster_info_path, 'file')
            error('One or more Kilosort output files are missing in %s', kilosortDir);
        end

        spike_times = utils.readNPY(spike_times_path);
        spike_clusters = utils.readNPY(spike_clusters_path);
        cluster_info = tdfread(cluster_info_path); % Using tdfread for .tsv file

        % Merge data
        session_data.trialInfo = trialInfo;
        session_data.eventTimes = eventTimes;
        session_data.spikes.times = spike_times;
        session_data.spikes.clusters = spike_clusters;
        session_data.spikes.cluster_info = cluster_info;

        % Save the final merged data
        outputFilePath = fullfile(outputDir, [job.unique_id '_session_data.mat']);
        save(outputFilePath, 'session_data');

        fprintf('Successfully consolidated data for session %s\n', job.unique_id);
        success = true;

    catch ME
        fprintf('Error consolidating data for session %s: %s\n', job.unique_id, ME.message);
    end
end
