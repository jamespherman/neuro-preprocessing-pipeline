function success = prepare_behavioral_data(job, config)
% PREPARE_BEHAVIORAL_DATA - Parses .nev event files and integrates them with
% data from PLDAPS behavioral tasks, saving an intermediate file.
%
% This function takes a job from the session manifest, finds the
% corresponding .nev and PLDAPS files, aligns the trial data between them,
% and saves a merged data structure for further processing.
%
% Inputs:
%   job (table row)      - A single row from the manifest table.
%   config (struct)      - The pipeline configuration struct.
%
% Outputs:
%   success (logical) - true if the intermediate file was created.

try
% Start with a failure status
success = false;

%% 1. Construct Paths
% Path to the raw NEV file containing spike and event data.
nevFile = fullfile(config.rawNeuralDataDir, ...
    [char(job.raw_filename_base), '.nev']);

% Directory for this job's processed (intermediate) data.
intermediateDir = fullfile(config.processedDataDir, job.unique_id);

% Directory for diagnostic plots generated during this process.
diagnosticsDir = fullfile(intermediateDir, 'diagnostics');

% Check if the raw .nev file exists before proceeding.
if ~exist(nevFile, 'file')
    fprintf('NEV file not found: %s\n', nevFile);
    return;
end

% Create directories for intermediate data and diagnostics if they don't
% exist.
if ~exist(intermediateDir, 'dir'), mkdir(intermediateDir); end
if ~exist(diagnosticsDir, 'dir'), mkdir(diagnosticsDir); end

fprintf('Processing job %s...\n', job.unique_id);

%% 2. Parse .nev File
fprintf('Reading NEV file: %s\n', nevFile);
[spike, ~] = utils.read_nev(nevFile);

% Filter for digital events (channel 0) which contain strobed event codes.
digitalEvents = spike(spike(:,1) == 0, :);
eventValuesAll = digitalEvents(:, 2);
eventTimesAll = digitalEvents(:, 3);

% Organize event codes and times into trial-based structures.
[trialInfo, eventTimes, eventValuesTrials] = ...
    utils.getEventTimes(eventValuesAll, eventTimesAll);
nNevTrials = numel(eventValuesTrials);
fprintf('Found %d trials in NEV file.\n', nNevTrials);

%% 3. Find and Load Matching PLDAPS Data
fprintf('Searching for PLDAPS data in: %s\n', config.behavioralDataDir);

% Construct a search pattern to find files/dirs for the session date.
dateObj = datetime(job.date, 'InputFormat', 'MM_dd_yyyy');
formattedDate = string(dateObj, 'yyyyMMdd');
searchPattern = fullfile(config.behavioralDataDir, ...
    ['*', char(formattedDate), '*']);
listing = dir(searchPattern);

% --- Pre-filtering to remove redundant directories ---
% This logic handles cases where data exists both as a directory of loose
% trial files and as a consolidated .mat file. It prioritizes the .mat
% file by removing the directory from the list.
all_names = {listing.name};
is_dir = [listing.isdir];
dir_names = all_names(is_dir);

% Find directories that have a corresponding .mat file with the same name.
[~, dir_basenames, ~] = cellfun(@fileparts, dir_names, ...
    'UniformOutput', false);
mat_files_exist = ismember(cellfun(@(x)[x '.mat'], dir_basenames', ...
    'UniformOutput', false), all_names);

% Identify and filter out the redundant directories.
dirs_to_remove_indices = find(is_dir & ismember(all_names, ...
    dir_names(mat_files_exist)));

if ~isempty(dirs_to_remove_indices)
    fprintf('Found %d redundant director(y/ies), removing...\n', ...
        numel(dirs_to_remove_indices));
    listing(dirs_to_remove_indices) = [];
end
% --- End of pre-filtering ---

valid_p_structs = {};
valid_paths = {};

