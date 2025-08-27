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
    rawFilePath = fullfile(config.rawNeuralDataDir, job.raw_filename_base + ".ns5");
    datFilePath = fullfile(kilosortOutputDir, job.unique_id + ".dat");

    % 2. Create Directory
    if ~exist(kilosortOutputDir, 'dir')
        mkdir(kilosortOutputDir);
    end

    % 3. Load Data
    nsxData = utils.openNSx('uv', 'read', char(rawFilePath));

    % 4. Define channelIndices
    channelIndices = str2num(job.channel_numbers);

    % --- Automated Validation of Channel Ordering ---
    try
        numSamplesForCorr = min(size(nsxData.Data(channelIndices, :), 2), 900000);
        dataSubsetForCorr = nsxData.Data(channelIndices, 1:numSamplesForCorr);
        corrMatrix = corrcoef(double(dataSubsetForCorr'));

        knownOrderings = containers.Map;
        knownOrderings('vProbe')     = [32:-2:2, 31:-2:1];
        knownOrderings('nnVector')   = [17:2:31 18:2:32 2:2:16 1:2:15];
        knownOrderings('orderingA')  = [31:-2:17, 32:-2:18, 16:-2:2, 15:-2:1];
        knownOrderings('orderingB')  = [1:2:31, 2:2:32];

        bestScore = -Inf;
        predictedOrdering = 'None';
        orderingKeys = keys(knownOrderings);

        for i = 1:length(orderingKeys)
            key = orderingKeys{i};
            orderingVector = knownOrderings(key);

            if length(orderingVector) == size(corrMatrix, 1)
                reorderedMatrix = corrMatrix(orderingVector, orderingVector);
                score = sum(diag(reorderedMatrix, 1));

                if score > bestScore
                    bestScore = score;
                    predictedOrdering = key;
                end
            end
        end

        manifestProbeType = char(job.probe_type);
        if strcmpi(manifestProbeType, predictedOrdering)
            fprintf('Channel order validation passed for %s.\n', job.unique_id);
        else
            warning('prep:prepare_spikes_for_kilosort:mismatch', ...
                    'WARNING for %s: Channel order mismatch! Manifest specifies ''%s'', but data correlation suggests ''%s''.', ...
                    job.unique_id, manifestProbeType, predictedOrdering);
        end
    catch valEx
        warning('prep:prepare_spikes_for_kilosort:validationFailed', ...
                'Automated channel order validation failed for %s. Error: %s', ...
                job.unique_id, valEx.message);
    end
    % --- End Validation ---

    % 5. Write .dat File
    fid = fopen(datFilePath, 'w');
    if fid == -1
        error('Could not open file for writing: %s', char(datFilePath));
    end

    fwrite(fid, nsxData.Data(channelIndices(knownOrderings(predictedOrdering)), :), 'int16');
    fclose(fid);

    success = true;

catch ME
    fprintf(2, 'ERROR during spike preparation for %s:\n', job.unique_id); % Print error in red
    fprintf(2, '%s\n', ME.message);
    warning('Execution paused in the debugger. Inspect variables (ME, job, config) and type ''dbcont'' to continue to the next job or ''dbquit'' to exit.');
    keyboard; % Pause execution for debugging
    success = false;
end

end
