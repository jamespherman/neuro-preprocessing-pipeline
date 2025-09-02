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

% Start with a failure status
success = false;

%% 1. Construct Paths
nevFile = fullfile(config.rawNeuralDataDir, job.raw_filename_base + ...
    ".nev");
intermediateDir = fullfile(config.processedDataDir, job.unique_id);

% Check if the raw .nev file exists
if ~exist(nevFile, 'file')
    fprintf('NEV file not found: %s\n', nevFile);
    return;
end

% Create the intermediate directory for this job if it doesn't exist
if ~exist(intermediateDir, 'dir')
    mkdir(intermediateDir);
end

fprintf('Processing job %s...\n', job.unique_id);

%% 2. Parse .nev File
fprintf('Reading NEV file: %s\n', nevFile);
[spike, ~] = utils.read_nev(nevFile);

% Filter for digital events (channel 0)
digitalEvents = spike(spike(:,1) == 0, :);
eventValues = digitalEvents(:, 2);
eventTimes = digitalEvents(:, 3);

% Get trial-by-trial event codes and times
[trialInfo, eventTimes, eventValuesTrials] = utils.getEventTimes(eventValues, eventTimes);
nNevTrials = numel(eventValuesTrials);
fprintf('Found %d trials in NEV file.\n', nNevTrials);

%% 3. Find and Load Matching PLDAPS Data
fprintf('Searching for PLDAPS data in: %s\n', config.behavioralDataDir);

% Construct a search pattern to find both files and directories. Convert 
% job.date to datetime, change format to 'YYYYMMDD', construct
% 'searchPattern' from reformatted date, and list directory contents that
% match searchPattern:
dateObj = datetime(job.date, 'InputFormat', 'MM_dd_yyyy');
formattedDate = string(dateObj, 'yyyyMMdd');
searchPattern = string(config.behavioralDataDir) + string(filesep) + ...
    "*" + formattedDate + "*";
listing = dir(searchPattern);

% --- Pre-filtering logic to remove redundant directories ---
% Extract all names and identify which are directories
all_names = {listing.name};
is_dir = [listing.isdir];
dir_names = all_names(is_dir);

% Find directories that have a corresponding .mat file
[~, dir_basenames, ~] = cellfun(@fileparts, dir_names, ...
    'UniformOutput', false);
mat_files_exist = ismember(cellfun(@(x)[x '.mat'], dir_basenames', ...
    'UniformOutput', false), all_names);

% Identify indices of directories to be removed
dirs_to_remove_indices = find(is_dir & ismember(all_names, ...
    dir_names(mat_files_exist)));

% Filter the original listing struct
if ~isempty(dirs_to_remove_indices)
    fprintf(['Found %d redundant director(y/ies), ...' ...
        'removing from processing list...\n'], ...
        numel(dirs_to_remove_indices));
    listing(dirs_to_remove_indices) = [];
end
% --- End of pre-filtering logic ---

valid_p_structs = {};
valid_paths = {};

