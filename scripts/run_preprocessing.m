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
manifest_path = fullfile(project_root, 'config', 'session_manifest.csv');
jobs = utils.parse_manifest(manifest_path);

%% --- Process Jobs ---
for i = 1:height(jobs)
    job = jobs(i, :);
    fprintf('\n--- Checking job: %s (Status: %s) ---\n', char(job.unique_id), char(job.status));

    switch job.status
        case 'raw'
            % --- Data Preparation (Spikes and Behavior) ---
            try
                fprintf('Beginning data preparation for %s...\n', job.unique_id);

                % Run spike data preparation
                spike_success = prep.prepare_spikes_for_kilosort(job, config);

                % Run behavioral data preparation
                behavior_success = prep.prepare_behavioral_data(job, config);

                if spike_success && behavior_success
                    utils.update_manifest_status(manifest_path, job.unique_id, 'prepared');
                    fprintf('Data preparation successful for %s.\n', job.unique_id);
                else
                    utils.update_manifest_status(manifest_path, job.unique_id, 'error');
                    warning('Data preparation failed for %s.\n', job.unique_id);
                end
            catch ME
                utils.update_manifest_status(manifest_path, job.unique_id, 'error');
                warning('An error occurred during data preparation for %s: %s\n', job.unique_id, ME.message);
            end

        case 'prepared'
            % --- Automated Kilosort Status Check ---
            fprintf('Checking Kilosort status for %s...\n', job.unique_id);
            kilosortJobDir = fullfile(config.kilosortOutputDir, job.unique_id);
            kilosortCompletionFile = fullfile(kilosortJobDir, 'spike_times.npy');

            if exist(kilosortCompletionFile, 'file')
                utils.update_manifest_status(manifest_path, job.unique_id, 'sorted');
                fprintf('Kilosort processing automatically detected as complete for %s.\n', job.unique_id);
            else
                fprintf('Kilosort processing not yet complete for %s. This step must be run manually or by an external process.\n', job.unique_id);
            end

        case 'sorted'
            % --- Data Consolidation ---
            try
                fprintf('Beginning data consolidation for %s...\n', job.unique_id);
                success = consolidate.consolidate_session(job, config);
                if success
                    utils.update_manifest_status(manifest_path, job.unique_id, 'complete');
                    fprintf('Data consolidation successful for %s.\n', job.unique_id);
                else
                    utils.update_manifest_status(manifest_path, job.unique_id, 'error');
                    warning('Data consolidation failed for %s.\n', job.unique_id);
                end
            catch ME
                utils.update_manifest_status(manifest_path, job.unique_id, 'error');
                warning('An error occurred during data consolidation for %s: %s\n', job.unique_id, ME.message);
            end

        case 'complete'
            fprintf('Job %s is already complete.\n', job.unique_id);

        case 'error'
            fprintf('Job %s is in an error state. Manual intervention required.\n', job.unique_id);

        otherwise
            fprintf('Unknown status "%s" for job %s.\n', job.status, job.unique_id);
    end
end

disp('--- All jobs checked. ---');

end