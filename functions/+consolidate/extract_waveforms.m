function success = extract_waveforms(job, config)
    % EXTRACT_WAVEFORMS - Extracts mean spike waveforms from the .dat file.
    %
    % This function is a specialized part of the consolidation process, focused
    % solely on extracting mean spike waveforms. It reads Kilosort's output
    % and the high-pass filtered .dat file to compute these waveforms, saving
    % them to an intermediate file.
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

        % --- Mean Waveform Extraction ---
        fprintf('Extracting mean waveforms for %s...\n', job.unique_id);

        % Path to high-pass filtered data.
        datFilePath = fullfile(jobDataDir, [job.raw_filename_base, '.dat']);
        if ~exist(datFilePath, 'file')
            error('consolidate:extract_waveforms:datNotFound', ...
                  '.dat file not found: %s', datFilePath);
        end

        % Load Kilosort output files for spike times and clusters.
        spike_times_path = fullfile(jobDataDir, 'spike_times.npy');
        spike_clusters_path = fullfile(jobDataDir, 'spike_clusters.npy');

        if ~exist(spike_times_path, 'file') || ...
           ~exist(spike_clusters_path, 'file')
            error(['Kilosort output files (spike_times.npy or ', ...
                'spike_clusters.npy) are missing in %s'], jobDataDir);
        end

        spike_times = utils.readNPY(spike_times_path);
        spike_clusters = utils.readNPY(spike_clusters_path);

        % Load raw data from .dat file.
        fid = fopen(datFilePath, 'r');
        rawData = fread(fid, Inf, 'int16');
        fclose(fid);

        % The number of channels is loaded from the Kilosort parameters,
        % which are stored in a .py file. This is not ideal, but it works.
        % A more robust solution would be to save this parameter in a
        % more accessible format.
        try
            load(fullfile(jobDataDir, 'params.py'), 'n_channels_dat');
            n_channels = n_channels_dat;
        catch
            % As a fallback, use the value from the main config file.
            n_channels = config.n_channels_in_dat;
        end
        rawData = reshape(rawData, n_channels, []);

        % Get unique cluster IDs.
        uClusterIDs = unique(spike_clusters);
        nClusterIDs = length(uClusterIDs);

        % Define data holders.
        wfMeans = cell(nClusterIDs, 1);
        wfStds = cell(nClusterIDs, 1);

        waveform_window = config.waveform_window_size(1):...
            config.waveform_window_size(2);
        waveform_length = length(waveform_window);

        for i = 1:nClusterIDs
            cluster_id = uClusterIDs(i);
            spikes_in_cluster = spike_times(spike_clusters == cluster_id);
            nSpikes = length(spikes_in_cluster);

            waveforms = zeros(n_channels, waveform_length, nSpikes);

            for j = 1:nSpikes
                spike_time = spikes_in_cluster(j);
                start_idx = spike_time + config.waveform_window_size(1);
                end_idx = spike_time + config.waveform_window_size(2);

                if start_idx > 0 && end_idx <= size(rawData, 2)
                    % The entire window is within the data bounds.
                    waveforms(:,:,j) = rawData(:, start_idx:end_idx);
                else
                    % Handle edge cases where the window is out of bounds.
                    % Find the valid indices within the raw data.
                    valid_indices = max(1, start_idx):...
                        min(size(rawData, 2), end_idx);
                    data_snippet = rawData(:, valid_indices);

                    % Create a temporary zero-padded waveform.
                    temp_waveform = zeros(n_channels, waveform_length);

                    % Calculate where the snippet should go in the window.
                    target_start = find(waveform_window == ...
                        (valid_indices(1) - spike_time));
                    target_end = target_start + length(valid_indices) - 1;

                    if ~isempty(target_start) && ...
                        target_end <= waveform_length
                         temp_waveform(:, target_start:target_end) = ...
                             data_snippet;
                    end
                    waveforms(:,:,j) = temp_waveform;
                end
            end

            wfMeans{i} = squeeze(mean(waveforms, 3));
            wfStds{i} = squeeze(std(waveforms, [], 3));
            fprintf('  Cluster %d/%d: Extracted %d waveforms.\n', ...
                i, nClusterIDs, nSpikes);
        end

        % Create a session_data struct and save the waveforms. This file
        % will be loaded and appended to by `consolidate_data`.
        session_data.spikes.wfMeans = wfMeans;
        session_data.spikes.wfStds = wfStds;

        outputFilePath = fullfile(jobDataDir, ...
            [job.unique_id, '_session_data.mat']);
        save(outputFilePath, 'session_data');

        fprintf('Finished extracting waveforms for %s. Saved to %s\n', ...
            job.unique_id, outputFilePath);
        success = true;

    catch ME
        fprintf(2, 'ERROR during waveform extraction for %s:\n', ...
            job.unique_id);
        fprintf(2, '%s\n', ME.message);
        warning(['Execution paused in the debugger. Inspect variables', ...
            ' (ME, job, config) and type ''dbcont'' to continue or', ...
            ' ''dbquit'' to exit.']);
        keyboard; % Pause for debugging
    end
end