% Iterate through all matching file system items to find valid data.
for i = 1:length(listing)
    item = listing(i);
    itemPath = fullfile(item.folder, item.name);
    matFilePath = '';

    if item.isdir
        % For directories, check for a minimum number of trial files.
        matFilesInDir = dir(fullfile(itemPath, '*.mat'));
        if numel(matFilesInDir) < 5
            fprintf('  --> Skipping dir, < 5 trials.\n');
            continue;
        end

        % Check if a consolidated .mat file already exists.
        potentialMatFile = fullfile(item.folder, [item.name '.mat']);
        if exist(potentialMatFile, 'file')
            fprintf('  Found matching summary file for dir: %s\n', ...
                item.name);
            matFilePath = potentialMatFile;
        else
            % If no summary file, create one from the loose trial files.
            fprintf('  Unconsolidated data dir found: %s. Consolidating...\n', ...
                item.name);
            try
                matFilePath = utils.catOldOutput(itemPath);
                fprintf('  --> Successfully created summary file: %s\n', ...
                    matFilePath);
            catch ME
                fprintf(2, '  Error consolidating dir %s: %s\n', ...
                    item.name, ME.message);
                continue;
            end
        end
    elseif endsWith(item.name, '.mat')
        % If the item is already a .mat file, use it directly.
        matFilePath = itemPath;
    else
        continue; % Skip other file types.
    end

    if ~isempty(matFilePath)
        fprintf('  Loading candidate file: %s\n', matFilePath);
        warningState = warning('off', ...
            'MATLAB:dispatcher:UnresolvedFunctionHandle');
        try
            matObj = matfile(matFilePath);
            varInfo = whos(matObj);

            % Load the 'p' struct, which contains all session data.
            if ismember('p', {varInfo.name})
                data = load(matFilePath, 'p');
                p_candidate = data.p;
            else
                % If 'p' doesn't exist (older format), synthesize it.
                all_vars = load(matFilePath);
                p_candidate = struct();
                fields = fieldnames(all_vars);
                for k = 1:numel(fields)
                    p_candidate.(fields{k}) = all_vars.(fields{k});
                end
            end
            close all force;

            % Validate that the file was from the correct experiment PC.
            if isfield(p_candidate, 'init') && ...
               isfield(p_candidate.init, 'pcName') && ...
               strcmp(string(p_candidate.init.pcName(1:end-1)), ...
               job.experiment_pc_name)

                valid_p_structs{end+1} = p_candidate;
                valid_paths{end+1} = matFilePath;
                close(findobj('Type', 'Figure'));
                fprintf('  --> Found and validated matching PLDAPS data.\n');
            else
                fprintf('  --> PC name does not match. Skipping.\n');
            end
        catch ME
            warning(warningState);
            fprintf(2, '  Error loading or checking file %s: %s\n', ...
                matFilePath, ME.message);
        end
        warning(warningState);
    end
end

% Final error handling if no valid PLDAPS data was found.
if isempty(valid_p_structs)
    keyboard
    fprintf(['ERROR: No matching PLDAPS data found for date %s ' ...
        'and PC %s.\n'], job.date, job.experiment_pc_name);
    return;
end

% Remove any duplicate file paths that may have been found.
fprintf('Found %d candidate PLDAPS files. Removing duplicates...\n', ...
    numel(valid_paths));
[~, unique_indices] = unique(valid_paths);
valid_paths = valid_paths(unique_indices);
valid_p_structs = valid_p_structs(unique_indices);
fprintf('Found %d unique PLDAPS files.\n', numel(valid_paths));

%% 3.5 Sort and Merge Multiple PLDAPS files

