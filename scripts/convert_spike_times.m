% This script converts spike times in session_data.mat files from samples to seconds.
% It prompts the user to select a directory, then recursively finds all
% session_data.mat files and performs the conversion.

function convert_spike_times()
    % Select the root directory
    data_dir = uigetdir('', 'Select the root data directory');
    if data_dir == 0
        disp('No directory selected. Exiting.');
        return;
    end

    % Find all session_data.mat files
    fprintf('Searching for session_data.mat files in %s...\n', data_dir);
    files = find_files(data_dir, 'session_data.mat');

    if isempty(files)
        fprintf('No session_data.mat files found in the selected directory.\n');
        return;
    end

    fprintf('Found %d session_data.mat files.\n', length(files));

    % Process each file
    for i = 1:length(files)
        file_path = files{i};
        fprintf('Processing %s...\n', file_path);

        try
            % Load the .mat file
            data = load(file_path);

            % Check if session_data.spikes.times exists
            if isfield(data, 'session_data') && isfield(data.session_data, 'spikes') && isfield(data.session_data.spikes, 'times')
                % Convert spike times from samples to seconds
                data.session_data.spikes.times = data.session_data.spikes.times / 30000;

                % Save the modified data back to the same file
                save(file_path, '-struct', 'data');
                fprintf('Successfully converted and saved %s\n', file_path);
            else
                fprintf('Warning: session_data.spikes.times not found in %s. Skipping.\n', file_path);
            end

        catch ME
            fprintf('Error processing file %s: %s\n', file_path, ME.message);
        end
    end

    disp('All files processed.');
end

function file_list = find_files(start_dir, pattern)
    dir_content = dir(start_dir);
    file_list = {};

    for i = 1:length(dir_content)
        item = dir_content(i);
        if item.isdir
            if ~strcmp(item.name, '.') && ~strcmp(item.name, '..')
                sub_dir_files = find_files(fullfile(start_dir, item.name), pattern);
                file_list = [file_list; sub_dir_files];
            end
        else
            if strcmp(item.name, pattern)
                file_list = [file_list; fullfile(start_dir, item.name)];
            end
        end
    end
end
