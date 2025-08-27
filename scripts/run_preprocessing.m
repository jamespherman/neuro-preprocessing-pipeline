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
config_path = fullfile(repo_root, 'config');

addpath(functions_path);
addpath(config_path);

disp('Added project functions & config directory to the MATLAB path.');

% --- End of Setup Paths ---

% Find the project root directory
project_root = utils.find_project_root;

% Load the pipeline configuration
config = pipeline_config();

% Construct the path to the sessions manifest file
manifest_path = fullfile(project_root, 'config', 'session_manifest.csv');

% Parse the manifest to get the list of jobs
jobs = utils.parse_manifest(manifest_path);

% Loop through each job in the manifest
for i = 1:height(jobs)
    % Get the current job (row)
    job = jobs(i, :);
    fprintf('Checking job: %s\n', char(job.unique_id));

    % --- Spike Data Preparation ---
    if strcmp(job.dat_status, 'pending')
        try
            fprintf('Beginning spike data preparation for %s...\n', job.unique_id);
            success = prep.prepare_spikes_for_kilosort(job, config.rawNeuralDataDir, config.kilosortOutputDir);
            if success
                utils.update_manifest_status(manifest_path, job.unique_id, 'complete', 'dat_status');
                fprintf('Spike data preparation successful for %s.\n', job.unique_id);
            else
                utils.update_manifest_status(manifest_path, job.unique_id, 'error', 'dat_status');
                warning('Spike data preparation failed for %s.\n', job.unique_id);
            end
        catch ME
            utils.update_manifest_status(manifest_path, job.unique_id, 'error', 'dat_status');
            warning('An error occurred during spike data preparation for %s: %s\n', job.unique_id, ME.message);
        end
    else
        fprintf('Spike data preparation already completed or not pending for %s.\n', job.unique_id);
    end

    % --- Behavioral Data Preparation ---
    if strcmp(job.behavior_status, 'pending')
        try
            fprintf('Beginning behavioral data preparation for %s...\n', job.unique_id);
            success = prep.prepare_behavioral_data(job, config.rawNeuralDataDir, config.kilosortOutputDir);
            if success
                utils.update_manifest_status(manifest_path, job.unique_id, 'complete', 'behavior_status');
                fprintf('Behavioral data preparation successful for %s.\n', job.unique_id);
            else
                utils.update_manifest_status(manifest_path, job.unique_id, 'error', 'behavior_status');
                warning('Behavioral data preparation failed for %s.\n', job.unique_id);
            end
        catch ME
            utils.update_manifest_status(manifest_path, job.unique_id, 'error', 'behavior_status');
            warning('An error occurred during behavioral data preparation for %s: %s\n', job.unique_id, ME.message);
        end
    else
        fprintf('Behavioral data preparation already completed or not pending for %s.\n', job.unique_id);
    end

    % --- Automated Kilosort Status Check ---
    if strcmp(job.kilosort_status, 'pending')
        fprintf('Checking Kilosort status for %s...\n', job.unique_id);
        kilosortJobDir = fullfile(config.kilosortOutputDir, job.unique_id);
        kilosortCompletionFile = fullfile(kilosortJobDir, 'spike_times.npy');

        if exist(kilosortCompletionFile, 'file')
            utils.update_manifest_status(manifest_path, job.unique_id, 'complete', 'kilosort_status');
            fprintf('Kilosort processing automatically detected as complete for %s.\n', job.unique_id);
        else
            fprintf('Kilosort processing not yet complete for %s.\n', job.unique_id);
        end
    else
        fprintf('Kilosort processing already marked as complete for %s.\n', job.unique_id);
    end

    % --- Data Consolidation ---
    if strcmp(job.consolidation_status, 'pending') && strcmp(job.kilosort_status, 'complete')
        try
            fprintf('Beginning data consolidation for %s...\n', job.unique_id);
            success = consolidate.consolidate_data(job, config);
            if success
                utils.update_manifest_status(manifest_path, job.unique_id, 'complete', 'consolidation_status');
                fprintf('Data consolidation successful for %s.\n', job.unique_id);
            else
                utils.update_manifest_status(manifest_path, job.unique_id, 'error', 'consolidation_status');
                warning('Data consolidation failed for %s.\n', job.unique_id);
            end
        catch ME
            utils.update_manifest_status(manifest_path, job.unique_id, 'error', 'consolidation_status');
            warning('An error occurred during data consolidation for %s: %s\n', job.unique_id, ME.message);
        end
    else
        fprintf('Data consolidation already completed or not pending for %s.\n', job.unique_id);
    end
end

end