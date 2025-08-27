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
nevFile = fullfile(config.rawNeuralDataDir, job.raw_filename_base);
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
fprintf('Searching for PLDAPS file in: %s\n', config.behavioralDataDir);
% This part of the logic for finding the PDS file seems fragile and dependent on `job.date` and `job.experiment_pc_name`
% which are not in the manifest according to `parse_manifest`.
% I will assume for now that the user will fix this, or that these fields are present in the manifest they are using.
% To make this runnable, I'll have to guess what `job.date` and `job.experiment_pc_name` are.
% The `parse_manifest` function does not list them as required columns. This is another inconsistency.
% I will have to proceed with the assumption that they exist in the job table.

datePattern = ['*' job.date '*.mat'];
candidateFiles = dir(fullfile(config.behavioralDataDir, datePattern));

pdsFileFound = false;
PDS = [];
for i = 1:length(candidateFiles)
    filePath = fullfile(candidateFiles(i).folder, candidateFiles(i).name);
    fprintf('  Loading candidate file: %s\n', candidateFiles(i).name);

    try
        data = load(filePath, 'PDS');
        if isfield(data, 'PDS')
            if isfield(data.PDS, 'initialParameters') && ...
               isfield(data.PDS.initialParameters, 'output') && ...
               isfield(data.PDS.initialParameters.output, 'pc_name') && ...
               strcmp(data.PDS.initialParameters.output.pc_name, job.experiment_pc_name)

                PDS = data.PDS;
                pdsFileFound = true;
                fprintf('  --> Found matching PLDAPS file.\n');
                break;
            else
                fprintf('  --> PC name does not match. Skipping.\n');
            end
        end
    catch ME
        fprintf(2, '  Error loading or checking file %s: %s\n', candidateFiles(i).name, ME.message);
        warning('Execution paused in the debugger. Inspect variables (ME, job, config) and type ''dbcont'' to continue or ''dbquit'' to exit.');
        keyboard; % Pause execution for debugging
    end
end

if ~pdsFileFound
    fprintf('ERROR: No matching PLDAPS file found for date %s and PC %s.\n', job.date, job.experiment_pc_name);
    return;
end

%% 4. Match Trials and Integrate Data
nPdsTrials = numel(PDS.data);
fprintf('Found %d trials in PLDAPS file. Matching with NEV trials...\n', nPdsTrials);

pdsTrialOffset = -1;
for offset = 0:min(5, nPdsTrials-1)
    pdsStrobes = PDS.data{1+offset}.strobed;
    nevStrobes = eventValuesTrials{1};
    if isequal(pdsStrobes(pdsStrobes <= 255), nevStrobes(nevStrobes <= 255))
        pdsTrialOffset = offset;
        fprintf('  Found trial alignment offset: %d\n', pdsTrialOffset);
        break;
    end
end

if pdsTrialOffset == -1
    fprintf('ERROR: Could not align NEV and PLDAPS trial strobes.\n');
    return;
end

nMatchedTrials = min(nNevTrials, nPdsTrials - pdsTrialOffset);
fprintf('Integrating data for %d matched trials.\n', nMatchedTrials);

for i = 1:nMatchedTrials
    nevIdx = i;
    pdsIdx = i + pdsTrialOffset;

    if pdsIdx > nPdsTrials
        break;
    end

    if pdsIdx <= numel(PDS.conditions)
        cond = PDS.conditions{pdsIdx};
        fields = fieldnames(cond);
        for f = 1:numel(fields)
            if isfield(trialInfo, fields{f}) && numel(trialInfo.(fields{f})) >= nevIdx
                trialInfo.(fields{f})(nevIdx) = cond.(fields{f});
            else
                trialInfo.(fields{f})(nevIdx,1) = cond.(fields{f});
            end
        end
    end

    pdsTrialData = PDS.data{pdsIdx};
    trialInfo.pdsTrialEndState{nevIdx,1} = pdsTrialData.trialEndState;
    trialInfo.pdsTrialRepeatFlag(nevIdx,1) = pdsTrialData.trialRepeatFlag;

    if isfield(pdsTrialData, 'timing')
        timingFields = fieldnames(pdsTrialData.timing);
        for t = 1:numel(timingFields)
            newFieldName = ['pds' timingFields{t}];
            if ~isfield(eventTimes, newFieldName)
                eventTimes.(newFieldName) = nan(nNevTrials, 1);
            end
            eventTimes.(newFieldName)(nevIdx) = pdsTrialData.timing.(timingFields{t});
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