% Iterate through all matching file system items
for i = 1:length(listing)
    item = listing(i);
    itemPath = fullfile(item.folder, item.name);

    matFilePath = '';

    if item.isdir
        % It's a directory, first check for the number of .mat files
        matFilesInDir = dir(fullfile(itemPath, '*.mat'));
        if numel(matFilesInDir) < 5
            fprintf('  --> Skipping directory, contains fewer than 25 trials.\n');
            continue;
        end

        % Now, check for a pre-existing .mat file
        potentialMatFile = fullfile(item.folder, [item.name '.mat']);
        if exist(potentialMatFile, 'file')
            fprintf('  Found matching summary file for directory: %s\n', item.name);
            matFilePath = potentialMatFile;
        else
            % If no .mat file, create it by calling utils.catOldOutput
            fprintf('  Found unconsolidated data directory: %s. Consolidating...\n', item.name);
            try
                matFilePath = utils.catOldOutput(itemPath);
                fprintf('  --> Successfully created summary file: %s\n', matFilePath);
            catch ME
                fprintf(2, '  Error consolidating directory %s: %s\n', item.name, ME.message);
                continue; % Try the next item
            end
        end
    elseif endsWith(item.name, '.mat')
        % It's already a .mat file
        matFilePath = itemPath;
    else
        % Not a directory or a .mat file, so skip
        continue;
    end

    if ~isempty(matFilePath)
        fprintf('  Loading candidate file: %s\n', matFilePath);
        warningState = warning('off', 'MATLAB:dispatcher:UnresolvedFunctionHandle');
        try
            matObj = matfile(matFilePath);
            varInfo = whos(matObj);

            if ismember('p', {varInfo.name})
                % If 'p' exists, load it directly
                data = load(matFilePath, 'p');
                p_candidate = data.p;
            else
                % If 'p' does not exist, load all variables and syntesize p
                all_vars = load(matFilePath);
                p_candidate = struct();
                fields = fieldnames(all_vars);
                for k = 1:numel(fields)
                    p_candidate.(fields{k}) = all_vars.(fields{k});
                end
            end

            % Validate that the candidate structure has the correct PC name
            if isfield(p_candidate, 'init') && isfield(p_candidate.init, 'pcName') && ...
               strcmp(string(p_candidate.init.pcName(1:end-1)), job.experiment_pc_name)

                valid_p_structs{end+1} = p_candidate;
                valid_paths{end+1} = matFilePath;
                close(findobj('Type', 'Figure'));
                fprintf('  --> Found and validated matching PLDAPS data.\n');
            else
                fprintf('  --> PC name does not match. Skipping.\n');
            end
        catch ME
            % Restore warning state in case of an error
            warning(warningState);
            fprintf(2, '  Error loading or checking file %s: %s\n', matFilePath, ME.message);
        end
        % Restore the original warning state after successful loading
        warning(warningState);
    end
end

% Final error handling after checking all candidates
if isempty(valid_p_structs)
    keyboard
    fprintf('ERROR: No matching PLDAPS data (file or directory) found for date %s and PC %s.\n', job.date, job.experiment_pc_name);
    return;
end

fprintf('Found %d candidate PLDAPS files. Removing duplicates...\n', numel(valid_paths));
[~, unique_indices] = unique(valid_paths);

valid_paths = valid_paths(unique_indices);
valid_p_structs = valid_p_structs(unique_indices);
fprintf('Found %d unique PLDAPS files.\n', numel(valid_paths));

%% 3.5 Sort and Merge Multiple PLDAPS files