% If multiple PLDAPS files were found (e.g., from restarting a session),
% sort them chronologically and merge them into a single data structure.
if numel(valid_p_structs) > 1
    fprintf('Multiple PLDAPS files found. Sorting and merging...\n');

    % Extract timestamps from filenames (e.g., from '_tHHMM_').
    timestamps = nan(1, numel(valid_paths));
    for i = 1:numel(valid_paths)
        [~, filename, ~] = fileparts(valid_paths{i});
        token = regexp(filename, '_t(\d{4,6})', 'tokens', 'once');
        if ~isempty(token)
            timestamps(i) = str2double(token{1});
        else
            % Use file modification date as a fallback if no timestamp.
            fprintf(['  Warning: No timestamp in "%s". Using file mod ' ...
                'date.\n'], filename);
            fileInfo = dir(valid_paths{i});
            if ~isempty(fileInfo)
                timestamps(i) = fileInfo.datenum;
            end
        end
    end

    % Sort the structs and paths based on the extracted timestamps.
    if ~all(isnan(timestamps))
        [~, sort_idx] = sort(timestamps);
        valid_p_structs = valid_p_structs(sort_idx);
        valid_paths = valid_paths(sort_idx);
        fprintf('  Files sorted. Merging...\n');
    else
        fprintf('  Warning: Could not sort files. Merging in default order.\n');
    end

    % Discover all unique field names across all files to pre-allocate.
    all_trVars_fields = {};
    all_trData_fields = {};
    total_trials = 0;
    for i = 1:numel(valid_p_structs)
        s = valid_p_structs{i};
        if isfield(s, 'trVars') && ~isempty(s.trVars)
            all_trVars_fields = union(all_trVars_fields, fieldnames(s.trVars));
            total_trials = total_trials + numel(s.trVars);
        end
        if isfield(s, 'trData') && ~isempty(s.trData)
            all_trData_fields = union(all_trData_fields, fieldnames(s.trData));
        end
    end

    % Pre-allocate the merged data structure.
    p_data.init = valid_p_structs{1}.init;

    all_trVars_fields = all_trVars_fields(:)';
    args_vars = [all_trVars_fields; cell(1, numel(all_trVars_fields))];
    if ~isempty(args_vars)
        p_data.trVars = repmat(struct(args_vars{:}), total_trials, 1);
    else
        p_data.trVars = [];
    end

    all_trData_fields = all_trData_fields(:)';
    args_data = [all_trData_fields; cell(1, numel(all_trData_fields))];
    if ~isempty(args_data)
        p_data.trData = repmat(struct(args_data{:}), total_trials, 1);
    else
        p_data.trData = [];
    end

    % Loop through sorted structs and copy data into the merged struct.
    trial_offset = 0;
    for i = 1:numel(valid_p_structs)
        s = valid_p_structs{i};
        if ~isfield(s, 'trVars') || isempty(s.trVars)
            continue; % Skip structs with no trials.
        end
        num_trials_in_struct = numel(s.trVars);

        for j = 1:num_trials_in_struct
            current_trial_idx = trial_offset + j;
            % Copy trVars fields.
            for f = 1:numel(all_trVars_fields)
                field = all_trVars_fields{f};
                if isfield(s.trVars, field)
                    p_data.trVars(current_trial_idx).(field) = ...
                        s.trVars(j).(field);
                end
            end
            % Copy trData fields.
            if isfield(s, 'trData') && ~isempty(s.trData)
                for f = 1:numel(all_trData_fields)
                    field = all_trData_fields{f};
                    if isfield(s.trData, field)
                        p_data.trData(current_trial_idx).(field) = ...
                            s.trData(j).(field);
                    end
                end
            end
        end
        trial_offset = trial_offset + num_trials_in_struct;
    end
    fprintf(['  %d files merged into a single data structure with ' ...
        '%d total trials.\n'], numel(valid_p_structs), total_trials);
else
    % If only one file was found, just extract it from the cell array.
    p_data = valid_p_structs{1};
end

%% 4. Match Trials and Integrate Data
nPdsTrials = numel(p_data.trVars);
fprintf('Found %d trials in PLDAPS. Matching with %d NEV trials...\n', ...
    nPdsTrials, nNevTrials);

% Extract all PLDAPS trial strobes into a clean cell array.
pds_strobes = arrayfun(@(x) x.strobed(:), p_data.trData, ...
    'UniformOutput', false);

% Create the mapping from NEV trials to PLDAPS trials.
fprintf('Aligning NEV and PLDAPS trials via constrained search...\n');
nev_to_pds_map = nan(nNevTrials, 1);

% --- Pre-computation of PLDAPS trialCount ---
% This is used for the "Anchor-and-Step" matching method.
codes = utils.initCodes;
temp_counts = cellfun(@(x) x(circshift(x==codes.trialCount, 1)), ...
    pds_strobes, 'UniformOutput', false);
empty_indices = cellfun('isempty', temp_counts);
temp_counts(empty_indices) = {NaN};
pds_trialCount = cell2mat(temp_counts);

