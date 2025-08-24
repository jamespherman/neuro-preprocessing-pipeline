function run_preprocessing()
%run_preprocessing - Main script for the neuro-preprocessing-pipeline.
%
% This script orchestrates the entire preprocessing workflow. It begins by
% setting up the environment, then loads the session manifest, and iterates
% through each job defined there. For this initial version, it simply
% displays the job's unique_id and status as a placeholder for real processing.
%
% The script depends on two utility functions:
%   - utils.find_project_root: to locate the project's base directory.
%   - utils.parse_manifest: to load and parse the jobs from the CSV manifest.

% Clear the workspace and command window, close all figures
clear; clc; close all;

%% --- Setup Paths ---
% This block ensures that the functions in the '/functions' directory are
% accessible to the script, regardless of where the project is located.

[script_path, ~, ~] = fileparts(mfilename('fullpath'));
repo_root = fileparts(script_path);
functions_path = fullfile(repo_root, 'functions');

addpath(functions_path);

disp('Added project functions to the MATLAB path.');

% --- End of Setup Paths ---

% Find the project root directory
project_root = utils.find_project_root;

% Construct the path to the sessions manifest file
manifest_path = fullfile(project_root, 'config', 'session_manifest.csv');

% Parse the manifest to get the list of jobs
jobs = utils.parse_manifest(manifest_path);

% Loop through each job in the manifest
for i = 1:height(jobs)
    % Get the current job (row)
    job = jobs(i, :);

    try
        % Check if the job status is 'raw'
        if strcmp(job.status, 'raw')
            fprintf('Processing job: %s\n', job.unique_id);

            % Run the preparation step
            success = prep.run_preparation(job, project_root);

            % If preparation was successful, update the status to 'prepared'
            if success
                utils.update_manifest_status(manifest_path, job.unique_id, 'prepared');
                fprintf('Successfully prepared job: %s\n', job.unique_id);
            else
                % The run_preparation function already prints an error, but let's
                % ensure the status is marked as 'error'.
                utils.update_manifest_status(manifest_path, job.unique_id, 'error');
                warning('Preparation failed for job: %s. See function output for details.', job.unique_id);
            end
        else
            % Optional: Display a message for jobs that are not 'raw'
            fprintf('Skipping job: %s, Status: %s\n', job.unique_id, job.status);
        end
    catch ME
        % If any unexpected error occurs, update the status to 'error'
        utils.update_manifest_status(manifest_path, job.unique_id, 'error');
        warning('An unexpected error occurred for job %s: %s', job.unique_id, ME.message);
        % Continue to the next job
    end
end

end