% If multiple PLDAPS files were found, sort them chronologically and merge
if numel(valid_p_structs) > 1
    fprintf('Multiple PLDAPS files found. Sorting chronologically before merging...\n');

    % Extract timestamps from filenames (e.g., from '_tHHMM_')
    timestamps = nan(1, numel(valid_paths));
    for i = 1:numel(valid_paths)
        [~, filename, ~] = fileparts(valid_paths{i});
        token = regexp(filename, '_t(\d{4,6})', 'tokens', 'once');
        if ~isempty(token)
            timestamps(i) = str2double(token{1});
        else
            fprintf('  Warning: Could not find _tHHMM_ timestamp in "%s". Using file modification date as a fallback.\n', filename);
            fileInfo = dir(valid_paths{i});
            if ~isempty(fileInfo)
                timestamps(i) = fileInfo.datenum;
            end
        end
    end

    % Get the sort order and re-order the structs and paths
    if ~all(isnan(timestamps))
        [~, sort_idx] = sort(timestamps);
        valid_p_structs = valid_p_structs(sort_idx);
        valid_paths = valid_paths(sort_idx);
        fprintf('  Files sorted. Merging...\n');
    else
        fprintf('  Warning: Could not determine chronological order. Merging in default order.\n');
    end

    % B. Discover All Field Names
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

    % C. Pre-allocate and Merge
    p_data.init = valid_p_structs{1}.init;

    % Create empty struct arrays with all fields for trVars
    all_trVars_fields = all_trVars_fields(:)'; % Ensure it's a row vector
    args_vars = [all_trVars_fields; cell(1, numel(all_trVars_fields))];
    args_vars = args_vars(:)';
    if ~isempty(args_vars)
        p_data.trVars = repmat(struct(args_vars{:}), total_trials, 1);
    else
        p_data.trVars = [];
    end

    % Create empty struct arrays with all fields for trData
    all_trData_fields = all_trData_fields(:)'; % Ensure it's a row vector
    args_data = [all_trData_fields; cell(1, numel(all_trData_fields))];
    args_data = args_data(:)';
    if ~isempty(args_data)
        p_data.trData = repmat(struct(args_data{:}), total_trials, 1);
    else
        p_data.trData = [];
    end

    % Loop through your sorted valid_p_structs and copy data
    trial_offset = 0;
    for i = 1:numel(valid_p_structs)
        s = valid_p_structs{i};
        if ~isfield(s, 'trVars') || isempty(s.trVars)
            continue; % Skip structs with no trials
        end
        num_trials_in_struct = numel(s.trVars);

        for j = 1:num_trials_in_struct
            current_trial_idx = trial_offset + j;

            % Copy trVars
            for f = 1:numel(all_trVars_fields)
                field = all_trVars_fields{f};
                if isfield(s.trVars, field)
                    p_data.trVars(current_trial_idx).(field) = s.trVars(j).(field);
                end
            end

            % Copy trData
            if isfield(s, 'trData') && ~isempty(s.trData)
                for f = 1:numel(all_trData_fields)
                    field = all_trData_fields{f};
                    if isfield(s.trData, field)
                        p_data.trData(current_trial_idx).(field) = s.trData(j).(field);
                    end
                end
            end
        end
        trial_offset = trial_offset + num_trials_in_struct;
    end
    fprintf('  %d files merged into a single data structure with %d total trials.\n', numel(valid_p_structs), total_trials);
else
    % If only one file was found, just extract it from the cell array
    p_data = valid_p_structs{1};
end

%% 4. Match Trials and Integrate Data
% The new logic correctly uses p.trVars and p.trData
nPdsTrials = numel(p_data.trVars);
fprintf('Found %d trials in PLDAPS file. Matching with NEV trials...\n', nPdsTrials);

% After the master p_data struct is created (at the end of Phase 1), extract
% all PLDAPS trial strobes into a clean cell array. Ensure they are column
% vectors for consistent comparison.
pds_strobes = arrayfun(@(x) x.strobed(:), p_data.trData, 'UniformOutput', false);

% Create the NEV-to-PLDAPS Mapping
fprintf('Aligning NEV and PLDAPS trials via exhaustive strobe search...\n');
nev_to_pds_map = nan(nNevTrials, 1);

% Now, implement the cellfun mapping logic. Loop through each NEV trial,
% find its match in the pds_strobes cell array, and record the index.
for i = 1:nNevTrials
    nev_strobe_vector = eventValuesTrials{i}(:);

    % Use cellfun to find a match in the PLDAPS strobes
    match_idx = find(cellfun(@(x) isequal(x, nev_strobe_vector), pds_strobes), 1);

    if ~isempty(match_idx)
        nev_to_pds_map(i) = match_idx;
    end
end

nMatchedTrials = sum(~isnan(nev_to_pds_map));
fprintf('Found %d matched trials between NEV and PLDAPS data.\n', nMatchedTrials);

if nMatchedTrials == 0
    keyboard
    fprintf('ERROR: Could not align NEV and PLDAPS trial strobes.\n');
    return;
end

% Dynamically discover all unique timing fields from p.trData.timing
allTimingFields = {};
if isfield(p_data.trData, 'timing')
    for i = 1:nPdsTrials
        if isstruct(p_data.trData(i).timing)
            allTimingFields = union(allTimingFields, fieldnames(p_data.trData(i).timing));
        end
    end
end

% --- Data-Driven Filtering of Timing Fields ---
scalarTimingFields = {};
fprintf('  Found %d candidate timing fields. Filtering for scalar values...\n', numel(allTimingFields));

