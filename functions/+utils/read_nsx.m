function out = read_nsx(filename,varargin)
% READ_NSX Reads data from a Blackrock .nsx file (pure MATLAB).
%
%   This function is based on Ripple's NSX2MAT and is designed to read any
%   NSx file (specifically version 2.2). It is a MATLAB-only alternative
%   to the faster, compiled openNSx function.
%
%   SYNTAX:
%   out = read_nsx(filename, 'begsample', 1, 'endsample', 1000, 'chanindx', 1:32)
%
%   INPUTS:
%   filename   - A string containing the full path to the .nsx file.
%
%   OPTIONAL NAME-VALUE PAIR INPUTS:
%   'begsample'  - The starting sample number to read. DEFAULT: 1.
%   'endsample'  - The ending sample number to read. DEFAULT: -1 (to end).
%   'chanindx'   - A numeric vector of channel indices to read.
%                  DEFAULT: -1 (all channels).
%   'readdata'   - A logical flag. If true, reads data; if false, reads
%                  only the header. DEFAULT: true.
%   'keepint'    - A logical flag. If true, keeps data as int16; otherwise,
%                  converts to double and scales to physical units.
%                  DEFAULT: false.
%   'allowpause' - A logical flag. If true, allows reading data segments
%                  that contain a pause, filling the gap with NaNs.
%                  DEFAULT: false (throws an error if a pause is found).
%
%   OUTPUTS:
%   out        - A structure containing the header and data.
%                out.hdr: A structure with header information (Fs, nChans, etc.).
%                out.data: A [channels x samples] matrix of the neural data.

%% Ignore MATLAB's complaints about code optimization in this legacy file.
%#ok<*NASGU>
%#ok<*AGROW>

%% Parse Optional Arguments
p = inputParser;
p.addRequired('filename', @ischar);
p.addOptional('begsample', 1, @isscalar);
p.addOptional('endsample', -1, @isscalar);
p.addOptional('chanindx', -1, @isnumeric);
p.addOptional('readdata', true, @islogical);
p.addOptional('keepint', false, @islogical);
p.addOptional('allowpause', false, @islogical);
p.parse(filename, varargin{:});

begsample = p.Results.begsample;
endsample = p.Results.endsample;
chanindx = p.Results.chanindx;
readdata = p.Results.readdata;
keepint = p.Results.keepint;
allowpause = p.Results.allowpause;

packetHeaderBytes = 9;

%% Open File & Read Header
fh = fopen(filename, 'rb', 'n', 'UTF-8');
fseek(fh, 0, 'eof');
filesize = ftell(fh);
fseek(fh, 0, 'bof');

% Check for 'NEURALCD' identifier for NSx 2.2.
fid = fread(fh, 8, '*char')';
if ~strcmp(fid, 'NEURALCD')
    error('read_nsx:InvalidFile', 'Not a valid NSx 2.2 file.');
end