% --- Anchor-and-Step Matching Logic ---
% Phase 1: Find an initial, unambiguous anchor match.
initial_anchor_found = false;
last_match_pds_idx = 0;
anchor_nev_idx = 0;

for i = 1:min(100, nNevTrials)
    % define current trial's strobes from NEV
    nev_strobe_vector = eventValuesTrials{i}(:);
    
    % Find potential matches by exact strobe sequence comparison.
    match_indices = find(cellfun(@(x) isequal(x, nev_strobe_vector), ...
        pds_strobes));

    % An anchor is only valid if it's a unique, unambiguous match.
    if isscalar(match_indices)
        match_idx = match_indices(1);
        nev_to_pds_map(i) = match_idx;
        last_match_pds_idx = match_idx;
        initial_anchor_found = true;
        anchor_nev_idx = i;
        anchor_match_value = match_idx;
        fprintf('Anchor match found: NEV trial %d -> PDS trial %d\n', ...
            i, anchor_match_value);
        break; % Exit after finding the first solid anchor.
    end
end

% if exact matching doesn't work to find our 'anchor', use LCS method:
if ~initial_anchor_found
    for i = 1:min(100, nNevTrials)
        % define current trial's strobes from NEV
        nev_strobe_vector = eventValuesTrials{i}(:);

        % Use Longest Common Subsequence.
        if isempty(match_indices)
            lcsVals = cellfun(@(x)utils.calculateLCSLength(...
                nev_strobe_vector, x), pds_strobes);
            maxLcsVal = max(lcsVals);
            match_indices = find(lcsVals == maxLcsVal);
        end

        % An anchor is only valid if it's a unique, unambiguous match.
        if isscalar(match_indices)
            match_idx = match_indices(1);
            nev_to_pds_map(i) = match_idx;
            last_match_pds_idx = match_idx;
            initial_anchor_found = true;
            anchor_nev_idx = i;
            anchor_match_value = match_idx;
            fprintf(['Anchor match found: NEV trial %d -> ' ...
                'PDS trial %d\n'], i, anchor_match_value);
            break; % Exit after finding the first solid anchor.
        end
    end
end

if ~initial_anchor_found
    error('Could not find a reliable anchor match. Aborting.');
end

% Phase 2: Step through subsequent trials using trialCount for matching.
% This is faster and more robust to minor strobe differences than LCS.
if anchor_nev_idx < nNevTrials
    for i = (anchor_nev_idx + 1):nNevTrials
        target_count = trialInfo.trialCount(i);
        if isnan(target_count), continue; end

        search_start_idx = last_match_pds_idx + 1;
        if search_start_idx > nPdsTrials, break; end

        % Find the end of the current monotonic block of PDS trials.
        temp_range = pds_trialCount(search_start_idx:end);
        reset_point_relative = find(diff(temp_range) < 0, 1);

        if isempty(reset_point_relative)
            search_end_idx = nPdsTrials; % No more resets.
        else
            search_end_idx = search_start_idx + reset_point_relative - 1;
        end
        search_range = search_start_idx:search_end_idx;

        % Find the first occurrence of the target trial count.
        relative_idx = find(pds_trialCount(search_range) == target_count, 1);

        if ~isempty(relative_idx)
            match_pds_idx = search_range(relative_idx);
            nev_to_pds_map(i) = match_pds_idx;
            last_match_pds_idx = match_pds_idx;
        end
    end
end

nMatchedTrials = sum(~isnan(nev_to_pds_map));
fprintf('Found %d matched PDS trials out of %d NEV trials. \n', ...
    nMatchedTrials, nNevTrials);

% Plot trial counts for diagnostic purposes.
figure('Color', 'w');
axes('Color', 'w', 'XColor', 'k', 'YColor', 'k', 'TickDir', 'Out');
hold on;
plot(1:length(pds_trialCount), pds_trialCount);
plot((1:length(trialInfo.trialCount)) + anchor_match_value, ...
    trialInfo.trialCount);
legObj = legend('pds trialCount', ...
    'nev trialCount (offset by anchor match)');