for i = 1:numel(allTimingFields)
    fieldName = allTimingFields{i};

    % Find the first trial that contains this timing field
    first_occurrence_trial = -1;
    for j = 1:nPdsTrials
        if isfield(p_data.trData(j), 'timing') && isfield(p_data.trData(j).timing, fieldName)
            first_occurrence_trial = j;
            break;
        end
    end

    % If the field was found, check if its value is scalar in that trial
    if first_occurrence_trial > 0
        fieldValue = p_data.trData(first_occurrence_trial).timing.(fieldName);
        if numel(fieldValue) == 1
            scalarTimingFields{end+1} = fieldName;
        else
            fprintf('  --> Filtering out non-scalar timing field: %s (size: %s)\n', ...
                    fieldName, mat2str(size(fieldValue)));
        end
    end
end

% Pre-allocate dynamically discovered fields in eventTimes
fprintf('  Pre-allocating %d dynamically discovered timing fields...\n', numel(scalarTimingFields));
for f = 1:numel(scalarTimingFields)
    fieldName = scalarTimingFields{f};
    pdsFieldName = ['pds' upper(fieldName(1)) fieldName(2:end)];
    eventTimes.(pdsFieldName) = nan(nNevTrials, 1);
end


% --- Analyze PLDAPS fields for consistent sizing and pre-allocate trialInfo ---
fprintf('Analyzing PLDAPS fields and pre-allocating trialInfo table...\n');

% --- Analysis and Pre-allocation for trVars ---
trVarsFieldsToCopy = {};
if isfield(p_data, 'trVars') && ~isempty(p_data.trVars)
    allTrVarsFields = {};
    % Discover all unique fields from all trials first
    for i = 1:numel(p_data.trVars)
        allTrVarsFields = union(allTrVarsFields, fieldnames(p_data.trVars(i)));
    end

    % Analyze each field and pre-allocate
    existingTrialInfoFields = fieldnames(trialInfo);
    for f = 1:numel(allTrVarsFields)
        fieldName = allTrVarsFields{f};
        if ismember(fieldName, existingTrialInfoFields)
            continue;
        end

        first_size = [];
        is_consistent = true;
        is_numeric = false;
        is_struct = false;

        % Find first instance to get base properties
        first_val_idx = -1;
        for i = 1:numel(p_data.trVars)
            if isfield(p_data.trVars(i), fieldName)
                val = p_data.trVars(i).(fieldName);
                first_size = size(val);
                is_numeric = isnumeric(val) || islogical(val);
                is_struct = isstruct(val);
                first_val_idx = i;
                break;
            end
        end

        if is_struct || first_val_idx == -1
            continue; % Skip structs and fields that were not found
        end

        % Compare with the rest of the trials for size consistency
        for i = (first_val_idx + 1):numel(p_data.trVars)
            if isfield(p_data.trVars(i), fieldName)
                if ~isequal(size(p_data.trVars(i).(fieldName)), first_size)
                    is_consistent = false;
                    fprintf('  --> Detected variable size for trVars field: %s\n', fieldName);
                    break;
                end
            end
        end

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
    % Discover all unique fields from all trials first
    for i = 1:numel(p_data.trData)
        allTrDataFields = union(allTrDataFields, fieldnames(p_data.trData(i)));
    end

    % Analyze each field and pre-allocate
    existingTrialInfoFields = fieldnames(trialInfo); % Update with fields from trVars
    for f = 1:numel(allTrDataFields)
        fieldName = allTrDataFields{f};
        if ismember(fieldName, existingTrialInfoFields) || strcmp(fieldName, 'timing')
            continue;
        end

        first_size = [];
        is_consistent = true;
        is_numeric = false;
        is_struct = false;

        % Find first instance to get base properties
        first_val_idx = -1;
        for i = 1:numel(p_data.trData)
            if isfield(p_data.trData(i), fieldName)
                val = p_data.trData(i).(fieldName);
                first_size = size(val);
                is_numeric = isnumeric(val) || islogical(val);
                is_struct = isstruct(val);
                first_val_idx = i;
                break;
            end
        end

        if is_struct || first_val_idx == -1
            continue; % Skip structs
        end

        % Compare with the rest of the trials
        for i = (first_val_idx + 1):numel(p_data.trData)
            if isfield(p_data.trData(i), fieldName)
                if ~isequal(size(p_data.trData(i).(fieldName)), first_size)
                    is_consistent = false;
                    fprintf('  --> Detected variable size for trData field: %s\n', fieldName);
                    break;
                end
            end
        end

        trDataFieldsToCopy{end+1} = fieldName;
        if is_consistent && is_numeric
            trialInfo.(fieldName) = nan(nNevTrials, prod(first_size));
        else
            trialInfo.(fieldName) = cell(nNevTrials, 1);
        end
    end