fseek(fh, 2, 'cof'); % Skip file spec
bytesInHeaders = fread(fh, 1, '*uint32');
label = fread(fh, 16, '*char')';
fseek(fh, 256, 'cof'); % Seek past comment field
period = fread(fh, 1, '*uint32');
fs = 30000 / period; % Sampling frequency in Hz
clockFs = fread(fh, 1, '*uint32');
timeOriginRaw = fread(fh, 8, 'uint16=>double');
dateVector = timeOriginRaw([1,2,4,5,6,7]);
dateVector(end) = dateVector(end) + timeOriginRaw(end)/1000;
timeOrigin = datestr(dateVector(:)', 'dd-mmm-yyyy HH:MM:SS.FFF');

%% Get Channel Info
chanCount = fread(fh, 1, '*uint32');
scale = zeros(chanCount, 1);
channelID = int16(scale);
unit = cell(chanCount, 1);
fseek(fh, 2, 'cof'); % Skip reserved bytes

for i = 1:chanCount
    channelID(i) = fread(fh, 1, '*uint16');
    fseek(fh, 18, 'cof'); % Skip label and connector bank/pin
    minD = fread(fh, 1, 'int16');
    maxD = fread(fh, 1, 'int16');
    minA = fread(fh, 1, 'int16');
    maxA = fread(fh, 1, 'int16');
    unit(i) = {deblank(fread(fh, 16, '*char')')};
    scale(i) = (maxA - minA) / (maxD - minD);
    fseek(fh, 22, 'cof'); % Skip to next channel entry
end
chanLabels = cellfun(@num2str, num2cell(double(channelID)), 'UniformOutput', 0);
fseek(fh, bytesInHeaders, 'bof');

%% Read Data Packet Timestamps
% This loop reads the header of each data packet to determine its start
% time and duration. This is necessary to handle paused recordings.
timeStamp = [];
ndataPoints = [];
k = 1;
while (filesize - ftell(fh)) > packetHeaderBytes
    header = fread(fh, 1);
    timeStamp(k) = fread(fh, 1, '*uint32');
    ndataPoints(k) = fread(fh, 1, '*uint32');

    if ndataPoints(k) == 0
        warning('read_nsx:fileInterrupted', ...
            'File %s may be interrupted; attempting data recovery.', filename);
        remainingBytes = filesize - ftell(fh);
        ndataPoints(k) = uint32(floor(0.5 * remainingBytes / double(chanCount)));
    end

    status = fseek(fh, (2 * double(ndataPoints(k)) * double(chanCount)), 'cof');
    if status < 0
        warning('read_nsx:fileCorrupted', ...
            'Corrupted file %s has invalid packet info.', filename);
        fseek(fh, bytesInHeaders + packetHeaderBytes, 'bof');
        remainingBytes = filesize - (double(bytesInHeaders) + packetHeaderBytes);
        ndataPoints = uint32(floor(0.5 * remainingBytes / double(chanCount)));
        timeStamp = timeStamp(1);
        break;
    else
        k = k + 1;
    end
end
time = [timeStamp; timeStamp + ndataPoints .* period];

%% Read Data
if readdata
    nvec = double(cumsum(double(ndataPoints)));
    nvec = [0, nvec];
    if endsample < 0
        endsample = nvec(end);
    end

    data = zeros(chanCount, endsample - begsample + 1, 'int16');
    if any(chanindx < 0), chanindx = 1:chanCount; end

    fseek(fh, bytesInHeaders, 'bof');
    bytes2skip = max((begsample - 1) * 2 * double(chanCount), 0);
    bytes2skip = bytes2skip + packetHeaderBytes * sum(begsample > nvec);
    fseek(fh, bytes2skip, 'cof');

    % This logic determines if the requested data segment contains pauses.
    % 'puntForPauses' is true if a specific segment is requested, which
    % implies pauses should not be handled by default.
    puntForPauses = endsample > 0;

    % Find the boundaries of data blocks within the requested segment.
    dataBlockBounds = nvec > begsample & nvec < endsample;

    if length(dataBlockBounds) == 2 && ~any(dataBlockBounds)
        % Case 1: No pauses within the requested data segment.
        % Read the data in a single block.
        data = fread(fh, [chanCount, endsample - begsample + 1], '*int16');
    else
        % Case 2: Pauses were detected in the file.
        if ~puntForPauses || allowpause
            % Read data block by block, skipping packet headers.
            endByte = packetHeaderBytes * sum(dataBlockBounds) + (endsample * 2 * chanCount);
            currentSample = begsample;
            dataInd = 1;
            while ftell(fh) < endByte
                nextBound = nvec(find(nvec > currentSample, 1, 'first'));
                nextBound = min(nextBound, endsample);
                readSize = nextBound - currentSample + 1;
                if readSize > 0
                    data(:, dataInd:dataInd + readSize - 1) = ...
                        fread(fh, [chanCount, readSize], '*int16');
                    dataInd = dataInd + readSize;
                end
                currentSample = nextBound + 1;
                if ftell(fh) < (filesize - packetHeaderBytes)
                    fseek(fh, packetHeaderBytes, 'cof');
                end
            end
        else
            error('read_nsx:pauseInRequestedTrial', ...
                ['The NSX file %s was paused during the requested data ', ...
                'segment (samples %d to %d). Use ''allowpause'', true to override.'], ...
                filename, begsample, endsample);
        end
    end

    % Convert data to physical units if requested.
    if ~keepint
        out.data = bsxfun(@times, double(data(chanindx,:)), double(scale(chanindx)));
    else
        out.data = data;
    end
end

%% Package Output
hdr.Fs = fs;
hdr.nChans = chanCount;
hdr.nSamples = max(nvec);
hdr.label = chanLabels;
hdr.chanunit = unit(:);
hdr.scale = scale;
hdr.timeStamps = double(time);
hdr.clockFs = double(clockFs);
hdr.timeOrigin = timeOrigin;

out.hdr = hdr;

fclose(fh);
end
