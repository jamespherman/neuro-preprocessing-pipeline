function update_manifest_status(manifestPath, unique_id, newStatus, statusColumn)
% UPDATE_MANIFEST_STATUS - Finds a job by its unique_id and updates its status
% in a specified column.
%
% This function programmatically and safely updates a specified status column
% for a single job entry in the given manifest file. It is designed for use in
% automated scripts where a job's state needs to be tracked.
%
% Inputs:
%   manifestPath (string) - The full file path to the manifest CSV file.
%   unique_id    (string) - The ID of the job/row to update.
%   newStatus    (string) - The new status to write for the job.
%   statusColumn (string) - The name of the column to update with the new status.
%
% Requirements:
% - The manifest file must be a valid CSV.
% - The file must contain a 'unique_id' column and the specified 'statusColumn'.
%
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    % --- 1. Load the Manifest File ---
    % Use a try-catch block for robust file reading.
    try
        % Read the entire CSV file into a table, treating all text-based
        % columns as strings. This is consistent with parse_manifest and
        % helps prevent data-type-related errors on read.
        opts = detectImportOptions(manifestPath);
        % Set all variable types to 'string' to avoid MATLAB's type detection
        % from causing issues. This provides consistency across different
        % environments and MATLAB versions.
        opts.VariableTypes = repmat({'string'}, 1, length(opts.VariableNames));
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

    % Update the specified status column for the found row(s).
    manifestTable.(statusColumn)(rowIndex) = string(newStatus);

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
