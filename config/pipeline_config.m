function config = pipeline_config()
    % pipeline_config Centralized configuration for the data processing pipeline.
    %
    %   Returns:
    %       config (struct): A struct containing all configuration parameters.

    % Get the OneDrive 'root' directory in which we expect to find the raw
    % neuronal data directory, the nested behavioral output from PLDAPS
    % directory, and the place we'll create a directory to store the .DAT
    % file and other Kilosort output for each session's data.
    oneDriveRoot = utils.findOneDrive();

    % Define directory paths
    config.rawNeuralDataDir = fullfile(oneDriveRoot, 'Neuronal Data');
    config.behavioralDataDir = fullfile(oneDriveRoot, 'Behavioral Data', ...
        'PLDAPS_output', 'output');
    % Define a SINGLE parent directory for ALL processed data.
    config.processedDataDir = fullfile(oneDriveRoot, 'Neuronal Data Analysis');

    % Other Parameters
    config.samplingRate = 30000; % Sampling rate in Hz
    config.n_channels_in_dat = 32; % Number of channels in the .dat file
    config.waveform_window_size = [-40, 41]; % Window size for waveform extraction
end
