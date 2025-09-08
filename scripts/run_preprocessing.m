function run_preprocessing()
% RUN_PREPROCESSING Main script for the neuro-preprocessing-pipeline.
%
% This script orchestrates the entire preprocessing workflow. It loads the
% session manifest and, for each job, sequentially runs the required
% preprocessing steps. It checks the status of each step and will only
% proceed if the prerequisite steps are marked as 'complete'.

% Clear the workspace and command window, close all figures.
clear; clc; close all;

%% --- Setup Paths ---
% Find the project root by looking for the .git directory and add necessary
% subdirectories to the MATLAB path.
try
    currDir = pwd;
    cd ..
    repo_root = pwd;
    cd(currDir);
    clear currDir;
    addpath(fullfile(repo_root, 'functions'));
    addpath(fullfile(repo_root, 'config'));
    disp('Added project functions & config directory to the MATLAB path.');
catch ME
    error('run_preprocessing:PathError', ...
        ['Could not find project root or set paths. Ensure that ', ...
         'the script is run from within the project directory and that ', ...
         'the ''+utils'' package is accessible. Details: %s'], ME.message);
end

%% --- Load Config and Manifest ---
config = pipeline_config();
fprintf('Processed data directory: %s\n', config.processedDataDir);
manifest_path = fullfile(repo_root, 'config', 'session_manifest.csv');
jobs = utils.parse_manifest(manifest_path);
fprintf('Loaded manifest with %d jobs.\n', height(jobs));

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
                utils.update_manifest_status(manifest_path, ...
                    job.unique_id, 'complete', 'dat_status');
                job.dat_status = "complete"; % Update local job for subsequent steps
                fprintf('Spike data preparation successful.\n');
            else
                utils.update_manifest_status(manifest_path, ...
                    job.unique_id, 'error', 'dat_status');
            end
        catch ME
            utils.update_manifest_status(manifest_path, job.unique_id, ...
                'error', 'dat_status');
            fprintf(2, 'ERROR during spike prep for %s:\n%s\n', ...
                job.unique_id, ME.message);
        end
    end

    % --- 2. Behavioral Data Preparation ---
    if strcmp(job.behavior_status, "pending")
        try
            fprintf('Beginning behavioral data preparation...\n');
            success = prep.prepare_behavioral_data(job, config);
            if success
                utils.update_manifest_status(manifest_path, ...
                    job.unique_id, 'complete', 'behavior_status');
                job.behavior_status = "complete";
                fprintf('Behavioral data preparation successful.\n');
            else
                utils.update_manifest_status(manifest_path, ...
                    job.unique_id, 'error', 'behavior_status');
            end
        catch ME
            utils.update_manifest_status(manifest_path, job.unique_id, ...
                'error', 'behavior_status');
            fprintf(2, 'ERROR during behavioral prep for %s:\n%s\n', ...
                job.unique_id, ME.message);
        end
    end

    % --- 3. Automated Kilosort Status Check ---
    % This is a passive check. It looks for Kilosort's output files to
    % determine if the manual sorting step has been completed.
    if strcmp(job.kilosort_status, "pending")
        kilosortJobDir = fullfile(config.processedDataDir, job.unique_id);
        kilosortCompletionFile = fullfile(kilosortJobDir, 'spike_times.npy');
        if isfile(kilosortCompletionFile)
            fprintf('Kilosort output detected. Updating status.\n');
            utils.update_manifest_status(manifest_path, ...
                job.unique_id, 'complete', 'kilosort_status');
            job.kilosort_status = "complete";
        end
    end

    % --- 4. Waveform Extraction ---
    if strcmp(job.waveform_status, "pending") && ...
       strcmp(job.dat_status, "complete") && ...
       strcmp(job.behavior_status, "complete") && ...
       strcmp(job.kilosort_status, "complete")
        try
            fprintf('Beginning waveform extraction...\n');
            success = consolidate.extract_waveforms(job, config);
            if success
                utils.update_manifest_status(manifest_path, ...
                    job.unique_id, 'complete', 'waveform_status');
                job.waveform_status = "complete";
                fprintf('Waveform extraction successful.\n');
            else
                utils.update_manifest_status(manifest_path, ...
                    job.unique_id, 'error', 'waveform_status');
            end
        catch ME
            utils.update_manifest_status(manifest_path, job.unique_id, ...
                'error', 'waveform_status');
            fprintf(2, 'ERROR during waveform extraction for %s:\n%s\n', ...
                job.unique_id, ME.message);
        end
    end

    % --- 5. Data Consolidation ---
    if strcmp(job.consolidation_status, "pending") && ...
       strcmp(job.dat_status, "complete") && ...
       strcmp(job.behavior_status, "complete") && ...
       strcmp(job.kilosort_status, "complete") && ...
       strcmp(job.waveform_status, "complete")
        try
            fprintf('Beginning final data consolidation...\n');
            success = consolidate.consolidate_data(job, config);
            if success
                utils.update_manifest_status(manifest_path, ...
                    job.unique_id, 'complete', 'consolidation_status');
                job.consolidation_status = "complete";
                fprintf('Data consolidation successful.\n');
            else
                utils.update_manifest_status(manifest_path, ...
                    job.unique_id, 'error', 'consolidation_status');
            end
        catch ME
            utils.update_manifest_status(manifest_path, ...
                job.unique_id, 'error', 'consolidation_status');
            fprintf(2, 'ERROR during data consolidation for %s:\n%s\n', ...
                job.unique_id, ME.message);
        end
    end
end

disp('--- All jobs checked. ---');

end