set(legObj, 'Color', 'w', 'Box', 'Off', 'TextColor', 'k');
hold off;
xlabel('Row');
ylabel('Trial Count');
title(sprintf('%d matched PDS trials out of %d NEV trials', ...
    nMatchedTrials, nNevTrials), 'Color', 'k');

% Save the diagnostic figure.
plotFileName = fullfile(diagnosticsDir, ...
    [char(job.unique_id), '_trialCount_alignment.png']);
saveas(gcf, plotFileName);
close(gcf);

if nMatchedTrials == 0
    keyboard
    fprintf('ERROR: Could not align NEV and PLDAPS trial strobes.\n');
    return;
end

% Dynamically discover all unique, scalar timing fields from p.trData.timing.
allTimingFields = {};
if isfield(p_data.trData, 'timing')
    for i = 1:nPdsTrials
        if isstruct(p_data.trData(i).timing)
            allTimingFields = union(allTimingFields, ...
                fieldnames(p_data.trData(i).timing));
        end
    end
end

scalarTimingFields = {};
fprintf('Found %d candidate timing fields. Filtering for scalars...\n', ...
    numel(allTimingFields));
for i = 1:numel(allTimingFields)
    fieldName = allTimingFields{i};
    first_occurrence_trial = -1;
    for j = 1:nPdsTrials
        if isfield(p_data.trData(j), 'timing') && ...
           isfield(p_data.trData(j).timing, fieldName)
            first_occurrence_trial = j;
            break;
        end
    end

    if first_occurrence_trial > 0
        fieldValue = p_data.trData(first_occurrence_trial).timing.(fieldName);
        if isscalar(fieldValue)
            scalarTimingFields{end+1} = fieldName;
        else
            fprintf('  --> Filtering out non-scalar timing field: %s\n', ...
                fieldName);
        end
    end
end

% Pre-allocate dynamically discovered fields in eventTimes.
fprintf('Pre-allocating %d dynamically discovered timing fields...\n', ...
    numel(scalarTimingFields));
for f = 1:numel(scalarTimingFields)
    fieldName = scalarTimingFields{f};
    pdsFieldName = ['pds', upper(fieldName(1)), fieldName(2:end)];
    eventTimes.(pdsFieldName) = nan(nNevTrials, 1);
end

% Analyze PLDAPS fields for consistent sizing and pre-allocate trialInfo.
fprintf('Analyzing PLDAPS fields and pre-allocating trialInfo table...\n');

% --- Analysis and Pre-allocation for trVars ---
trVarsFieldsToCopy = {};
if isfield(p_data, 'trVars') && ~isempty(p_data.trVars)
    allTrVarsFields = {};
    for i = 1:numel(p_data.trVars)
        allTrVarsFields = union(allTrVarsFields, fieldnames(p_data.trVars(i)));
    end

    existingTrialInfoFields = fieldnames(trialInfo);
    for f = 1:numel(allTrVarsFields)
        fieldName = allTrVarsFields{f};
        if ismember(fieldName, existingTrialInfoFields), continue; end

        is_consistent = true;
        is_numeric = true;
        is_struct = false;
        first_size = [];
        first_val_found = false;

        for i = 1:numel(p_data.trVars)
            if isfield(p_data.trVars(i), fieldName)
                val = p_data.trVars(i).(fieldName);
                if isstruct(val), is_struct = true; break; end
                if ~isempty(val)
                    if ~(isnumeric(val) || islogical(val))
                        is_numeric = false; break;
                    end
                    if ~first_val_found
                        first_size = size(val);
                        first_val_found = true;
                    elseif ~isequal(size(val), first_size)
                        is_consistent = false; break;
                    end
                end
            end
        end
        if is_struct, continue; end

        trVarsFieldsToCopy{end+1} = fieldName;
        if is_consistent && is_numeric
            trialInfo.(fieldName) = nan(nNevTrials, prod(first_size));
        else
            trialInfo.(fieldName) = cell(nNevTrials, 1);
        end
    end
end

