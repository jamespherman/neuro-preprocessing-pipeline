function success = prepare_spikes_for_kilosort(job, config)
% PREPARE_SPIKES_FOR_KILOSORT - Converts raw neural data to a Kilosort-ready .dat file.
%
% This function takes a job's information, loads the corresponding raw .ns5 data,
% extracts the specified channels, and saves the data as a binary .dat file
% in the appropriate Kilosort output directory.
%
% Inputs:
%   job (table row or struct) - A single row from the manifest table.
%   config (struct)           - The pipeline configuration struct.
%
% Outputs:
%   success (logical) - true if the .dat file was created successfully, false otherwise.
%

try
    % 1. Construct Paths
    kilosortOutputDir = fullfile(config.processedDataDir, job.unique_id);
    rawFilePath = fullfile(config.rawNeuralDataDir, ...
        [job.raw_filename_base, '.ns5']);
    datFilePath = fullfile(kilosortOutputDir, [job.unique_id, '.dat']);

    % 2. Create Directory
    if ~exist(kilosortOutputDir, 'dir')
        mkdir(kilosortOutputDir);
    end

    % 3. Load Data
    % 'uv' flag specifies that we want to read the data in microvolts.
    nsxData = utils.openNSx('uv', 'read', char(rawFilePath));

    % 4. Define channelIndices from the manifest.
    channelIndices = str2num(job.channel_numbers);
    manifestProbeType = char(job.probe_type);

    % --- Automated Validation of Channel Ordering ---
    % This section validates that the probe type in the manifest matches
    % the correlation structure of the data. It does this by checking
    % known physical channel layouts. The correct layout should have high
    % correlation between adjacent channels.
    try
        % Take a subset of data for correlation analysis.
        numSamplesForCorr = min(size(nsxData.Data(channelIndices, :), 2), 900000);
        dataSubsetForCorr = nsxData.Data(channelIndices, 1:numSamplesForCorr);
        corrMatrix = corrcoef(double(dataSubsetForCorr'));

        % Define known physical channel orderings for different probes.
        knownOrderings = containers.Map;
        knownOrderings('vProbe')     = [32:-2:2, 31:-2:1];
        knownOrderings('nnVector')   = [17:2:31 18:2:32 2:2:16 1:2:15];
        knownOrderings('orderingA')  = [31:-2:17, 32:-2:18, 16:-2:2, 15:-2:1];
        knownOrderings('orderingB')  = [1:2:31, 2:2:32];

        bestScore = -Inf;
        predictedOrdering = 'None';
        orderingKeys = keys(knownOrderings);

        % Test each known ordering to see which one best explains the data.
        for i = 1:length(orderingKeys)
            key = orderingKeys{i};
            orderingVector = knownOrderings(key);

            if length(orderingVector) == size(corrMatrix, 1)
                
                % Reorder the correlation matrix according to the template.
                reorderedMatrix = corrMatrix(orderingVector, orderingVector);

                % A good match will have high values on the first
                % off-diagonal. We sum this diagonal to get a score.
                score = sum(diag(reorderedMatrix, 1));

                if score > bestScore
                    bestScore = score;
                    predictedOrdering = key;
                end
            end
        end

        % Compare the best-fitting ordering to the one in the manifest.
        if strcmpi(manifestProbeType, predictedOrdering)
            fprintf('Channel order validation passed for %s.\n', ...
                job.unique_id);
        else
            warning('prep:mismatch', ...
                    ['WARNING for %s: Channel order mismatch! Manifest: ', ...
                    '''%s'', but data suggests ''%s''.'], ...
                    job.unique_id, manifestProbeType, predictedOrdering);
        end
    catch valEx
        warning('prep:validationFailed', ...
                'Automated channel order validation failed for %s. Error: %s', ...
                job.unique_id, valEx.message);
    end
    % --- End Validation ---

    % 5. Write .dat File
    fid = fopen(datFilePath, 'w');
    if fid == -1
        error('Could not open file for writing: %s', char(datFilePath));
    end

    % Use the channel ordering specified in the manifest as the source of
    % truth. The validation above serves as a check.
    if isKey(knownOrderings, manifestProbeType)
        finalOrdering = knownOrderings(manifestProbeType);
        % Reorder the data according to the manifest's probe type.
        reorderedData = nsxData.Data(channelIndices(finalOrdering), :);
        fwrite(fid, reorderedData, 'int16');
    else
        % If the probe type is unknown, write in default order and warn.
        warning('prep:unknownProbe', ...
            'Unknown probe type "%s". Writing channels in default order.', ...
            manifestProbeType);
        fwrite(fid, nsxData.Data(channelIndices, :), 'int16');
    end

    fclose(fid);
    success = true;

catch ME
    fprintf(2, 'ERROR during spike preparation for %s:\n', job.unique_id);
    fprintf(2, '%s\n', ME.message);
    warning(['Execution paused. Inspect variables (ME, job, config) ' ...
        'and type ''dbcont'' to continue or ''dbquit'' to exit.']);
    keyboard; % Pause for debugging
    success = false;
end

end
