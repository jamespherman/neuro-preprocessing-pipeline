function sessionFileName = catOldOutput(varargin)

% Turn off function handle warning
warningState = warning('off', ...
    'MATLAB:load:cannotInstantiateFunctionHandle');

% if the user supplies a directory, use that, otherwise, prompt user to
% select one:
if nargin < 1
    % prompt user to select a new output directory
    newOutputFolderName = uigetdir('', ...
        'Select an output folder...');
else
    newOutputFolderName = varargin{1};
end

% tell user we're loading data
disp('Loading data...');

% load session's data
q = lp(newOutputFolderName);

% tell user we're saving session's data
disp('Saving session data...');

% save session data
t = find(newOutputFolderName == filesep, 1, 'last');
sessionFileName = [newOutputFolderName(1:t) ...
    newOutputFolderName(t+1:end) '.mat'];
save(sessionFileName, '-struct', 'q');
[~, lmid] = lastwarn;
if strcmp(lmid, 'MATLAB:save:sizeTooBigForMATFile')
    save(sessionFileName, '-v7.3', '-struct', 'q');
end

% tell user we're back to "idle"
disp('Done saving.');

% Restore the original warning state
warning(warningState);

end

function p = lp(sessionFolder)
%   p = lp(sessionFolder)
% 
% loads the output of a pldaps_vK2 session to memory. 
% first it loads the general 'p file' (holds all task info) and then loads
% each 'trial file' into two strcut arrays: trVars & trData, each of length
% nTrials. 
%
% Input:
%   sessionFolder - path to the folder that holds output of the session.
%                   This folder should have one 'p' file and many 'trial'
%                   files, save by saveP.
%   no input      - function will open ui box for you to select a folder.
% 
% Output:
%   single 'p' struct that holds all general and trial-by-trial data.
%
% See also pds.saveP


% find files of interst:

% if session Folder was not provided as input, have user select one:
if ~exist('sessionFolder', 'var')
    [sessionFolder] = uigetdir(pwd, 'Select the session folder you wish to load');
end

% get all files in folder, but only .mat files:
fileList = dir(sessionFolder);
idxMat      = arrayfun(@(x) any(strfind(x.name, '.mat')), fileList);
fileList    = fileList(idxMat);

% get indices to the one 'p' file:
idxP      = find(arrayfun(@(x) any(strfind(x.name, 'p.mat')), fileList));
% get pointer to all 'trial' files:
idxTrial  = find(arrayfun(@(x) any(strfind(x.name, 'trial') & strfind(x.name, '.mat')), fileList));

%% Load'em up:

% load the 'p file' into 'p':
p = load(fullfile(sessionFolder, fileList(idxP).name));

nTrials = numel(idxTrial);

% First pass: discover all field names
all_trVars_fields = {};
all_trData_fields = {};
for iTr = 1:nTrials
    filePath = fullfile(sessionFolder, fileList(idxTrial(iTr)).name);
    trial_data = load(filePath);
    close(findobj('Type', 'Figure'));

    if isfield(trial_data, 'trVars')
        all_trVars_fields = union(all_trVars_fields, fieldnames(trial_data.trVars));
    end
    if isfield(trial_data, 'trData')
        all_trData_fields = union(all_trData_fields, fieldnames(trial_data.trData));
    end
end

% Pre-allocate struct arrays
if ~isempty(all_trVars_fields)
    trVars_template = cell2struct(cell(size(all_trVars_fields)), all_trVars_fields, 1);
    p.trVars = repmat(trVars_template, nTrials, 1);
else
    p.trVars = struct([]);
end

if ~isempty(all_trData_fields)
    trData_template = cell2struct(cell(size(all_trData_fields)), all_trData_fields, 1);
    p.trData = repmat(trData_template, nTrials, 1);
else
    p.trData = struct([]);
end


% Second pass: build the final struct array
for iTr = 1:nTrials
    filePath = fullfile(sessionFolder, fileList(idxTrial(iTr)).name);
    trial_data = load(filePath);
    close(findobj('Type', 'Figure'));

    if isfield(trial_data, 'trVars')
        current_fields = fieldnames(trial_data.trVars);
        for j = 1:numel(current_fields)
            p.trVars(iTr).(current_fields{j}) = trial_data.trVars.(current_fields{j});
        end
    end
    
    if isfield(trial_data, 'trData')
        current_fields = fieldnames(trial_data.trData);
        for j = 1:numel(current_fields)
            p.trData(iTr).(current_fields{j}) = trial_data.trData.(current_fields{j});
        end
    end
end

end