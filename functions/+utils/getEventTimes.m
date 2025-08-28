function [trialInfo, eventTimesOutput, eventValuesTrials] = getEventTimes(eventValues, eventTimes)
%
% [trialInfo, eventTimesOutput] = getEventTimes(eventValues, eventTimes)
%
%   Extracts trial information and event times from event values and times.
%   This function outputs two structures: trialInfo, which contains
%   "information strobes" (these strobes indicate that the next strobe
%   value contains the value of a variable used in the just-completed
%   trial) and eventTimesOutput, which contains "normal" strobes (these
%   strobes indicate the timing of an event in the trial, for example:
%   fixation onset, joystick release, stimulus onset, etc.).
%
%   Inputs:
%       eventValues - A vector of event codes (strobes).
%       eventTimes  - A vector of event timestamps corresponding to
%                     eventValues.
%
%   Outputs:
%       trialInfo - A structure containing trial information strobes.
%       eventTimesOutput - A structure containing normal strobe event
%                          times.
%       eventValuesTrials - A cell array containing event values in each trial.

% Define strobe values and strobe value categories:
codes = utils.initCodes;
cats  = utils.initCodeCats;

% Get field names and values for "codes":
codeVals  = cell2mat(struct2cell(codes));
codeNames = fieldnames(codes);

% Make a vector the same length as "eventValues" that has the category
% for each strobe value in "eventValues":
eventCategory = strobeCategory(eventValues, codes, cats);

% Count the number of "trialBegin" and "trialEnd" codes. If these match,
% use them to define trial starts and ends. If they don't, resort to our
% method based on "eventCategory".
trialStartTimes = eventTimes(eventValues == codes.trialBegin);
trialEndTimes   = [trialStartTimes(2:end); eventTimes(end)];
nStarts = length(trialStartTimes);
nEnds   = length(trialEndTimes);
if nStarts > nEnds
    trialEndTimes(end+1) = eventTimes(end);
elseif nStarts < nEnds
    keyboard
end

nTrials = length(trialStartTimes);

% Initialize structures to hold "infoStrobes" and "normalStrobes".
trialInfo = struct;
eventTimesOutput = struct;

% variable for storing each trial's event values:
if nargout > 2
    eventValuesTrials = cell(nTrials,1);
end

% Loop over all the fieldnames in "codes" to categorize strobes:
for i = 1:length(codeNames)
    % Logical expression to determine how the current "code" should be
    % handled:
    if cats.(codeNames{i}) == 0
        % Current code should be stored in "eventTimesOutput"
        eventTimesOutput.(codeNames{i}) = nan(nTrials, 1);
    elseif cats.(codeNames{i}) == 1 && contains(codeNames{i}, 'unique')
        % Skip codes that are values following another "infoStrobe"
    else
        % Current code should be stored in "trialInfo"
        trialInfo.(codeNames{i}) = nan(nTrials, 1);
    end
end

% Loop through every trial to populate the structures
for i = 1:nTrials

    % Logically index all the strobe values that occurred
    % in the currently considered trial based on their timing relative
    % to "trialStartTimes" and "trialEndTimes".
    trialEventsIdx = eventTimes >= trialStartTimes(i) & ...
        eventTimes < trialEndTimes(i);

    % List event values and times of current trial's events
    trialEventValues = eventValues(trialEventsIdx);
    trialEventTimes = eventTimes(trialEventsIdx);

    % Store the event values
    if nargout > 2
        eventValuesTrials{i} = trialEventValues;
    end

    % Loop over every strobe value in the current trial and store it in
    % "infoStrobes" or "normalStrobes" depending on the category of the
    % strobe:
    for j = 1:length(trialEventValues)
        % Determine where the current strobe should be stored. First we
        % logically index "codeVals", indexing where the currently
        % considered strobe value ("trialEventValues(j)") occurs. Since
        % "codeVals" is the same length as "codeName" we retrieve the
        % "codeName" using this logical index (if the strobe value is
        % in our list).
        codeIdx = codeVals == trialEventValues(j);

        % We have to make sure the code value appears in our list
        % before we try to decide where it should be stored. If it
        % doesn't appear in our list, it is likely a strobe value that
        % followed an "infoStrobe", and so has already been stored.
        if any(codeIdx) && ~any(contains({'trialBegin', 'trialEnd'}, ...
                codeNames{codeIdx}))
            % If this strobe is coded as having a value of "0" in
            % "cats" that means it's a "normal" (timing) strobe:
            if cats.(codeNames{codeIdx}) == 0
                % This is a "normal strobe"
                eventTimesOutput.(codeNames{codeIdx})(i) = ...
                    trialEventTimes(j);

                % If this strobe is instead coded as having a value of "1"
                % in "cats" that means it's an "info" strobe.
            elseif cats.(codeNames{codeIdx}) == 1 && ...
                    ~contains(codeNames{codeIdx}, 'unique') && ...
                    length(trialEventValues) >= j + 1
                % This is an "info strobe"
                trialInfo.(codeNames{codeIdx})(i) = ...
                    trialEventValues(j + 1);
            end
        end
    end
