function metrics_plan = define_metrics_aggregation_plan()
% DEFINE_METRICS_AGGREGATION_PLAN Defines the plan for aggregating neuron metrics.
%   metrics_plan = DEFINE_METRICS_AGGREGATION_PLAN() returns a struct that
%   specifies which per-neuron metrics and PSTH data to aggregate from
%   session_data.mat files.
%
%   Output:
%       metrics_plan: A struct with the following fields:
%           - per_neuron_metrics: A struct array defining metrics to be
%             extracted for each neuron.
%           - psth_aggregation: A struct defining how to aggregate PSTHs.

% © 2025 Your Name or Company

%% Plan for Per-Neuron Metrics
% Each entry specifies a column in the output table and the source path
% to the data within the session_data struct.

metrics_plan.per_neuron_metrics = struct(...
    'ColumnName', {}, ...
    'SourcePath', {});

metrics_plan.per_neuron_metrics(1) = struct(...
    'ColumnName', 'fr', ...
    'SourcePath', 'spikes.cluster_info.fr');

metrics_plan.per_neuron_metrics(2) = struct(...
    'ColumnName', 'amplitude', ...
    'SourcePath', 'spikes.cluster_info.amplitude');

metrics_plan.per_neuron_metrics(3) = struct(...
    'ColumnName', 'contam_pct', ...
    'SourcePath', 'spikes.cluster_info.contam_pct');

metrics_plan.per_neuron_metrics(4) = struct(...
    'ColumnName', 'depth', ...
    'SourcePath', 'spikes.cluster_info.depth');


%% Plan for PSTH Aggregation
% Defines the selector for 'good' neurons and the events for which to
% aggregate mean PSTHs.

metrics_plan.psth_aggregation = struct(...
    'SelectorPath', 'spikes.cluster_info.group', ... % Path to the quality label
    'SelectorValue', 'good', ...                     % Value for good neurons
    'SourcePath', 'psth_data', ...                   % Path to the PSTH data struct
    'DataField', 'rates', ...                        % Field containing the [neurons x trials x bins] matrix
    'Events', {{'targOn', 'reward', 'fixAq'}});       % Events to aggregate

end