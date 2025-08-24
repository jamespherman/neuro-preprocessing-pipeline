function rootPath = find_project_root()
    % FIND_PROJECT_ROOT Searches for the project's root directory.
    %   This function traverses up the directory tree from the currently executing
    %   script's path to find a directory named 'OneDrive - University of Pittsburgh'.
    %
    %   Outputs:
    %       rootPath (string): The absolute path to the project root directory.
    %
    %   Throws:
    %       error: If the project root directory is not found.

    % Define the name of the directory to search for.
    targetDirName = 'OneDrive - University of Pittsburgh';

    % Get the full path of the currently running file.
    % This ensures the search starts from the location of the script that calls this function.
    currentFilePath = mfilename('fullpath');

    % Start searching from the directory containing this file.
    currentDir = fileparts(currentFilePath);

    % Loop until the root of the filesystem is reached.
    while true
        % Construct the potential path to the target directory
        potentialPath = fullfile(currentDir, targetDirName);

        % Check if a directory with the target name exists at the current level.
        if isfolder(potentialPath)
            % If found, we have our root path.
            rootPath = potentialPath;
            return;
        end

        % Move up to the parent directory for the next iteration.
        parentDir = fileparts(currentDir);

        % If the parent directory is the same as the current directory, we have
        % reached the root of the filesystem (e.g., 'C:\' or '/').
        if strcmp(currentDir, parentDir)
            break; % Exit the loop if we've reached the top.
        end

        currentDir = parentDir;
    end

    % If the loop completes without finding the directory, it means the target
    % was not found in any parent path. Throw an informative error.
    error('Could not find the project root directory: ''%s''', targetDirName);

end
