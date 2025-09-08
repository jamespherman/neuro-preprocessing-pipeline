function [trialInfo, eventTimesOutput, eventValuesTrials] = getEventTimes(eventValues, eventTimes)
% GETEVENTTIMES Parses and categorizes trial-based event codes (strobes).
%
% This function takes raw vectors of event codes and their timestamps and
% organizes them into a trial-by-trial format. It uses a robust, multi-
% stage algorithm to demarcate trial boundaries, validate the internal 
% structure of each trial's event data, and handle missing or duplicated 
% strobes.
%
%   Inputs:
%       eventValues - A vector of numerical event codes.
%       eventTimes  - A vector of timestamps for each event code.
%
%   Outputs:
%       trialInfo         - A struct with fields for each info event type.
%                           Includes an 'isLowConfidence' flag for trials
%                           that do not conform to the expected structure.
%       eventTimesOutput  - A struct with fields for each timing event type.
%       eventValuesTrials - A cell array, where each cell contains the raw
%                           event codes for one trial.

% Task 1: Initialization
codes = utils.initCodes;
cats  = utils.initCodeCats;

% Get field names for later use in parsing
codeNames = fieldnames(codes);
codeVals  = cell2mat(struct2cell(codes));

% Initialize main loop pointer and storage for trial boundaries
pointer = 1;
trial_start_indices = [];
trial_end_indices = [];

% Task 2: Iterative Trial Demarcation
while pointer <= length(eventValues)
    % Find the start of the current trial
    start_idx = find(eventValues(pointer:end) == codes.trialBegin, 1, ...
        'first') + pointer - 1;
    if isempty(start_idx)
        % No more trial beginnings found, exit loop
        break;
    end

    % Find the start of the *next* trial to define an upper search boundary
    next_trialBegin_idx = find(eventValues(start_idx + 1:end) == ...
        codes.trialBegin, 1, 'first') + start_idx;

    % Define the search window for the current trial's end
    if isempty(next_trialBegin_idx)
        % This is the last trial, so it extends to the end of the event 
        % stream
        search_until_idx = length(eventValues);
    else
        % The trial must end before the next one begins
        search_until_idx = next_trialBegin_idx - 1;
    end

    % Refine Trial End: Find the *last* trialEnd strobe before the next 
    % trial
    % This handles cases of duplicated trialEnd strobes
    last_trialEnd_idx = find(eventValues(start_idx + ...
        1:search_until_idx) == codes.trialEnd, 1, 'last') + start_idx;

    if isempty(last_trialEnd_idx)
        % Preliminary Trial End: No trialEnd found, so the trial ends 
        % just before the next trial begins (or at the end of the stream).
        end_idx = search_until_idx;
    else
        % Definitive Trial End: A trialEnd was found.
        end_idx = last_trialEnd_idx;
    end

    % Store the demarcated trial boundaries
    trial_start_indices(end+1) = start_idx;
    trial_end_indices(end+1) = end_idx;

    % Update the main loop pointer to the end of the just-found trial
    pointer = end_idx + 1;
end

nTrials = length(trial_start_indices);

% --- Task 3: Trial-by-Trial Verification and Parsing ---

% Pre-allocate the output structures with NaN values.
trialInfo = struct;
eventTimesOutput = struct;
for i = 1:length(codeNames)
    codeName = codeNames{i};
    category = cats.(codeName);
    if category == 0 % Timing event
        eventTimesOutput.(codeName) = nan(nTrials, 1);
    
    % Info event identifier
    elseif category == 1 && ~contains(codeName, 'unique')
        trialInfo.(codeName) = nan(nTrials, 1);
    end
end
% Add a new field to flag trials with non-canonical event structure.
trialInfo.isLowConfidence = false(nTrials, 1);

% Pre-allocate for the raw event values per trial, if requested.
if nargout > 2
    eventValuesTrials = cell(nTrials, 1);
end

% --- Main Parsing Loop ---
for i = 1:nTrials
    % Extract the subsequence of event values and times for this trial.
    trial_idx_range = trial_start_indices(i):trial_end_indices(i);
    trialEventValues = eventValues(trial_idx_range);
    trialEventTimes = eventTimes(trial_idx_range);

    if nargout > 2
        eventValuesTrials{i} = trialEventValues;
    end

    % --- Verify Internal Structure ---

    % 1. Convert event values to a sequence of categories (0=timing, 
    % 1=info).
    [is_known, loc] = ismember(trialEventValues, codeVals);
    category_sequence = nan(size(trialEventValues));
    known_code_names = codeNames(loc(is_known));
    for k = 1:length(known_code_names)
        category_sequence(find(is_known, k, 'first')) = cats.( ...
            known_code_names{k});
    end

     % Assume unknown codes are info *values*.
    category_sequence(isnan(category_sequence)) = 1;

    % 2. Smooth/denoise the category sequence to correct isolated errors.
    % A pattern [1, 0, 1] should become [1, 1, 1]. This occurs where a 
    % 0 has a convolution result of 2.
    change_to_one = conv(category_sequence, [1, -2, 1], 'same') == 2 & ...
    category_sequence == 0;
    category_sequence(change_to_one) = 1;
    % A pattern [0, 1, 0] should become [0, 0, 0]. This occurs where a 1 
    % has a convolution result of -2.
    change_to_zero = conv(category_sequence, [1, -2, 1], 'same') == -2 &...
    category_sequence == 1;
    category_sequence(change_to_zero) = 0;

    % 3. Check for the canonical [0, 0, ... 1, 1] structure.
    % The difference of the sequence should not contain a -1 (i.e., a 1 
    % followed by a 0).
    category_diff = diff(category_sequence);
    if any(category_diff == -1)
        trialInfo.isLowConfidence(i) = true;
    end

    % --- Parse Events ---
    % This logic is reused from the original function's main parsing loop.
    for j = 1:length(trialEventValues)
        codeIdx = find(codeVals == trialEventValues(j), 1);
        if ~isempty(codeIdx)
            codeName = codeNames{codeIdx};
            if any(strcmp(codeName, {'trialBegin', 'trialEnd'}))
                continue; % These are for demarcation, not stored inside 
                % the trial.
            end

            category = cats.(codeName);
            if category == 0
                % Timing strobe: store the timestamp.
                eventTimesOutput.(codeName)(i) = trialEventTimes(j);
            elseif category == 1 && ~contains(codeName, 'unique')
                % Info strobe: the next event value is the data.
                if length(trialEventValues) >= j + 1
                    trialInfo.(codeName)(i) = trialEventValues(j + 1);
                end
            end
        end
    end
end

% Manually add the trial start and end times, which are derived from the
% demarcation loop, not the parsing loop.
eventTimesOutput.trialBegin = eventTimes(trial_start_indices)';
eventTimesOutput.trialEnd = eventTimes(trial_end_indices)';

% --- Task 4: Cleanup ---
% Remove any fields that were pre-allocated but never populated with any
% non-NaN data across all trials.
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