end


% New, robust integration loop
for nevIdx = 1:nNevTrials
    pdsIdx = nev_to_pds_map(nevIdx);

    % Only copy data if a match was found for this NEV trial
    if ~isnan(pdsIdx)
        % Dynamically copy data for fields discovered from p.trVars
        for f = 1:numel(trVarsFieldsToCopy)
            fieldName = trVarsFieldsToCopy{f};
            if isfield(p_data.trVars(pdsIdx), fieldName)
                dataValue = p_data.trVars(pdsIdx).(fieldName);
                if iscell(trialInfo.(fieldName))
                    trialInfo.(fieldName){nevIdx} = dataValue;
                else
                    if isempty(dataValue)
                        trialInfo.(fieldName)(nevIdx, :) = nan(1, size(trialInfo.(fieldName), 2));
                    else
                        trialInfo.(fieldName)(nevIdx, :) = dataValue(:)'; % Ensure row vector
                    end
                end
            end
        end

        % Dynamically copy data for fields discovered from p.trData
        for f = 1:numel(trDataFieldsToCopy)
            fieldName = trDataFieldsToCopy{f};
            if isfield(p_data.trData(pdsIdx), fieldName)
                dataValue = p_data.trData(pdsIdx).(fieldName);
                if iscell(trialInfo.(fieldName))
                    trialInfo.(fieldName){nevIdx} = dataValue;
                else
                    if isempty(dataValue)
                        trialInfo.(fieldName)(nevIdx, :) = nan(1, size(trialInfo.(fieldName), 2));
                    else
                        trialInfo.(fieldName)(nevIdx, :) = dataValue(:)'; % Ensure row vector
                    end
                end
            end
        end

        % Map detailed event timestamps from p.trData.timing
        if isfield(p_data.trData(pdsIdx), 'timing') && ...
                isstruct(p_data.trData(pdsIdx).timing)

            timingData = p_data.trData(pdsIdx).timing;
            timingFields = fieldnames(timingData);

            for t = 1:numel(timingFields)
                pdsFieldName = ['pds' upper(timingFields{t}(1)) timingFields{t}(2:end)];
                % Ensure the field was pre-allocated to avoid typos causing errors
                if isfield(eventTimes, pdsFieldName)
                    eventTimes.(pdsFieldName)(nevIdx) = timingData.(timingFields{t});
                end
            end
        end
    end
end

%% 5. Save Intermediate File
outputFileName = sprintf('%s_intermediate_data.mat', job.unique_id);
outputFilePath = fullfile(intermediateDir, outputFileName);

fprintf('Saving intermediate data to: %s\n', outputFilePath);
try
    save(outputFilePath, 'trialInfo', 'eventTimes', '-v7.3');
    success = true;
    fprintf('Successfully created intermediate data file.\n');
catch ME
    fprintf(2, 'ERROR during behavioral data preparation for %s:\n', job.unique_id); % Print error in red
    fprintf(2, '%s\n', ME.message);
    warning('Execution paused in the debugger. Inspect variables (ME, job, config) and type ''dbcont'' to continue to the next job or ''dbquit'' to exit.');
    keyboard; % Pause execution for debugging
    success = false;
end

end
