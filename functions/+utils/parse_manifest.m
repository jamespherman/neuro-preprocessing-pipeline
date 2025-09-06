function sessionTable = parse_manifest(manifestPath)
% PARSE_MANIFEST - Loads and validates the sessions_manifest.csv file.
%
% This function reads the project's session manifest CSV file into a MATLAB
% table and performs essential validation to ensure its integrity.
%
% Inputs:
%   manifestPath (string) - The full file path to the sessions_manifest.csv file.
%
% Outputs:
%   sessionTable (table) - A MATLAB table containing the validated manifest data.
%
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    % Check if the manifest file exists
    if ~isfile(manifestPath)
        error('parse_manifest:FileNotFound', 'The manifest file was not found at the specified path:\n%s', manifestPath);
    end

    % Use a try-catch block for robust file reading
    try
        % Read the CSV file into a table
        sessionTable = readtable(manifestPath, 'FileType', 'text', 'Delimiter', ',', 'TextType', 'string');
    catch ME
        % If readtable fails, throw a more informative error
        error('parse_manifest:ReadError', 'Failed to read the manifest file. Please ensure it is a valid CSV file.\nDetails: %s', ME.message);
    end

    % --- Validation Checks ---

    % 1. Check for the presence of all required columns
    requiredColumns = {
        'unique_id', 'session_group_id', 'monkey', 'date', ...
        'experiment_pc_name', 'probe_type', 'brain_area', ...
        'channel_numbers', 'channel_ordering', 'raw_filename_base', ...
        'dat_status', 'behavior_status', 'kilosort_status', 'waveform_status', ...
        'consolidation_status', 'notes'
    };

    for i = 1:length(requiredColumns)
        if ~ismember(requiredColumns{i}, sessionTable.Properties.VariableNames)
            error('parse_manifest:MissingColumn', 'The manifest file is missing the required column: "%s".', requiredColumns{i});
        end
    end

    % 2. Validate status columns without converting to categorical
    statusColumns = {'dat_status', 'behavior_status', 'kilosort_status', 'waveform_status', 'consolidation_status'};
    allowedStatuses = {'pending', 'complete', 'error'};

    for i = 1:length(statusColumns)
        colName = statusColumns{i};
        invalidEntries = ~ismember(sessionTable.(colName), allowedStatuses);
        if any(invalidEntries)
            error('parse_manifest:InvalidStatusValue', ...
                'The "%s" column contains invalid values: %s. Only the following are allowed: %s.', ...
                colName, strjoin(unique(sessionTable.(colName)(invalidEntries)), ', '), strjoin(allowedStatuses, ', '));
        end
    end

    % --- End of Validation ---

    % --- End of Validation ---

    % If all checks pass, return the validated table
end
