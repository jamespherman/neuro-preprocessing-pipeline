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
intermediateDir = config.processedDataDir;

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
        if numel(matFilesInDir) < 25
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
            fprintf(2, '  Error loading or checking file %s: %s\n', matFilePath, ME.message);
        end
    end
end

% Final error handling after checking all candidates
if isempty(valid_p_structs)
    fprintf('ERROR: No matching PLDAPS data (file or directory) found for date %s and PC %s.\n', job.date, job.experiment_pc_name);
    return;
end

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
    args_vars = reshape([all_trVars_fields; cell(1, numel(all_trVars_fields))], 1, []);
    if ~isempty(args_vars)
        p_data.trVars = repmat(struct(args_vars{:}), total_trials, 1);
    else
        p_data.trVars = [];
    end

    % Create empty struct arrays with all fields for trData
    args_data = reshape([all_trData_fields; cell(1, numel(all_trData_fields))], 1, []);
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

% Pre-allocate dynamically discovered fields in eventTimes
fprintf('  Pre-allocating %d dynamically discovered timing fields...\n', numel(allTimingFields));
for f = 1:numel(allTimingFields)
    fieldName = allTimingFields{f};
    pdsFieldName = ['pds' upper(fieldName(1)) fieldName(2:end)];
    eventTimes.(pdsFieldName) = nan(nNevTrials, 1);
end


% --- Dynamic pre-allocation for trialInfo table from p.trVars and p.trData ---
existingTrialInfoFields = trialInfo.Properties.VariableNames;

% Find the first PDS trial that has a corresponding NEV trial
firstValidPdsIdx = find(~isnan(nev_to_pds_map), 1);
if ~isempty(firstValidPdsIdx)
    firstValidPdsTrial = nev_to_pds_map(firstValidPdsIdx);
else
    firstValidPdsTrial = []; % Handle case with no matches
end

% Keep track of fields to populate to avoid re-checking conditions in the loop
trVarsFieldsToCopy = {};
if ~isempty(firstValidPdsTrial)
    allTrVarsFields = fieldnames(p_data.trVars(firstValidPdsTrial));
    fprintf('  Pre-allocating fields from p.trVars...\n');
    for f = 1:numel(allTrVarsFields)
        fieldName = allTrVarsFields{f};
        if ~ismember(fieldName, existingTrialInfoFields)
            trVarsFieldsToCopy{end+1} = fieldName; % Add to copy list
            sampleData = p_data.trVars(firstValidPdsTrial).(fieldName);
            if isnumeric(sampleData) || islogical(sampleData)
                trialInfo.(fieldName) = nan(nNevTrials, numel(sampleData));
            else
                trialInfo.(fieldName) = cell(nNevTrials, 1);
            end
        end
    end
end

trDataFieldsToCopy = {};
if ~isempty(firstValidPdsTrial)
    allTrDataFields = fieldnames(p_data.trData(firstValidPdsTrial));
    fprintf('  Pre-allocating non-structural fields from p.trData...\n');
    for f = 1:numel(allTrDataFields)
        fieldName = allTrDataFields{f};
        if ~ismember(fieldName, existingTrialInfoFields) && ~strcmp(fieldName, 'timing')
            sampleData = p_data.trData(firstValidPdsTrial).(fieldName);
            if ~isstruct(sampleData)
                trDataFieldsToCopy{end+1} = fieldName; % Add to copy list
                if isnumeric(sampleData) || islogical(sampleData)
                    trialInfo.(fieldName) = nan(nNevTrials, numel(sampleData));
                else
                    trialInfo.(fieldName) = cell(nNevTrials, 1);
                end
            end
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
