function update_manifest_status(manifestPath, unique_id, newStatus)
% UPDATE_MANIFEST_STATUS - Finds a job by its unique_id and updates its status.
%
% This function programmatically and safely updates the status of a single
% job entry in the specified sessions_manifest.csv file. It is designed to
% be called by automated scripts after a processing stage is completed or fails.
%
% Inputs:
%   manifestPath (string) - The full file path to the sessions_manifest.csv file.
%   unique_id    (string) - The ID of the job/row to update.
%   newStatus    (string) - The new status to write for the job (e.g.,
%                           'prepared', 'complete', 'error').
%
% Requirements:
% - The manifest file must be a valid CSV.
% - The file must contain 'unique_id' and 'status' columns.
%
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    % --- 1. Load the Manifest File ---
    % Use a try-catch block for robust file reading.
    try
        % Read the entire CSV file into a table, treating text as strings.
        % This is consistent with parse_manifest.
        opts = detectImportOptions(manifestPath);
        % Ensure all text-based columns are read as string
        opts.TextType = "string";
        manifestTable = readtable(manifestPath, opts);
    catch ME
        % If readtable fails, throw an error with details.
        error('update_manifest_status:ReadError', ...
              'Failed to read the manifest file at:\n%s\nDetails: %s', manifestPath, ME.message);
    end

    % --- 2. Find the Row by Unique ID ---
    % Find the row index matching the unique_id.
    % Direct comparison `==` is used for string arrays.
    rowIndex = find(manifestTable.unique_id == unique_id);

    % --- 3. Update the Status ---
    if isempty(rowIndex)
        % If unique_id is not found, display a warning and do not proceed.
        warning('update_manifest_status:IDNotFound', ...
                'The unique_id "%s" was not found in the manifest. No update will be performed.', char(unique_id));
        return; % Exit the function

    elseif numel(rowIndex) > 1
        % If multiple rows have the same unique_id, this is a critical data integrity issue.
        warning('update_manifest_status:DuplicateID', ...
                'Found multiple rows with the unique_id "%s". Updating all found entries.', char(unique_id));
    end

    % Update the 'status' column for the found row(s).
    % newStatus is a string or char, which can be directly assigned.
    manifestTable.status(rowIndex) = string(newStatus);

    % --- 4. Write the Updated Table Back to File ---
    % Write the entire modified table back to the original file path.
    % This is a safe way to ensure the file is correctly formatted and overwritten.
    try
        writetable(manifestTable, manifestPath);
    catch ME
        % If writing fails, throw an error.
        error('update_manifest_status:WriteError', ...
              'Failed to write the updated manifest to file:\n%s\nDetails: %s', manifestPath, ME.message);
    end

end
