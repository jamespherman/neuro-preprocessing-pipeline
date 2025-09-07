function [trialInfo, eventTimesOutput, eventValuesTrials] = getEventTimes(eventValues, eventTimes)
% GETEVENTTIMES Parses and categorizes trial-based event codes (strobes).
%
% This function takes raw vectors of event codes and their timestamps and
% organizes them into a trial-by-trial format. It separates events into two
% main categories:
%   - Timing Events: Mark the time of an occurrence (e.g., fixOn, targOn).
%     These are stored in the 'eventTimesOutput' struct.
%   - Information Events: A two-part strobe where the first code identifies
%     a variable, and the second code is the value of that variable (e.g.,
%     trialCount, targetDirection). These values are stored in 'trialInfo'.
%
%   Inputs:
%       eventValues - A vector of numerical event codes.
%       eventTimes  - A vector of timestamps for each event code.
%
%   Outputs:
%       trialInfo         - A struct with fields for each info event type.
%       eventTimesOutput  - A struct with fields for each timing event type.
%       eventValuesTrials - A cell array, where each cell contains the raw
%                           event codes for one trial.

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
    error('getEventTimes:MismatchedTrials', ...
        'Fewer trial starts than trial ends detected.');
end

nTrials = length(trialStartTimes);

% Initialize structures to hold "infoStrobes" and "normalStrobes".
trialInfo = struct;
eventTimesOutput = struct;

% variable for storing each trial's event values:
if nargout > 2
    eventValuesTrials = cell(nTrials,1);
end

% Loop over all defined codes to pre-allocate fields in the output structs.
for i = 1:length(codeNames)
    codeName = codeNames{i};
    category = cats.(codeName);

    if category == 0
        % Category 0 corresponds to a timing event.
        eventTimesOutput.(codeName) = nan(nTrials, 1);
    elseif category == 1 && ~contains(codeName, 'unique')
        % Category 1 is an info event. 'unique' codes are the values
        % themselves, not the identifiers, so they don't get fields.
        trialInfo.(codeName) = nan(nTrials, 1);
    end
end

% --- Main Parsing Loop ---
% Loop through every trial to populate the pre-allocated structures.
for i = 1:nTrials
    % Get all events that occurred within the start and end times of this trial.
    trialEventsIdx = eventTimes >= trialStartTimes(i) & ...
                     eventTimes < trialEndTimes(i);
    trialEventValues = eventValues(trialEventsIdx);
    trialEventTimes = eventTimes(trialEventsIdx);

    if nargout > 2
        eventValuesTrials{i} = trialEventValues;
    end

    % Loop over every event in the current trial.
    for j = 1:length(trialEventValues)
        % Find the name of the current event code.
        codeIdx = find(codeVals == trialEventValues(j), 1);

        % If the code is a known identifier (not a value that follows an
        % info strobe), then process it.
        if ~isempty(codeIdx)
            codeName = codeNames{codeIdx};
            % Skip trial start/end codes as they are handled separately.
            if any(strcmp(codeName, {'trialBegin', 'trialEnd'}))
                continue;
            end

            category = cats.(codeName);
            if category == 0
                % Timing strobe: store the timestamp.
                eventTimesOutput.(codeName)(i) = trialEventTimes(j);
            elseif category == 1 && ~contains(codeName, 'unique')
                % Info strobe: the next event value is the data.
                % Check for out-of-bounds access.
                if length(trialEventValues) >= j + 1
                    trialInfo.(codeName)(i) = trialEventValues(j + 1);
                end
            end
        end
    end
end

% Manually add the trial start and end times.
eventTimesOutput.trialBegin = trialStartTimes;
eventTimesOutput.trialEnd = trialEndTimes;

% --- Cleanup ---
% Remove any fields that were pre-allocated but never filled with data.
tempFieldNames = fieldnames(trialInfo);
for i = 1:length(tempFieldNames)
    if all(isnan(trialInfo.(tempFieldNames{i})))
        trialInfo = rmfield(trialInfo, tempFieldNames{i});
    end
end

tempFieldNames = fieldnames(eventTimesOutput);
for i = 1:length(tempFieldNames)
    if all(isnan(eventTimesOutput.(tempFieldNames{i})))
        eventTimesOutput = rmfield(eventTimesOutput, tempFieldNames{i});
    end
end
end

function strobeCategory = strobeCategory(strobeValue, codes, cats)
% STROBECATEGORY (Helper) Determines the category of each strobe code.
%
% This function is a legacy helper that attempts to classify each raw
% event value as either a timing strobe (0) or an info strobe (1). It has
% complex logic to handle cases where the value of an info strobe might be
% the same as a known timing strobe code.

% Get the names of all defined strobe codes.
codeNames = fieldnames(codes);

% Create a mapping from strobe numerical value to its category (0 or 1).
catsAndCodes = [cellfun(@(x)cats.(x), codeNames), ...
                cellfun(@(x)codes.(x), codeNames)];

% For each event in the input strobeValue vector, find its corresponding
% category from the map.
[isKnownCode, codeIdx] = ismember(strobeValue, catsAndCodes(:,2));

% Initialize the output category vector.
strobeCategory = codeIdx;

% For known codes, assign their predefined category.
strobeCategory(isKnownCode) = catsAndCodes(codeIdx(isKnownCode), 1);

% For unknown codes (values that are not in our 'codes' list), assume they
% are the second part of an "info strobe" and assign them category 1.
strobeCategory(isKnownCode == 0) = 1;

% --- Special Case Handling ---
% The following logic attempts to correct for cases where a data value
% (which should be category 1) is the same as a timing code (category 0).
% It identifies "problematic" info strobes (like random seeds) whose
% values are likely to conflict with timing codes.
probInfoNames = codeNames(contains(codeNames, 'Seed'));
probInfoNames{end+1} = 'targetTheta';
probInfoVals = cellfun(@(x)codes.(x), probInfoNames);

% Find the locations of these problematic info strobes.
tempInfoLocs = find(ismember(strobeValue, probInfoVals));
% Ensure we don't go past the end of the strobe list.
tempInfoLocs(tempInfoLocs == length(strobeValue)) = [];

% Force the category of the value *following* these strobes to be 1.
strobeCategory(tempInfoLocs + 1) = 1;

% Another correction: find any isolated '0's surrounded by '1's and flip
% them to '1'. This is done by looking at the second derivative of the
% category vector. A pattern of [1, 0, 1] will result in a value of 2 in
% the second derivative at the position of the '0'.
twoDiff = [diff([0; diff(strobeCategory)]); 0];
strobeCategory(twoDiff == 2) = 1;

% Final cleanup: if the last category is different from the second to last,
% make them match. This handles cases where a trial ends mid-strobe.
if strobeCategory(end) ~= strobeCategory(end-1)
    strobeCategory(end) = strobeCategory(end-1);
end
end