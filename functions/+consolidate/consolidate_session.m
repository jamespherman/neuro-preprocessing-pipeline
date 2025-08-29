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
        jobDataDir = fullfile(config.processedDataDir, job.unique_id);
        kilosortDir = jobDataDir;
        behavioralDataPath = jobDataDir + string(filesep) + ...
            job.unique_id + "_intermediate_data.mat";
        outputDir = jobDataDir;

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

        % --- Mean Waveform Extraction ---
        fprintf('Extracting mean waveforms for %s...\n', job.unique_id);

        % Path to high-pass filtered data
        datFilePath = fullfile(kilosortDir, job.unique_id + ".dat");
        if ~exist(datFilePath, 'file')
            error('consolidate:consolidate_session:datNotFound', ...
                  '.dat file not found: %s', datFilePath);
        end

        % Load raw data
        fid = fopen(datFilePath, 'r');
        rawData = fread(fid, Inf, 'int16');
        fclose(fid);
        rawData = reshape(rawData, config.n_channels_in_dat, []);

        % Get unique cluster IDs
        uClusterIDs = unique(session_data.spikes.clusters);
        nClusterIDs = length(uClusterIDs);

        % Define data holders
        wfMeans = cell(nClusterIDs, 1);
        wfStds = cell(nClusterIDs, 1);

        waveform_window = config.waveform_window_size(1):config.waveform_window_size(2);
        waveform_length = length(waveform_window);

        for i = 1:nClusterIDs
            cluster_id = uClusterIDs(i);
            spikes_in_cluster = session_data.spikes.times(session_data.spikes.clusters == cluster_id);
            nSpikes = length(spikes_in_cluster);


            waveforms = zeros(config.n_channels_in_dat, waveform_length, nSpikes);

            for j = 1:nSpikes
                spike_time = spikes_in_cluster(j);
                start_idx = spike_time + config.waveform_window_size(1);
                end_idx = spike_time + config.waveform_window_size(2);

                if start_idx > 0 && end_idx <= size(rawData, 2)
                    waveforms(:,:,j) = rawData(:, start_idx:end_idx);
                else
                    % Handle spikes near the beginning or end of the recording
                    valid_indices = max(1, start_idx):min(size(rawData, 2), end_idx);
                    data_snippet = rawData(:, valid_indices);

                    temp_waveform = zeros(config.n_channels_in_dat, waveform_length);

                    % Calculate where to place the snippet in the temporary waveform
                    target_start = find(waveform_window == (valid_indices(1) - spike_time));
                    target_end = target_start + length(valid_indices) - 1;

                    if ~isempty(target_start) && target_end <= waveform_length
                         temp_waveform(:, target_start:target_end) = data_snippet;
                    end
                    waveforms(:,:,j) = temp_waveform;
                end
            end

            wfMeans{i} = squeeze(mean(waveforms, 3));
            wfStds{i} = squeeze(std(waveforms, [], 3));
            fprintf('  Cluster %d/%d: Extracted %d waveforms.\n', i, nClusterIDs, nSpikes);
        end

        session_data.spikes.wfMeans = wfMeans;
        session_data.spikes.wfStds = wfStds;

        fprintf('Finished extracting waveforms for %s.\n', job.unique_id);
        % --- End Mean Waveform Extraction ---

        % Save the final merged data
        outputFilePath = fullfile(outputDir, job.unique_id + "_session_data.mat");
        save(outputFilePath, 'session_data');

        fprintf('Successfully consolidated data for session %s\n', job.unique_id);
        success = true;

    catch ME
    fprintf(2, 'ERROR during data consolidation for %s:\n', job.unique_id); % Print error in red
    fprintf(2, '%s\n', ME.message);
    warning('Execution paused in the debugger. Inspect variables (ME, job, config) and type ''dbcont'' to continue to the next job or ''dbquit'' to exit.');
    keyboard; % Pause execution for debugging
    end
end
