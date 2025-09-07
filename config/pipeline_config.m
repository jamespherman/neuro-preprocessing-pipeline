function config = pipeline_config()
    % pipeline_config Centralized configuration for the data processing pipeline.
    %
    %   Returns:
    %       config (struct): A struct containing all configuration parameters.

    % Get the OneDrive 'root' directory. This is the parent folder for
    % multiple data directories, including the raw neuronal data,
    % behavioral data from PLDAPS, and the Kilosort output directories.
    oneDriveRoot = utils.findOneDrive();

    % Define directory paths.
    config.rawNeuralDataDir = fullfile(oneDriveRoot, 'Neuronal Data');
    config.behavioralDataDir = fullfile(oneDriveRoot, 'Behavioral Data', ...
        'PLDAPS_output', 'output');

    % Define a single parent directory for all processed data.
    config.processedDataDir = fullfile(oneDriveRoot, ...
        'Neuronal Data Analysis');

    % Other Parameters
    config.samplingRate = 30000; % Sampling rate in Hz.
    config.n_channels_in_dat = 32; % Number of channels in the .dat file.
    % Window size for waveform extraction.
    config.waveform_window_size = [-40, 41];
end
