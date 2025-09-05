function convert_spike_times()
%CONVERT_SPIKE_TIMES_TO_SECONDS Converts spike times from samples to seconds.
%
%   This script iterates through all sessions defined in the project's
%   manifest file. For each session, it locates the corresponding
%   _session_data.mat file, loads it, converts the spike times from
%   samples to seconds by dividing by the configured sampling rate,
%   and saves the file back to its original location.

% --- Setup Paths ---
[script_path, ~, ~] = fileparts(mfilename('fullpath'));
repo_root = fileparts(script_path);
addpath(fullfile(repo_root, 'functions'));
addpath(fullfile(repo_root, 'config'));
disp('Added project functions & config directory to the MATLAB path.');

% --- Load Config and Manifest ---
try
    config = pipeline_config();
    fprintf('Loaded pipeline configuration.\n');
    fprintf('Processed data is located in: %s\n', config.processedDataDir);
    
    manifest_path = fullfile(repo_root, 'config', 'session_manifest.csv');
    jobs = utils.parse_manifest(manifest_path);
    fprintf('Loaded and parsed session manifest with %d jobs.\n', height(jobs));
catch ME
    fprintf(2, 'Error during setup: %s\n', ME.message);
    fprintf(2, 'Please ensure you are running this script from within the project directory.\n');
    return;
end

% --- Process Each Session ---
fprintf('\n--- Starting Spike Time Conversion ---\n');
conversion_count = 0;
file_not_found_count = 0;

for i = 1:height(jobs)
    job = jobs(i, :);
    session_id = char(job.unique_id);
    
    fprintf('Processing session: %s\n', session_id);
    
    % Construct the path to the session_data.mat file
    session_data_filename = sprintf('%s_session_data.mat', session_id);
    session_data_path = fullfile(config.processedDataDir, session_id, session_data_filename);
    
    % Check if the file exists
    if ~isfile(session_data_path)
        fprintf('  -> File not found: %s. Skipping.\n', session_data_path);
        file_not_found_count = file_not_found_count + 1;
        continue;
    end
    
    try
        % Load the session_data.mat file
        loaded_data = load(session_data_path);
        
        % Define the path for spike_times.npy in the same directory
        [session_dir, ~, ~] = fileparts(session_data_path);
        spike_times_npy_path = fullfile(session_dir, 'spike_times.npy');

        % Check if spike_times.npy exists
        if ~isfile(spike_times_npy_path)
            fprintf('  -> spike_times.npy not found in %s. Skipping.\n', session_dir);
            continue;
        end

        % Check if the required fields exist in the loaded .mat file
        if isfield(loaded_data, 'session_data') && isfield(loaded_data.session_data, 'spikes')

            % Load spike times from .npy file
            fprintf('  -> Loading spike times from %s\n', spike_times_npy_path);
            spike_times_samples = utils.readNPY(spike_times_npy_path);
            
            % Convert spike times to seconds (and ensure double precision)
            fprintf('  -> Converting spike times to seconds...');
            spike_times_seconds = double(spike_times_samples) / config.samplingRate;

            % Ensure the 'times' field exists and is of type double before assigning
            if ~isfield(loaded_data.session_data.spikes, 'times')
                loaded_data.session_data.spikes.times = [];
            end

            % Assign the converted spike times
            loaded_data.session_data.spikes.times = spike_times_seconds;
            
            % Save the modified data back to the same file
            save(session_data_path, '-struct', 'loaded_data');
            
            fprintf(' Done. Stored %d spike times as double.\n', numel(spike_times_seconds));
            conversion_count = conversion_count + 1;
        else
            fprintf('  -> session_data.spikes field not found in %s. Skipping.\n', session_data_path);
        end
        
    catch ME
        keyboard
        fprintf(2, '  -> ERROR processing file %s: %s\n', session_data_path, ME.message);
    end
end

fprintf('\n--- Conversion Complete ---\n');
fprintf('Successfully converted %d files.\n', conversion_count);
fprintf('Skipped %d files (not found).\n', file_not_found_count);

end