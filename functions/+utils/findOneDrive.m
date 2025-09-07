function pathOut = findOneDrive()
% FINDONEDRIVE Attempts to find the local path to the user's OneDrive directory.
%
% This function is designed to be cross-platform, with specific logic for
% Windows, macOS, and Linux. It is essential for locating the root data
% directory for the pipeline.

pathOut = '';

% Check if we're on a Windows system.
if ispc
    % On Windows, OneDrive paths are typically stored in environment variables.
    % We use PowerShell to query them.

    % First, try to get the path for OneDrive for Business.
    [status, result] = system(['powershell -command ', ...
        '"$env:OneDriveCommercial"']);
    if status == 0 && ~isempty(strtrim(result))
        pathOut = strtrim(result);
        return;
    end

    % If that fails, try to get the path for personal OneDrive.
    [status, result] = system('powershell -command "$env:OneDrive"');
    if status == 0 && ~isempty(strtrim(result))
        pathOut = strtrim(result);
        return;
    end
else
    % On macOS and Linux, OneDrive is typically in the user's home directory.
    homeDir = getenv('HOME');

    % List all visible items in the home directory.
    homeDirList = list_visible_items(homeDir);

    % Find items that contain "OneDrive" in their name.
    oneDriveMatches = homeDirList(contains(homeDirList, 'OneDrive'));

    if numel(oneDriveMatches) == 1
        % If exactly one match is found, use it.
        pathOut = fullfile(homeDir, oneDriveMatches{1});
    elseif numel(oneDriveMatches) > 1
        % If multiple matches are found, it's ambiguous.
        warning('findOneDrive:MultipleFound', ...
            'Multiple OneDrive directories found. Using the first one.');
        pathOut = fullfile(homeDir, oneDriveMatches{1});
    else
        % If no matches are found, throw an error.
        error('findOneDrive:NotFound', ...
            'Could not automatically find a OneDrive directory.');
    end
end

if isempty(pathOut)
    error('findOneDrive:Failed', 'Failed to find any OneDrive path.');
end

end

function itemList = list_visible_items(folderPath)
% LIST_VISIBLE_ITEMS Lists all non-hidden files and directories.
%
% This is a helper function that uses 'dir' to get the contents of a
% folder and then filters out any items that start with a '.', which are
% typically hidden files or system directories (e.g., '.', '..').

% Use dir to get the full listing.
all_items = dir(folderPath);

% Filter out any names that start with a '.'
is_hidden = startsWith({all_items.name}, '.');
itemList = {all_items(~is_hidden).name};
end