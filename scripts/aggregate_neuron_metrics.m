function aggregate_neuron_metrics()
% AGGREGATE_NEURON_METRICS Aggregates per-neuron metrics and PSTHs across all sessions.
%   This script is plan-driven. It first calls a function to define an
%   aggregation plan, then iterates through all completed sessions in the
%   session manifest, aggregating the data specified in the plan.
%
%   The final aggregated data is saved to 'data/processed/aggregated_neuron_metrics.mat'.

% © 2025 Your Name or Company

%% Setup
% Add necessary paths
addpath(genpath('../functions'));

% --- 1. Load the Aggregation Plan ---
metrics_plan = utils.define_metrics_aggregation_plan();

% --- 2. Load Session Manifest ---
project_root = utils.find_project_root();
manifest_path = fullfile(project_root, 'config', 'session_manifest.csv');
session_manifest = readtable(manifest_path);

disp('Plan and session manifest loaded.');

%% Initialize Output Structures (Plan-Driven)

% --- For Per-Neuron Metrics ---
per_neuron_colnames = {metrics_plan.per_neuron_metrics.ColumnName};
sc_metrics = table('Size', [0, numel(per_neuron_colnames)], 'VariableTypes', repmat("double", 1, numel(per_neuron_colnames)), 'VariableNames', per_neuron_colnames);
snc_metrics = table('Size', [0, numel(per_neuron_colnames)], 'VariableTypes', repmat("double", 1, numel(per_neuron_colnames)), 'VariableNames', per_neuron_colnames);

% --- For PSTH Data ---
psth_data = struct();
psth_data.sc = struct();
psth_data.snc = struct();
for i = 1:numel(metrics_plan.psth_aggregation.Events)
    event_name = metrics_plan.psth_aggregation.Events{i};
    psth_data.sc.(event_name) = [];
    psth_data.snc.(event_name) = [];
end

disp('Output structures initialized.');

%% Main Aggregation Loop
% --- 3. Filter for Completed Sessions ---
analysis_status_idx = strcmp(session_manifest.analysis_status, 'complete');
completed_sessions = session_manifest(analysis_status_idx, :);

fprintf('Found %d completed sessions to aggregate.\n', height(completed_sessions));

for i = 1:height(completed_sessions)
    session_info = completed_sessions(i, :);
    unique_id = session_info.unique_id{1};
    brain_area = session_info.brain_area{1};

    fprintf('\nProcessing session: %s\n', unique_id);

    % Construct path to the session data file
    % Note: This assumes a local 'data/processed' directory structure
    session_data_path = fullfile(project_root, 'data', 'processed', unique_id, [unique_id, '_session_data.mat']);

    if ~isfile(session_data_path)
        fprintf('  - Warning: Could not find session_data.mat file. Skipping.\n');
        fprintf('    - Searched at: %s\n', session_data_path);
        continue;
    end

    % Load the session's data
    fprintf('  - Loading session data...\n');
    load(session_data_path, 'session_data');

    % --- Aggregate Per-Neuron Metrics (Plan-Driven) ---
    fprintf('  - Aggregating per-neuron metrics...\n');
    num_neurons = height(session_data.spikes.cluster_info);
    session_metrics_data = zeros(num_neurons, numel(metrics_plan.per_neuron_metrics));

    for j = 1:numel(metrics_plan.per_neuron_metrics)
        metric_info = metrics_plan.per_neuron_metrics(j);
        try
            data_vector = get_nested_field(session_data, metric_info.SourcePath);
            session_metrics_data(:, j) = data_vector;
        catch ME
            fprintf('    - Warning: Could not extract metric "%s". Error: %s. Filling with NaNs.\n', metric_info.ColumnName, ME.message);
            session_metrics_data(:, j) = NaN;
        end
    end

    session_metrics_table = array2table(session_metrics_data, 'VariableNames', per_neuron_colnames);

    % Append to the correct master table
    if strcmpi(brain_area, 'SC')
        sc_metrics = [sc_metrics; session_metrics_table];
    elseif strcmpi(brain_area, 'SNc')
        snc_metrics = [snc_metrics; session_metrics_table];
    end

    % --- Aggregate Mean PSTHs (Plan-Driven) ---
    fprintf('  - Aggregating PSTHs...\n');

    % Get the logical vector of selected neurons
    quality_labels = get_nested_field(session_data, metrics_plan.psth_aggregation.SelectorPath);
    selected_neurons = strcmp(quality_labels, metrics_plan.psth_aggregation.SelectorValue);

    if ~any(selected_neurons)
        fprintf('  - No neurons met the selection criteria ("%s"). Skipping PSTH aggregation.\n', metrics_plan.psth_aggregation.SelectorValue);
        continue;
    end

    % Loop through the specified events
    for j = 1:numel(metrics_plan.psth_aggregation.Events)
        event_name = metrics_plan.psth_aggregation.Events{j};

        try
            % Access the [n_neurons, n_trials, n_bins] rates matrix
            psth_struct = get_nested_field(session_data, metrics_plan.psth_aggregation.SourcePath);
            rates_matrix = psth_struct.(event_name).(metrics_plan.psth_aggregation.DataField);

            % Filter for selected neurons
            selected_rates = rates_matrix(selected_neurons, :, :);

            % Calculate mean PSTH for each neuron (average across trials)
            % Resulting dimensions: [n_selected_neurons x n_bins]
            mean_psth = mean(selected_rates, 2, 'omitnan');
            mean_psth = squeeze(mean_psth); % Squeeze to remove the singleton dimension

            % Vertically concatenate onto the appropriate field
            if strcmpi(brain_area, 'SC')
                psth_data.sc.(event_name) = [psth_data.sc.(event_name); mean_psth];
            elseif strcmpi(brain_area, 'SNc')
                psth_data.snc.(event_name) = [psth_data.snc.(event_name); mean_psth];
            end
        catch ME
            fprintf('    - Warning: Could not aggregate PSTH for event "%s". Error: %s\n', event_name, ME.message);
        end
    end
end

%% Save the Aggregated Data
% --- 4. Save to a .mat file ---
output_dir = fullfile(project_root, 'data', 'processed');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
output_path = fullfile(output_dir, 'aggregated_neuron_metrics.mat');

fprintf('\nAggregation complete. Saving data to: %s\n', output_path);
save(output_path, 'sc_metrics', 'snc_metrics', 'psth_data', 'metrics_plan');

disp('Script finished successfully.');

end


%% Helper Function
function val = get_nested_field(s, field_path)
% GET_NESTED_FIELD Accesses a nested field in a struct using a dot-separated path.
%   val = GET_NESTED_FIELD(s, 'parent.child.field') returns s.parent.child.field.

    path_parts = strsplit(field_path, '.');
    val = s;
    for k = 1:numel(path_parts)
        val = val.(path_parts{k});
    end
end