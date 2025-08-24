function success = run_preparation(jobInfo, projectRootPath)
% RUN_PREPARATION - Converts raw neural data to a Kilosort-ready .dat file.
%
% This function takes a job's information, loads the corresponding raw .ns5 data,
% extracts the specified channels, and saves the data as a binary .dat file
% in the appropriate Kilosort output directory.
%
% Inputs:
%   jobInfo (table row or struct) - A single row from the manifest table,
%                                   containing metadata for one unique_id.
%   projectRootPath (string)      - The absolute path to the project's root directory.
%
% Outputs:
%   success (logical) - true if the .dat file was created successfully, false otherwise.
%

try
    % 1. Construct Paths
    rawFilePath = fullfile(projectRootPath, jobInfo.raw_filename_base);
    kilosortOutputDir = fullfile(projectRootPath, jobInfo.kilosort_output_dir);
    datFilePath = fullfile(kilosortOutputDir, [jobInfo.unique_id, '.dat']);

    % 2. Create Directory
    if ~exist(kilosortOutputDir, 'dir')
        mkdir(kilosortOutputDir);
    end

    % 3. Load Data
    % We will load the entire file, then select channels.
    % The 'c:X' argument in openNSx is for channels, but our channel numbers
    % might not be contiguous, so it's easier to load all and then slice.
    nsxData = utils.openNSx('read', rawFilePath);

    % 4. Slice Channels
    % The 'channel_numbers' field is a string like '1:32' or '33:64'
    channelIndices = eval(jobInfo.channel_numbers);

    % The data from openNSx is in a cell array, with one cell per electrode bank.
    % We assume the data we need is in the first cell nsxData.Data{1}
    % The data matrix is channels x samples.
    slicedData = nsxData.Data{1}(channelIndices, :);

    % 4a. Reorder Channels based on Probe Type for Kilosort
    if isfield(jobInfo, 'probe_type') && ischar(jobInfo.probe_type) && ~isempty(jobInfo.probe_type)
        switch jobInfo.probe_type
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
                        jobInfo.probe_type);
        end
    else
        warning('prep:run_preparation:noProbeType', ...
                'Probe type not specified in manifest. Channels will not be reordered.');
    end

    % 5. Write .dat File
    % Open file for writing in binary mode
    fid = fopen(datFilePath, 'w');
    if fid == -1
        error('Could not open file for writing: %s', datFilePath);
    end

    % Write the data, transposing it to be samples x channels, and casting to int16
    % Kilosort expects the data in column-major order (samples x channels).
    fwrite(fid, slicedData', 'int16');

    % Close the file
    fclose(fid);

    success = true;

catch ME
    % If any error occurs, display it and return false
    fprintf('Error in prep.run_preparation for unique_id %s:\n', jobInfo.unique_id);
    fprintf('%s\n', ME.message);
    success = false;
end

end
