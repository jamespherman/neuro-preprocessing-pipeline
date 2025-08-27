function success = prepare_behavioral_data(jobInfo, rawDataDir, behavioralDataDir, kilosortParentDir)
% PREPARE_BEHAVIORAL_DATA - Parses .nev event files and integrates them with
% data from PLDAPS behavioral tasks, saving an intermediate file.
%
% This function takes a job from the session manifest, finds the
% corresponding .nev and PLDAPS files, aligns the trial data between them,
% and saves a merged data structure for further processing.
%
% Inputs:
%   jobInfo (table row)      - A single row from the manifest table,
%                              containing metadata for the job.
%   rawDataDir (string)      - Absolute path to the raw data directory
%                              (e.g., 'D:/neuropixels/Data/raw').
%   behavioralDataDir (string) - Absolute path to the behavioral data
%                                directory (e.g., 'D:/neuropixels/Data/behavior').
%   kilosortParentDir (string) - Absolute path to the parent directory
%                                for Kilosort output.
%
% Outputs:
%   success (logical) - true if the intermediate file was created.

% Start with a failure status
success = false;

%% 1. Construct Paths
nevFile = fullfile(rawDataDir, jobInfo.rawDataFile);
kilosortJobDir = fullfile(kilosortParentDir, jobInfo.unique_id);

% Check if the raw .nev file exists
if ~exist(nevFile, 'file')
    fprintf('NEV file not found: %s\n', nevFile);
    return;
end

% Create the Kilosort output directory for this job if it doesn't exist
if ~exist(kilosortJobDir, 'dir')
    mkdir(kilosortJobDir);
end

fprintf('Processing job %s...\n', jobInfo.unique_id);

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
fprintf('Searching for PLDAPS file in: %s\n', behavioralDataDir);
datePattern = ['*' jobInfo.date '*.mat'];
candidateFiles = dir(fullfile(behavioralDataDir, datePattern));

pdsFileFound = false;
PDS = [];
for i = 1:length(candidateFiles)
    filePath = fullfile(candidateFiles(i).folder, candidateFiles(i).name);
    fprintf('  Loading candidate file: %s\n', candidateFiles(i).name);

    try
        data = load(filePath, 'PDS');
        if isfield(data, 'PDS')
            % Check if the PC name matches the one in the manifest
            if isfield(data.PDS, 'initialParameters') && ...
               isfield(data.PDS.initialParameters, 'output') && ...
               isfield(data.PDS.initialParameters.output, 'pc_name') && ...
               strcmp(data.PDS.initialParameters.output.pc_name, jobInfo.experiment_pc_name)

                PDS = data.PDS;
                pdsFileFound = true;
                fprintf('  --> Found matching PLDAPS file.\n');
                break; % Exit loop once the correct file is found
            else
                fprintf('  --> PC name does not match. Skipping.\n');
            end
        end
    catch ME
        fprintf('  Error loading or checking file %s: %s\n', candidateFiles(i).name, ME.message);
    end
end

if ~pdsFileFound
    fprintf('ERROR: No matching PLDAPS file found for date %s and PC %s.\n', jobInfo.date, jobInfo.experiment_pc_name);
    return;
end

%% 4. Match Trials and Integrate Data
nPdsTrials = numel(PDS.data);
fprintf('Found %d trials in PLDAPS file. Matching with NEV trials...\n', nPdsTrials);

% Find offset between NEV and PDS trials. PDS may not save the first few
% trials if they are aborted, or the last few.
pdsTrialOffset = -1;
for offset = 0:min(5, nPdsTrials-1) % Check first few PDS trials
    pdsStrobes = PDS.data{1+offset}.strobed;
    nevStrobes = eventValuesTrials{1};
    % Use isequal after removing any value strobes (typically > 255)
    if isequal(pdsStrobes(pdsStrobes <= 255), nevStrobes(nevStrobes <= 255))
        pdsTrialOffset = offset;
        fprintf('  Found trial alignment offset: %d\n', pdsTrialOffset);
        break;
    end
end

if pdsTrialOffset == -1
    fprintf('ERROR: Could not align NEV and PLDAPS trial strobes.\n');
    % As a fallback, let's try to find the first match anywhere
    for nevStart = 1:min(10, nNevTrials)
        for pdsStart = 1:min(10, nPdsTrials)
             pdsStrobes = PDS.data{pdsStart}.strobed;
             nevStrobes = eventValuesTrials{nevStart};
             if isequal(pdsStrobes(pdsStrobes <= 255), nevStrobes(nevStrobes <= 255))
                 fprintf('WARNING: Found a potential match at NEV trial %d and PDS trial %d. Proceeding with caution.\n', nevStart, pdsStart);
                 % This logic is more complex, for now, we will error out.
                 % In a future version, one could align based on this arbitrary starting point.
                 return;
             end
        end
    end
    return;
end

% Determine the number of trials to integrate
nMatchedTrials = min(nNevTrials, nPdsTrials - pdsTrialOffset);
fprintf('Integrating data for %d matched trials.\n', nMatchedTrials);

% Integrate data for matched trials
for i = 1:nMatchedTrials
    nevIdx = i;
    pdsIdx = i + pdsTrialOffset;

    % Stop if we run out of PDS trials
    if pdsIdx > nPdsTrials
        break;
    end

    % --- Integrate trial parameters into `trialInfo` ---
    if pdsIdx <= numel(PDS.conditions)
        cond = PDS.conditions{pdsIdx};
        fields = fieldnames(cond);
        for f = 1:numel(fields)
            % Check if the field exists to avoid errors if a trial is missing data
            if isfield(trialInfo, fields{f}) && numel(trialInfo.(fields{f})) >= nevIdx
                trialInfo.(fields{f})(nevIdx) = cond.(fields{f});
            else
                trialInfo.(fields{f})(nevIdx,1) = cond.(fields{f});
            end
        end
    end

    % --- Integrate continuous data and detailed timings ---
    pdsTrialData = PDS.data{pdsIdx};

    % Add PDS trial outcome
    trialInfo.pdsTrialEndState{nevIdx,1} = pdsTrialData.trialEndState;
    trialInfo.pdsTrialRepeatFlag(nevIdx,1) = pdsTrialData.trialRepeatFlag;

    % Add PDS timing data to eventTimes struct, prefixed with 'pds'
    if isfield(pdsTrialData, 'timing')
        timingFields = fieldnames(pdsTrialData.timing);
        for t = 1:numel(timingFields)
            newFieldName = ['pds' timingFields{t}];
            % Initialize field if it doesn't exist
            if ~isfield(eventTimes, newFieldName)
                eventTimes.(newFieldName) = nan(nNevTrials, 1);
            end
            eventTimes.(newFieldName)(nevIdx) = pdsTrialData.timing.(timingFields{t});
        end
    end

    % Optionally, add other continuous data if needed in the future
    % For now, we focus on parameters and timings.
    % e.g., trialInfo.eyeX{nevIdx} = pdsTrialData.eyeX;
end

%% 5. Save Intermediate File
outputFileName = sprintf('%s_intermediate_data.mat', jobInfo.unique_id);
outputFilePath = fullfile(kilosortJobDir, outputFileName);

fprintf('Saving intermediate data to: %s\n', outputFilePath);
try
    save(outputFilePath, 'trialInfo', 'eventTimes', '-v7.3');
    success = true;
    fprintf('Successfully created intermediate data file.\n');
catch ME
    fprintf('ERROR: Could not save intermediate data file.\n');
    fprintf('Error message: %s\n', ME.message);
    success = false;
end

end