% --- Analysis and Pre-allocation for trData ---
trDataFieldsToCopy = {};
if isfield(p_data, 'trData') && ~isempty(p_data.trData)
    allTrDataFields = {};
    for i = 1:numel(p_data.trData)
        allTrDataFields = union(allTrDataFields, fieldnames( ...
            p_data.trData(i)));
    end

    existingTrialInfoFields = fieldnames(trialInfo);
    for f = 1:numel(allTrDataFields)
        fieldName = allTrDataFields{f};
        if ismember(fieldName, existingTrialInfoFields) || ...
            strcmp(fieldName, 'timing')
            continue;
        end

        is_consistent = true;
        is_numeric = true;
        is_struct = false;
        first_size = [];
        first_val_found = false;

        for i = 1:numel(p_data.trData)
            if isfield(p_data.trData(i), fieldName)
                val = p_data.trData(i).(fieldName);
                if isstruct(val), is_struct = true; break; end
                if ~isempty(val)
                    if ~(isnumeric(val) || islogical(val))
                        is_numeric = false; break;
                    end
                    if ~first_val_found
                        first_size = size(val);
                        first_val_found = true;
                    elseif ~isequal(size(val), first_size)
                        is_consistent = false; break;
                    end
                end
            end
        end
        if is_struct, continue; end

        trDataFieldsToCopy{end+1} = fieldName;
        if is_consistent && is_numeric
            trialInfo.(fieldName) = nan(nNevTrials, prod(first_size));
        else
            trialInfo.(fieldName) = cell(nNevTrials, 1);
        end
    end
end

% --- Main Integration Loop ---
% Copy data from the PLDAPS structure to the NEV-based trialInfo table.
for nevIdx = 1:nNevTrials
    pdsIdx = nev_to_pds_map(nevIdx);
    if ~isnan(pdsIdx) % Only copy if a match was found.
        % Dynamically copy from p.trVars.
        for f = 1:numel(trVarsFieldsToCopy)
            fieldName = trVarsFieldsToCopy{f};
            if isfield(p_data.trVars(pdsIdx), fieldName)
                dataValue = p_data.trVars(pdsIdx).(fieldName);
                if iscell(trialInfo.(fieldName))
                    trialInfo.(fieldName){nevIdx} = dataValue;
                elseif isempty(dataValue)
                    trialInfo.(fieldName)(nevIdx, :) = nan;
                else
                    trialInfo.(fieldName)(nevIdx, :) = dataValue(:)';
                end
            end
        end

        % Dynamically copy from p.trData.
        for f = 1:numel(trDataFieldsToCopy)
            fieldName = trDataFieldsToCopy{f};
            if isfield(p_data.trData(pdsIdx), fieldName)
                dataValue = p_data.trData(pdsIdx).(fieldName);
                if iscell(trialInfo.(fieldName))
                    trialInfo.(fieldName){nevIdx} = dataValue;
                elseif isempty(dataValue)
                    trialInfo.(fieldName)(nevIdx, :) = nan;
                else
                    trialInfo.(fieldName)(nevIdx, :) = dataValue(:)';
                end
            end
        end

        % Map detailed event timestamps from p.trData.timing.
        if isfield(p_data.trData(pdsIdx), 'timing') && ...
           isstruct(p_data.trData(pdsIdx).timing)
            timingData = p_data.trData(pdsIdx).timing;
            timingFields = fieldnames(timingData);
            for t = 1:numel(timingFields)
                pdsFieldName = ['pds', upper(timingFields{t}(1)), ...
                    timingFields{t}(2:end)];
                if isfield(eventTimes, pdsFieldName)
                    eventTimes.(pdsFieldName)(nevIdx) = ...
                        timingData.(timingFields{t});
                end
            end
        end
    end
end

%% 4.5 Timestamp Correction for gSac_4factors
% This section corrects for timestamp drift in the gSac_4factors task
% by building a linear model from other, more reliable tasks run in the
% same session and applying it to the gSac_4factors timestamps.

codes = utils.initCodes;
is_gsac_4factors_trial = (trialInfo.taskCode == ...
    codes.uniqueTaskCode_gSac_4factors);

% Identify "good" non-gSac trials to build the correction model.
good_trial_indices = find(~is_gsac_4factors_trial & ...
    ~isnan(nev_to_pds_map));

