function convert_spike_times_to_seconds()
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
        % Load the file
        loaded_data = load(session_data_path);
        
        % Check if the required fields exist
        if isfield(loaded_data, 'session_data') && ...
           isfield(loaded_data.session_data, 'spikes') && ...
           isfield(loaded_data.session_data.spikes, 'times')
            
            % Check if conversion is needed (e.g., max time > reasonable session length in sec)
            % This is a heuristic to avoid re-converting already converted files.
            % A session is unlikely to be > 100,000 seconds (27 hours).
            if max(loaded_data.session_data.spikes.times) < 100000
                 fprintf('  -> Spike times appear to be in seconds already. Skipping conversion.\n');
                 continue;
            end

            % Perform the conversion
            fprintf('  -> Converting spike times...');
            original_max_time = max(loaded_data.session_data.spikes.times);
            loaded_data.session_data.spikes.times = loaded_data.session_data.spikes.times / config.samplingRate;
            new_max_time = max(loaded_data.session_data.spikes.times);
            
            % Save the modified data back to the same file
            save(session_data_path, '-struct', 'loaded_data');
            
            fprintf(' Done. (e.g., max time changed from %.2f to %.2f)\n', original_max_time, new_max_time);
            conversion_count = conversion_count + 1;
        else
            fprintf('  -> session_data.spikes.times field not found. Skipping.\n');
        end
        
    catch ME
        fprintf(2, '  -> ERROR processing file %s: %s\n', session_data_path, ME.message);
    end
end

fprintf('\n--- Conversion Complete ---\n');
fprintf('Successfully converted %d files.\n', conversion_count);
fprintf('Skipped %d files (not found).\n', file_not_found_count);

end