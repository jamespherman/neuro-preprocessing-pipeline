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

found_flag = false;
p_data = [];

% Iterate through all matching file system items
for i = 1:length(listing)
    item = listing(i);
    itemPath = fullfile(item.folder, item.name);

    matFilePath = '';

    if item.isdir
        % It's a directory, check for a pre-existing .mat file
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
            % Load the 'p' structure specifically
            data = load(matFilePath, 'p');

            % Validate that the 'p' structure exists and has the correct PC name
            if isfield(data, 'p')
                % The PC name field is located at data.p.init.pcName
                if isfield(data.p, 'init') && isfield(data.p.init, 'pcName') && ...
                   strcmp(string(data.p.init.pcName(1:end-1)), job.experiment_pc_name)

                    p_data = data.p;
                    found_flag = true;
                    fprintf('  --> Found and validated matching PLDAPS data.\n');
                    break; % Exit loop once found
                else
                    fprintf('  --> PC name does not match. Skipping.\n');
                end
            else
                fprintf('  --> File does not contain the expected ''p'' structure. Skipping.\n');
            end
        catch ME
            fprintf(2, '  Error loading or checking file %s: %s\n', matFilePath, ME.message);
        end
    end
end

% Final error handling after checking all candidates
if ~found_flag
    fprintf('ERROR: No matching PLDAPS data (file or directory) found for date %s and PC %s.\n', job.date, job.experiment_pc_name);
    return;
end

%% 4. Match Trials and Integrate Data
% The new logic correctly uses p.trVars and p.trData
nPdsTrials = numel(p_data.trVars);
fprintf('Found %d trials in PLDAPS file. Matching with NEV trials...\n', nPdsTrials);

% Trial alignment logic remains the same, but it must handle the case where
% strobed data is not present in the first few trial data structs, which can
% happen if the recording is started mid-session.
pdsTrialOffset = -1;
for offset = 0:min(5, nPdsTrials - 1)
    % Ensure the field exists before trying to access it
    if isfield(p_data.trData, 'strobed') && numel(p_data.trData(1+offset).strobed) > 0
        pdsStrobes = p_data.trData(1+offset).strobed;
        nevStrobes = eventValuesTrials{1};
        if isequal(pdsStrobes(pdsStrobes <= 255), nevStrobes(nevStrobes <= 255))
            pdsTrialOffset = offset;
            fprintf('  Found trial alignment offset: %d\n', pdsTrialOffset);
            break;
        end
    end
end

if pdsTrialOffset == -1
    fprintf('ERROR: Could not align NEV and PLDAPS trial strobes.\n');
    return;
end

nMatchedTrials = min(nNevTrials, nPdsTrials - pdsTrialOffset);
fprintf('Integrating data for %d matched trials.\n', nMatchedTrials);

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
firstValidPdsTrial = 1 + pdsTrialOffset;

% Keep track of fields to populate to avoid re-checking conditions in the loop
trVarsFieldsToCopy = {};
if pdsTrialOffset > -1 && nPdsTrials >= firstValidPdsTrial
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
if pdsTrialOffset > -1 && nPdsTrials >= firstValidPdsTrial
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
for i = 1:nMatchedTrials
    nevIdx = i;
    pdsIdx = i + pdsTrialOffset;

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