if ~isempty(good_trial_indices)
    % Collect paired timestamps from reliable trials.
    pds_trial_end_times = eventTimes.pdsTrialEnd(good_trial_indices);
    pds_trial_start_ptb = eventTimes.pdsTrialStartPTB( ...
        good_trial_indices);

    pldaps_times = pds_trial_start_ptb + pds_trial_end_times;
    ripple_times = eventTimes.trialEnd(good_trial_indices);

    % Remove pairs with NaN values before fitting.
    nan_mask = isnan(pldaps_times) | isnan(ripple_times);
    pldaps_times(nan_mask) = [];
    ripple_times(nan_mask) = [];

    if numel(pldaps_times) > 1 % Need at least 2 points for a line.
        % --- Outlier Removal ---
        [p_initial, ~, mu_initial] = polyfit(pldaps_times, ...
            ripple_times, 1);
        residuals = ripple_times(:) - polyval(p_initial, pldaps_times, ...
            [], mu_initial);
        is_outlier = abs(residuals) > 3 * std(residuals);

        if any(is_outlier)
            fprintf(['  --> Detected and removed %d outlier(s) ' ...
                'from fit.\n'], nnz(is_outlier));
        end

        % Create the final model using only "inlier" data.
        pldaps_times_clean = pldaps_times(~is_outlier);
        ripple_times_clean = ripple_times(~is_outlier);

        [map_params, stats, mu] = polyfit(pldaps_times_clean, ...
            ripple_times_clean, 1);
        predicted_ripple = polyval(map_params, pldaps_times_clean, ...
            [], mu);

        % Generate a diagnostic scatter plot.
        figure;
        scatter(pldaps_times_clean, ripple_times_clean, 'filled');
        hold on;
        plot(pldaps_times_clean, predicted_ripple, 'r-');
        if isfield(stats, 'rsquared')
            title(['Timestamp Correction Fit for ', job.unique_id, ...
                ' | R^2 = ', num2str(stats.rsquared)], 'Interpreter', 'none');
        else
            title(['Timestamp Correction Fit for ', job.unique_id, ...
                ' | R^2 = ', num2str(stats.normr)], 'interpreter', 'none');
        end
        xlabel('PLDAPS Time (s)');
        ylabel('Ripple Time (s)');
        legend('Data', 'Linear Fit', 'Location', 'best');
        grid on;

        % Save the diagnostic figure.
        plotFileName = fullfile(diagnosticsDir, ...
            [char(job.unique_id), '_timestamp_fit.pdf']);
        saveas(gcf, plotFileName);
        close(gcf);

    else
        warning(['Not enough reliable trials to build correction ' ...
            'model.']);
    end

else
    warning('No reliable trials found to build correction model.');
end

% if there are gSac_4factors trials, we need to correct the timestamps:
if any(is_gsac_4factors_trial)
    fprintf(['Found gSac_4factors trials. ' ...
        'Applying timestamp correction...\n']);

    % Define mapping from NEV target fields to PLDAPS source fields.
    map = containers.Map(...
        {'CUE_ON', 'fixAq', 'fixBreak', 'fixOff', 'fixOn', ...
        'joyPress', 'lowTone', 'reward', 'REWARD_GIVEN', ...
        'saccadeOffset', 'saccadeOnset', 'targetAq', ...
        'targetOff', 'targetOn', 'targetReillum', 'trialEnd', ...
        'TRIAL_END', 'trialBegin'}, ...
        {'pdsCueOn', 'pdsFixAq', 'pdsBrokeFix', 'pdsFixOff', ...
        'pdsFixOn', 'pdsJoyPress', 'pdsTone', 'pdsReward', ...
        'pdsReward', 'pdsSaccadeOffset', 'pdsSaccadeOnset', ...
        'pdsTargetAq', 'pdsTargetOff', 'pdsTargetOn', ...
        'pdsTargetReillum', 'pdsTrialEnd', 'pdsTrialEnd', ...
        'pdsTrialBegin'});
    fields_to_null = {'nonStart', 'blinkDuringSac'};

    % Apply correction to all gSac_4factors trials.
    gsac_indices = find(is_gsac_4factors_trial);
    for i = 1:length(gsac_indices)
        nevIdx = gsac_indices(i);
        pdsIdx = nev_to_pds_map(nevIdx);

        if ~isnan(pdsIdx) && isfield(p_data.trData(pdsIdx), ...
                'timing') ...
                && isfield(p_data.trData(pdsIdx).timing, ...
                'trialStartPTB')
            pds_start = p_data.trData(pdsIdx).timing.trialStartPTB;

            target_fields = keys(map);
            for k = 1:length(target_fields)
                target = target_fields{k};
                source = map(target);
                if isfield(eventTimes, source)
                    relative_time = eventTimes.(source)(nevIdx);
                    if ~isnan(relative_time)
                        absolute_pds = pds_start + relative_time;
                        corrected_abs = polyval(map_params, ...
                            absolute_pds, [], mu);
                        if isfield(eventTimes, target)
                            eventTimes.(target)(nevIdx) = ...
                                corrected_abs;
                        end
                    end
                end
            end
            % Nullify fields known to be unreliable in this task.
            for k = 1:length(fields_to_null)
                if isfield(eventTimes, fields_to_null{k})
                    eventTimes.(fields_to_null{k})(nevIdx) = NaN;
                end
            end
        end
    end
    fprintf('Timestamp correction applied to %d gSac trials.\n', ...
        length(gsac_indices));
