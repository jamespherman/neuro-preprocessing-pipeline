function success = run_preparation(jobInfo, rawDataDir, kilosortParentDir)
% RUN_PREPARATION - Converts raw neural data to a Kilosort-ready .dat file.
%
% This function takes a job's information, loads the corresponding raw .ns5 data,
% extracts the specified channels, and saves the data as a binary .dat file
% in the appropriate Kilosort output directory.
%
% Inputs:
%   jobInfo (table row or struct) - A single row from the manifest table,
%                                   containing metadata for one unique_id.
%   rawDataDir (string)           - The absolute path to the directory containing the raw .ns5 files.
%   kilosortParentDir (string)    - The absolute path to the parent directory for Kilosort output.
%
% Outputs:
%   success (logical) - true if the .dat file was created successfully, false otherwise.
%

try
    % 1. Construct Paths

    kilosortOutputDir = fullfile(kilosortParentDir, jobInfo.unique_id);
    rawFilePath = fullfile(rawDataDir, jobInfo.raw_filename_base + ".ns5");
    datFilePath = fullfile(kilosortOutputDir, jobInfo.unique_id + ".dat");

    % 2. Create Directory
    if ~exist(kilosortOutputDir, 'dir')
        mkdir(kilosortOutputDir);
    end

    % 3. Load Data
    % We will load the entire file, then select channels.
    % The 'c:X' argument in openNSx is for channels, but our channel numbers
    % might not be contiguous, so it's easier to load all and then slice.
    nsxData = utils.openNSx('uv', 'read', char(rawFilePath));

    % 4. Slice Channels
    % The 'channel_numbers' field is a string like '1:32' or '33:64'.
    % Using str2num is safer than eval.
    channelIndices = str2num(jobInfo.channel_numbers);

    % The data from openNSx is in a cell array, with one cell per electrode bank.
    % We assume the data we need is in the first cell nsxData.Data{1}
    % The data matrix is channels x samples.
    slicedData = nsxData.Data{1}(channelIndices, :);

    % --- Automated Validation of Channel Ordering ---
    try
        % Use a subset of data for speed (e.g., 30s at 30kHz)
        numSamplesForCorr = min(size(slicedData, 2), 900000);
        dataSubsetForCorr = slicedData(:, 1:numSamplesForCorr);

        % Compute channel-by-channel correlation
        % Using double for corrcoef is good practice
        corrMatrix = corrcoef(double(dataSubsetForCorr'));

        % Define known physical orderings in a map
        knownOrderings = containers.Map;
        knownOrderings('vProbe')     = [32:-2:2, 31:-2:1];
        knownOrderings('nnVector')   = [17:2:31 18:2:32 2:2:16 1:2:15];
        knownOrderings('orderingA')  = [31:-2:17, 32:-2:18, 16:-2:2, 15:-2:1];
        knownOrderings('orderingB')  = [1:2:31, 2:2:32];

        % Score each known ordering
        bestScore = -Inf;
        predictedOrdering = 'None';
        orderingKeys = keys(knownOrderings);

        for i = 1:length(orderingKeys)
            key = orderingKeys{i};
            orderingVector = knownOrderings(key);

            % Check if this ordering is applicable to the current data's channel count
            if length(orderingVector) == size(corrMatrix, 1)
                reorderedMatrix = corrMatrix(orderingVector, orderingVector);
                % Score by summing the first off-diagonal (correlation of adjacent channels)
                score = sum(diag(reorderedMatrix, 1));

                if score > bestScore
                    bestScore = score;
                    predictedOrdering = key;
                end
            end
        end

        % Validate against the manifest
        manifestProbeType = char(jobInfo.probe_type);
        if strcmpi(manifestProbeType, predictedOrdering)
            fprintf('Channel order validation passed for %s.\n', jobInfo.unique_id);
        else
            warning('prep:run_preparation:mismatch', ...
                    'WARNING for %s: Channel order mismatch! Manifest specifies ''%s'', but data correlation suggests ''%s''.', ...
                    jobInfo.unique_id, manifestProbeType, predictedOrdering);
        end
    catch valEx
        warning('prep:run_preparation:validationFailed', ...
                'Automated channel order validation failed for %s. Error: %s', ...
                jobInfo.unique_id, valEx.message);
    end
    % --- End Validation ---

    % 4a. Reorder Channels based on Probe Type for Kilosort
    % Use ismember with VariableNames for tables, and handle both char and string types.
    hasProbeType = ismember('probe_type', jobInfo.Properties.VariableNames);
    if hasProbeType && (ischar(jobInfo.probe_type) || isstring(jobInfo.probe_type)) && ~isempty(jobInfo.probe_type)
        switch char(jobInfo.probe_type) % Convert to char for switch
            case 'nnVector'
                % NeuroNexus Vector Probe (32-channel)
                reorder_idx = [17:2:31 18:2:32 2:2:16 1:2:15];
                slicedData = slicedData(reorder_idx, :);
            case 'vProbe'
                % V-Probe (32-channel)
                reorder_idx = [32:-2:2, 31:-2:1];
                slicedData = slicedData(reorder_idx, :);
            otherwise
                warning('prep:run_preparation:unknownProbeType', ...
                        'Probe type ''%s'' is not recognized. Channels will not be reordered.', ...
                        char(jobInfo.probe_type));
        end
    else
        warning('prep:run_preparation:noProbeType', ...
                'Probe type not specified in manifest. Channels will not be reordered.');
    end

    % 5. Write .dat File
    % Open file for writing in binary mode
    fid = fopen(datFilePath, 'w');
    if fid == -1
        error('Could not open file for writing: %s', char(datFilePath));
    end

    % Write the data, transposing it to be samples x channels, and casting to int16
    % Kilosort expects the data in column-major order (samples x channels).
    fwrite(fid, slicedData', 'int16');

    % Close the file
    fclose(fid);

    success = true;

catch ME
    % If any error occurs, display it and return false
    fprintf('Error in prep.run_preparation for unique_id %s:\n', char(jobInfo.unique_id));
    fprintf('%s\n', ME.message);
    success = false;
    keyboard
end

end
