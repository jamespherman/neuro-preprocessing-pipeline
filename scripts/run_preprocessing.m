function run_preprocessing()
%run_preprocessing - Main script for the neuro-preprocessing-pipeline.
%
% This script orchestrates the entire preprocessing workflow. It loads the
% session manifest and processes each job based on its current status.

% Clear the workspace and command window, close all figures
clear; clc; close all;

%% --- Setup Paths ---
[script_path, ~, ~] = fileparts(mfilename('fullpath'));
repo_root = fileparts(script_path);
functions_path = fullfile(repo_root, 'functions');
config_path = fullfile(repo_root, 'config');

addpath(functions_path);
addpath(config_path);

disp('Added project functions & config directory to the MATLAB path.');

%% --- Load Config and Manifest ---
project_root = utils.find_project_root;
config = pipeline_config();
fprintf('All Processed Data To/From: %s\n', config.processedDataDir);
manifest_path = fullfile(project_root, 'config', 'session_manifest.csv');
jobs = utils.parse_manifest(manifest_path);

%% --- Process Jobs ---
for i = 1:height(jobs)
    job = jobs(i, :);
    fprintf('\n--- Checking job: %s ---\n', char(job.unique_id));

    % --- 1. Spike Data Preparation ---
    if strcmp(job.dat_status, "pending")
        try
            fprintf('Beginning spike data preparation...\n');
            success = prep.prepare_spikes_for_kilosort(job, config);
            if success
                utils.update_manifest_status(manifest_path, job.unique_id, 'complete', 'dat_status');
                job.dat_status = "complete"; % Update local job variable
                fprintf('Spike data preparation successful.\n');
            else
                utils.update_manifest_status(manifest_path, job.unique_id, 'error', 'dat_status');
            end
        catch ME
            utils.update_manifest_status(manifest_path, job.unique_id, 'error', 'dat_status');
            fprintf(2, 'ERROR during spike prep: %s\n', ME.message);
            keyboard;
        end
    end

    % --- 2. Behavioral Data Preparation ---
    if strcmp(job.behavior_status, "pending")
        try
            fprintf('Beginning behavioral data preparation...\n');
            success = prep.prepare_behavioral_data(job, config);
            if success
                utils.update_manifest_status(manifest_path, job.unique_id, 'complete', 'behavior_status');
                job.behavior_status = "complete"; % Update local job variable
                fprintf('Behavioral data preparation successful.\n');
            else
                utils.update_manifest_status(manifest_path, job.unique_id, 'error', 'behavior_status');
            end
        catch ME
            utils.update_manifest_status(manifest_path, job.unique_id, 'error', 'behavior_status');
            fprintf(2, 'ERROR during behavioral prep: %s\n', ME.message);
            keyboard;
        end
    end

    % --- 3. Automated Kilosort Status Check ---
    if strcmp(job.kilosort_status, "pending")
        kilosortJobDir = fullfile(config.processedDataDir, job.unique_id);
        kilosortCompletionFile = fullfile(kilosortJobDir, 'spike_times.npy');
        if isfile(kilosortCompletionFile)
            fprintf('Kilosort output detected.\n');
            utils.update_manifest_status(manifest_path, job.unique_id, 'complete', 'kilosort_status');
            job.kilosort_status = "complete"; % Update local job variable
        end
    end

    % --- 4. Data Consolidation ---
    % This step can only run if all prerequisite steps are complete.
    if strcmp(job.consolidation_status, "pending") && ...
       strcmp(job.dat_status, "complete") && ...
       strcmp(job.behavior_status, "complete") && ...
       strcmp(job.kilosort_status, "complete")
        try
            fprintf('Beginning data consolidation...\n');
            success = consolidate.consolidate_session(job, config);
            if success
                utils.update_manifest_status(manifest_path, job.unique_id, 'complete', 'consolidation_status');
                job.consolidation_status = "complete"; % Update local job variable
                fprintf('Data consolidation successful.\n');
            else
                utils.update_manifest_status(manifest_path, job.unique_id, 'error', 'consolidation_status');
            end
        catch ME
            utils.update_manifest_status(manifest_path, job.unique_id, 'error', 'consolidation_status');
            fprintf(2, 'ERROR during consolidation: %s\n', ME.message);
            keyboard;
        end
    end
end

disp('--- All jobs checked. ---');

end