end

% handle trial start / stop differently:
eventTimesOutput.trialBegin = trialStartTimes;
eventTimesOutput.trialEnd = trialEndTimes;

% Loop over fieldnames in each structure and remove fields with all NaN
% values. Because we initialized each field of "trialInfo" and
% "eventTimesOutput" structures with arrays of NaNs, any fields that
% are all NaNs are irrelevant - no values have been stored in them
% after looping over all trials. Thus we can remove them. Do this once
% for "trialInfo" (infoStrobes):
tempFieldNames = fieldnames(trialInfo);
for i = 1:length(tempFieldNames)
    if all(isnan(trialInfo.(tempFieldNames{i})))
        trialInfo = rmfield(trialInfo, tempFieldNames{i});
    end
end

% Repeat removing fields with arrays of all NaNs (as described above)
% for the "eventTimesOutput" structure:
tempFieldNames = fieldnames(eventTimesOutput);
for i = 1:length(tempFieldNames)
    if all(isnan(eventTimesOutput.(tempFieldNames{i})))
        eventTimesOutput = rmfield(eventTimesOutput, ...
            tempFieldNames{i});
    end
end
end

function strobeCategory = strobeCategory(strobeValue, codes, cats)

% list fieldnames in "codes" structure:
codeNames = fieldnames(codes);

% make a list of categories for each strobe values, two columns,
% cataegories in the first, strobe value in the second.
catsAndCodes = [cellfun(@(x)cats.(x), codeNames), ...
    cellfun(@(x)codes.(x), codeNames)];

% use 'ismember' to get an indexed list of the rows of "catsAndCodes" where
% we find each element of "strobeValue"; our plan is to use this to index
% the 1st column of "catsAndCodes", thus giving us the "cat":
[codeVals, codeIdx] = ismember(strobeValue, catsAndCodes(:,2));

% make a variable the same size as "strobeValue" to hold the category:
strobeCategory = codeIdx;

% define category values in "strobeCategory" for those entries that we have
% strobe "names" (e.g. not something like a specific variable infostrobe
% value we're strobing).
strobeCategory(codeVals == 1) = catsAndCodes(codeIdx(codeVals == 1), 1);

% define category values for remaining non-strobe-name entries (presumably
% specific variable infoStrobes values following infoStrobes at the end of
% a trial).
strobeCategory(codeVals == 0) = 1;

% it seems that for a couple of "infoStrobes" we need to make sure that
% values following those infoStrobes are set to "1" because those values
% might take on "normalStrobe" values. Define a list of "infoStrobe" names
% here that are known to be problematic:
probInfoNames = codeNames(contains(codeNames, 'Seed'));
probInfoNames{end+1} = 'targetTheta';

% make a list of values corresponding to each of the problematic
% infostrobes:
probInfoVals = cellfun(@(x)codes.(x), probInfoNames);

% list event value locations corresponding to "probInfoNames", and if one
% of them is the final strobe, get rid of that one:
tempInfoLocs = find(ismember(strobeValue, probInfoVals));
tempInfoLocs(tempInfoLocs == length(strobeValue)) = [];

% set strobe values following "seedVals" too "1"
strobeCategory(tempInfoLocs + 1) = 1;

% Check for a lone "0" amidst "1s" and get rid of them. Do this by
% computing the "2nd derrivative" of strobeCategory and looking for values
% of +2. We then recompute "twoDiff" to make sure everything is clean:
twoDiff = [diff([0; diff(strobeCategory)]); 0];
strobeCategory(twoDiff == 2) = 1;
% twoDiff = [diff([0; diff(strobeCategory)]); 0];

% if the final value of "strobeCategory" is different from the value
% immediately before it, change it to match the value immediately before:
if strobeCategory(end) ~= strobeCategory(end-1)
    strobeCategory(end) = strobeCategory(end-1);
end

% look for "-1, 1" or "1, -1" by taking a second diff and looking for
% absolute value of 2:
% discontLog = abs(twoDiff) == 2;
end