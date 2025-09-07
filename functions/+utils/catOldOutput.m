function sessionFileName = catOldOutput(varargin)
% CATOLDOUTPUT Consolidates a directory of loose trial files into one .mat file.
%
% This function is designed to handle an older PLDAPS data format where
% each trial was saved as a separate .mat file. It loads all trial files,
% merges them into a single structure, and saves it as a session file.

% Temporarily turn off a warning that can occur when loading data
% containing old function handles.
warningState = warning('off', ...
    'MATLAB:load:cannotInstantiateFunctionHandle');

% If no directory is provided, prompt the user to select one.
% Note: For pipeline use, a path should always be provided.
if nargin < 1
    newOutputFolderName = uigetdir('', 'Select an output folder...');
else
    newOutputFolderName = varargin{1};
end

disp('Loading and collating trial data...');
% Use the helper function to load and merge all trial data.
sessionData = load_and_collate_trials(newOutputFolderName);

disp('Saving consolidated session data...');
% Construct the output filename based on the directory name.
lastFileSepIdx = find(newOutputFolderName == filesep, 1, 'last');
sessionFileName = [newOutputFolderName(1:lastFileSepIdx), ...
    newOutputFolderName(lastFileSepIdx+1:end), '.mat'];

% Save the consolidated data.
save(sessionFileName, '-struct', 'sessionData');

% Check if the save command produced a "size too big" warning.
% If so, re-save using the -v7.3 flag which supports larger files.
[~, lastWarnId] = lastwarn;
if strcmp(lastWarnId, 'MATLAB:save:sizeTooBigForMATFile')
    fprintf('File size is large. Re-saving with -v7.3 flag...\n');
    save(sessionFileName, '-v7.3', '-struct', 'sessionData');
end

disp('Done saving.');
% Restore the original warning state.
warning(warningState);
end

function p = load_and_collate_trials(sessionFolder)
% LOAD_AND_COLLATE_TRIALS Helper function to load and merge trial files.
%
% This function finds the main 'p.mat' file and all 'trial*.mat' files
% within a session folder, then collates them into a single structure.

% Find all .mat files in the specified session folder.
fileList = dir(fullfile(sessionFolder, '*.mat'));

% Find the main 'p.mat' file, which contains session-level parameters.
idxP = find(strcmp({fileList.name}, 'p.mat'));
if isempty(idxP)
    error('Could not find the main "p.mat" file in %s.', sessionFolder);
elseif numel(idxP) > 1
    error('Found multiple "p.mat" files in %s.', sessionFolder);
end

% Find all individual 'trial*.mat' files.
isTrialFile = startsWith({fileList.name}, 'trial');
idxTrial = find(isTrialFile);
nTrials = numel(idxTrial);

% Load the main 'p' structure.
p = load(fullfile(sessionFolder, fileList(idxP).name));

% --- Efficiently merge trial data ---
% First pass: Discover all unique field names across all trial files
% for both 'trVars' and 'trData' structures.
all_trVars_fields = {};
all_trData_fields = {};
for iTr = 1:nTrials
    filePath = fullfile(sessionFolder, fileList(idxTrial(iTr)).name);
    trial_data = load(filePath);

    % Loading a trial file might create a figure; close it immediately.
    close(findobj('Type', 'Figure'));

    if isfield(trial_data, 'trVars')
        all_trVars_fields = union(all_trVars_fields, ...
            fieldnames(trial_data.trVars));
    end
    if isfield(trial_data, 'trData')
        all_trData_fields = union(all_trData_fields, ...
            fieldnames(trial_data.trData));
    end
end

% Pre-allocate the structure arrays for performance. This avoids resizing
% the array in a loop, which can be very slow in MATLAB.
if ~isempty(all_trVars_fields)
    trVars_template = cell2struct(cell(size(all_trVars_fields)), ...
        all_trVars_fields, 1);
    p.trVars = repmat(trVars_template, nTrials, 1);
else
    p.trVars = struct([]);
end

if ~isempty(all_trData_fields)
    trData_template = cell2struct(cell(size(all_trData_fields)), ...
        all_trData_fields, 1);
    p.trData = repmat(trData_template, nTrials, 1);
else
    p.trData = struct([]);
end

% Second pass: Populate the pre-allocated structure arrays.
for iTr = 1:nTrials
    filePath = fullfile(sessionFolder, fileList(idxTrial(iTr)).name);
    trial_data = load(filePath);
    close(findobj('Type', 'Figure')); % Close any stray figures.

    % Copy fields from the loaded trial's trVars.
    if isfield(trial_data, 'trVars')
        current_fields = fieldnames(trial_data.trVars);
        for j = 1:numel(current_fields)
            p.trVars(iTr).(current_fields{j}) = ...
                trial_data.trVars.(current_fields{j});
        end
    end
    
    % Copy fields from the loaded trial's trData.
    if isfield(trial_data, 'trData')
        current_fields = fieldnames(trial_data.trData);
        for j = 1:numel(current_fields)
            p.trData(iTr).(current_fields{j}) = ...
                trial_data.trData.(current_fields{j});
        end
    end
end
end