else
    fprintf('No gSac_4factors trials found. Skipping correction.\n');
end
%% 4.6 Timestamp Correction for Tokens Task Outcome
% This section applies the session's clock correction model to the
% 'pdsOutcomeOn' event times for trials from the 'tokens' task.

% Identify trials belonging to the 'tokens' task
is_tokens_trial = trialInfo.taskCode == codes.uniqueTaskCode_tokens;

% Proceed only if there are tokens trials and a valid mapping exists
if any(is_tokens_trial) && exist('map_params', 'var')
    fprintf(['Found tokens trials. Applying timestamp correction to ' ...
        '''outcomeOn'' event.\n']);
    
    % Create and initialize a new field to hold the corrected timestamps
    eventTimes.outcomeOn = nan(nNevTrials, 1);
    
    % Get the indices of the tokens trials to be corrected
    tokens_indices = find(is_tokens_trial);
    
    % Loop through each tokens trial
    for i = 1:length(tokens_indices)
        nevIdx = tokens_indices(i);
        
        % Get the necessary PDS-based timestamps for this trial
        pds_start_time = eventTimes.pdsTrialStartPTB(nevIdx);
        relative_outcome_time = eventTimes.pdsOutcomeOn(nevIdx);
        
        % Ensure both required time values are valid numbers before 
        % proceeding
        if ~isnan(pds_start_time) && ~isnan(relative_outcome_time)
            
            % Step 1: Calculate the absolute time of the event on the PDS 
            % clock
            absolute_pds_time = pds_start_time + relative_outcome_time;
            
            % Step 2: Translate the absolute PDS time into the Ripple 
            % clock's time base using the model derived from the session's 
            % 'trialEnd' events.
            corrected_ripple_time = polyval(map_params, ...
                absolute_pds_time, [], mu);
            
            % Step 3: Assign the corrected timestamp to the new field
            eventTimes.outcomeOn(nevIdx) = corrected_ripple_time;
        end
    end
else
    fprintf(['No tokens trials. Skipping timestamp correction to ' ...
        '''outcomeOn'' event.\n']);
end

%% 5. Save Intermediate File
outputFileName = sprintf('%s_intermediate_data.mat', job.unique_id);
outputFilePath = fullfile(intermediateDir, outputFileName);

fprintf('Saving intermediate data to: %s\n', outputFilePath);
try
    save(outputFilePath, 'trialInfo', 'eventTimes', ...
        'eventValuesTrials', '-v7.3');
    success = true;
    fprintf('Successfully created intermediate data file.\n');
catch ME
    fprintf(2, 'ERROR during behavioral data prep for %s:\n', ...
        job.unique_id);
    fprintf(2, '%s\n', ME.message);
    warning(['Execution paused. Inspect variables (ME, job, config) ' ...
        'and type ''dbcont'' to continue or ''dbquit'' to exit.']);
    keyboard; % Pause for debugging
    success = false;
end

catch me
    keyboard
end

end
