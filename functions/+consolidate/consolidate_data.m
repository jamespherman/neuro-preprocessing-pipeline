function success = consolidate_data(job, config)
    % CONSOLIDATE_DATA - Merges behavioral data, Kilosort output, and waveforms.
    %
    % This is the final step in the main data processing pipeline. It combines
    % the pre-processed behavioral data with the spike data from Kilosort and
    % the mean waveforms extracted by the `extract_waveforms` function.
    %
    % Inputs:
    %   job - A struct representing a single job from the manifest.
    %   config - A struct with global configuration.
    %
    % Outputs:
    %   success - A boolean flag indicating success or failure.

    success = false; % Default to failure

    try
        % Define the directory for this specific job's processed data.
        jobDataDir = fullfile(config.processedDataDir, job.unique_id);

        % Define paths for all input files.
        behavioralDataPath = fullfile(jobDataDir, ...
            [char(job.unique_id), '_intermediate_data.mat']);
        sessionDataPath = fullfile(jobDataDir, ...
            [char(job.unique_id), '_session_data.mat']);
        spike_times_path = fullfile(jobDataDir, 'spike_times.npy');
        spike_clusters_path = fullfile(jobDataDir, 'spike_clusters.npy');
        cluster_info_path = fullfile(jobDataDir, 'cluster_info.tsv');

        % --- Load all data sources ---

        % 1. Load intermediate behavioral data.
        if ~exist(behavioralDataPath, 'file')
            error('consolidate:DataNotFound', ...
                'Intermediate behavioral data file not found: %s', ...
                behavioralDataPath);
        end
        load(behavioralDataPath, ...
            'trialInfo', 'eventTimes', 'eventValuesTrials');

        % The previous function may have left figures open. Close them.
        try close all force;
        catch
        end

        % 2. Load Kilosort output.
        if ~exist(spike_times_path, 'file') || ...
           ~exist(spike_clusters_path, 'file') || ...
           ~exist(cluster_info_path, 'file')
            error('consolidate:KilosortOutputNotFound', ...
                'One or more Kilosort output files are missing in %s', ...
                jobDataDir);
        end
        spike_times = utils.readNPY(spike_times_path);
        spike_clusters = utils.readNPY(spike_clusters_path);
        cluster_info = tdfread(cluster_info_path);

        % 3. Load extracted waveforms from the existing session_data file.
        if ~exist(sessionDataPath, 'file')
            error('consolidate:SessionDataNotFound', ...
                'Session data file not found: %s', sessionDataPath);
        end
        % This file will be overwritten, so we must load its contents first.
        existing_data = load(sessionDataPath, 'session_data');
        wfMeans = existing_data.session_data.spikes.wfMeans;
        wfStds = existing_data.session_data.spikes.wfStds;

        % The previous function may have left figures open. Close them.
        try close all force;
        catch
        end

        % --- Consolidate data into a single struct ---

        session_data.trialInfo = trialInfo;
        session_data.eventTimes = eventTimes;
        session_data.eventValuesTrials = eventValuesTrials;

        session_data.spikes.times = spike_times;
        session_data.spikes.clusters = spike_clusters;
        session_data.spikes.cluster_info = cluster_info;

        % Assign the loaded waveforms.
        session_data.spikes.wfMeans = wfMeans;
        session_data.spikes.wfStds = wfStds;

        % Convert spike times from samples to seconds.
        fprintf('Converting spike times from samples to seconds...\n');
        session_data.spikes.times = double(session_data.spikes.times) / ...
            config.samplingRate;

        % --- Save the final consolidated data ---
        fprintf('Writing .mat file...\n');
        outputFilePath = fullfile(jobDataDir, ...
            [char(job.unique_id), '_session_data.mat']);
        save(outputFilePath, 'session_data', '-v7.3');

        fprintf('Successfully consolidated data for session %s\n', ...
            job.unique_id);
        success = true;

    catch ME
        fprintf(2, 'ERROR during data consolidation for %s:\n', ...
            job.unique_id);
        fprintf(2, '%s\n', ME.message);
        warning(['Execution paused in the debugger. Inspect variables', ...
            ' (ME, job, config) and type ''dbcont'' to continue or', ...
            ' ''dbquit'' to exit.']);
        keyboard; % Pause for debugging
    end
end
