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

% load each 'trial file' into a struct array:
nTrials = numel(idxTrial);
for iTr = 1:nTrials
    filePath = fullfile(sessionFolder, fileList(idxTrial(iTr)).name);
    tmp = load(filePath);
    
    p.trVars(iTr,1) = tmp.trVars;
    p.trData(iTr,1) = tmp.trData;
end

end