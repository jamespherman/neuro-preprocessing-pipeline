function strobeCategory = strobeCategory(strobeValue, codes, cats)
% STROBECATEGORY Determines the category of each strobe code (legacy).
%
% This function is a legacy helper that attempts to classify each raw
% event value as either a timing strobe (0) or an info strobe (1). It has
% complex logic to handle cases where the value of an info strobe might be
% the same as a known timing strobe code.
%
%   Inputs:
%       strobeValue - A vector of numerical event codes.
%       codes       - A struct mapping code names to numerical values.
%       cats        - A struct mapping code names to categories (0 or 1).
%
%   Outputs:
%       strobeCategory - A vector of the same size as strobeValue, with
%                        the determined category for each value.

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