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
twoDiff = [diff([0; diff(strobeCategory)]); 0];

% if the final value of "strobeCategory" is different from the value
% immediately before it, change it to match the value immediately before:
if strobeCategory(end) ~= strobeCategory(end-1)
    strobeCategory(end) = strobeCategory(end-1);
end

% look for "-1, 1" or "1, -1" by taking a second diff and looking for
% absolute value of 2:
discontLog = abs(twoDiff) == 2;
end