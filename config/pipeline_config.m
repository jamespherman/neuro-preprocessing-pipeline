function config = pipeline_config()
    % pipeline_config Centralized configuration for the data processing pipeline.
    %
    %   Returns:
    %       config (struct): A struct containing all configuration parameters.

    % Get the project root directory
    projectRoot = utils.find_project_root();

    % Define directory paths
    config.rawNeuralDataDir = fullfile(projectRoot, 'Neuronal Data');
    config.behavioralDataDir = fullfile(projectRoot, 'Behavioral Data', 'PLDAPS_output', 'output');
    config.analysisOutputDir = fullfile(projectRoot, 'Neuronal Data Analysis');

    % Define other parameters
    config.samplingRate = 30000; % Sampling rate in Hz

end
