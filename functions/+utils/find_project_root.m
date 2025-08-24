function project_root = find_project_root()
    % find_project_root - Finds the project's root directory.
    %
    % The project root is identified by the presence of the '.git' directory.
    % This function starts its search from the directory where this script is located
    % and moves up the directory tree until it finds the '.git' directory.

    % Start from the directory of the currently executing file
    current_dir = fileparts(mfilename('fullpath'));

    % Loop until the root of the filesystem is reached
    while ~isempty(current_dir)
        % Check if the .git directory exists in the current directory
        if isfolder(fullfile(current_dir, '.git'))
            project_root = current_dir;
            return;
        end

        % Move up one level
        parent_dir = fileparts(current_dir);

        % If parent_dir is the same as current_dir, we've reached the root
        if strcmp(parent_dir, current_dir)
            break;
        end

        current_dir = parent_dir;
    end

    % If the loop completes without finding .git, throw an error
    error('Project root with .git directory not found.');
end
