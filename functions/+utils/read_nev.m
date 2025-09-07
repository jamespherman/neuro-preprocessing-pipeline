function [spike, waves] = read_nev(nevfile, varargin)
% READ_NEV Reads spike and event data from a Blackrock .nev file (pure MATLAB).
%
%   This function parses a .nev file to extract event codes, timestamps,
%   and optionally, spike waveforms. It is a MATLAB-only alternative to the
%   faster, compiled readNEV.mex function.
%
%   SYNTAX:
%   [spike, waves] = read_nev(nevfile, 'channels', 1:32, 'waveFormat', 'uvolt')
%
%   INPUTS:
%   nevfile    - A string containing the full path to the .nev file.
%
%   OPTIONAL NAME-VALUE PAIR INPUTS:
%   'channels'   - A numeric vector specifying which channel IDs to read.
%                  If empty or not provided, all channels are read.
%                  DEFAULT: []
%   'waveFormat' - A string specifying the format for output waveforms.
%                  'uvolt' (default): double precision, in microvolts.
%                  'uvoltint': int16, converted to microvolts.
%                  'rawint': int16, raw values, not converted.
%
%   OUTPUTS:
%   spike      - An Nx3 matrix where each row is an event. The columns are:
%                1: Channel ID (0 for digital events)
%                2: Spike classification unit (or digital value for events)
%                3: Timestamp of the event in seconds.
%   waves      - (Optional) A cell array containing the spike waveforms.

%% Parse Optional Arguments
p = inputParser;
p.addOptional('channels', [], @isnumeric);
p.addOptional('waveFormat', 'uvolt', @ischar);
p.parse(varargin{:});

requestedChannels = p.Results.channels;
waveFormat = p.Results.waveFormat;
waveson = (nargout > 1);

if isempty(requestedChannels)
    readAllChannels = true;
else
    readAllChannels = false;
end

%% Open File and Read Header
disp('Reading NEV file...');
fid = fopen(nevfile, 'r', 'l', 'UTF-8');

% Basic Header
identifier = fscanf(fid, '%8s', 1); % Should be 'NEURALEV'
filespec = fread(fid, 2, 'uchar');
version = sprintf('%d.%d', filespec(1), filespec(2));
fileformat = fread(fid, 2, 'uchar');
headersize = fread(fid, 1, 'ulong');
datapacketsize = fread(fid, 1, 'ulong');
stampfreq = fread(fid, 1, 'ulong');
samplefreq = fread(fid, 1, 'ulong');

% Timestamp of when the file was created
time = fread(fid, 8, 'uint16');
year = time(1); month = time(2); day = time(4);
hour = time(5); minute = time(6); second = time(7);
% disp(sprintf('%d/%d/%d %d:%d:%d', month, day, year, hour, minute, second));

% Acquisition system info
application = fread(fid, 32, 'uchar')';
comments = fread(fid, 256, 'uchar')';
ExtendedHeaderNumber = fread(fid, 1, 'ulong');

%% Read Extended Headers
% This section reads metadata for each channel, like digital-to-analog
% conversion factors and filter settings.
nVperBit = [];
for i = 1:ExtendedHeaderNumber
    Identifier = char(fread(fid, 8, 'char'))';
    % This only fully parses NEUEVWAV type extended headers.
    % TODO: Add support for other extended header types if needed.
    switch Identifier
        case 'NEUEVWAV'
            ElecID = fread(fid, 1, 'uint16');
            PhysConnect = fread(fid, 1, 'uchar');
            PhysConnectPin = fread(fid, 1, 'uchar');
            nVperBit(ElecID) = fread(fid, 1, 'uint16');
            EnergyThresh = fread(fid, 1, 'uint16');
            HighThresh(ElecID) = fread(fid, 1, 'int16');
            LowThresh(ElecID) = fread(fid, 1, 'int16');
            SortedUnits = fread(fid, 1, 'uchar');
            BytesPerSample = ((fread(fid, 1, 'uchar')) > 1) + 1;
            fread(fid, 10, 'uchar'); % Skip reserved bytes
        otherwise
            % For unknown header types, just skip the 24 bytes.
            fread(fid, 24, 'uchar');
    end
end

%% Read Data Packets
fseek(fid, 0, 'eof');
nBytesInFile = ftell(fid);
nPacketsInFile = (nBytesInFile - headersize) / datapacketsize;
fseek(fid, headersize, 'bof');

% Pre-allocate arrays for speed. They will be truncated later.
spike = zeros(nPacketsInFile, 3);
if waveson
    waves = cell(nPacketsInFile, 1);
end

fprintf('%% Complete: ');
m = 1; % Counter for valid packets
while ~feof(fid)
    % Reading the entire packet at once is faster than multiple small reads.
    packetData = fread(fid, datapacketsize, 'uint8=>uint8');
    if isempty(packetData), break; end
    
    timestamp = double(typecast(packetData(1:4), 'uint32'));
    electrode = typecast(packetData(5:6), 'uint16');
    
    % If a channel list was provided, check if this packet is from one
    % of the requested channels.
    if readAllChannels || ismember(electrode, requestedChannels)
        if (electrode == 0)
            % This is a digital event packet.
            class = typecast(packetData(9:10), 'uint16'); % Digital value
            spike(m, 1) = 0;
            spike(m, 2) = class;
            spike(m, 3) = (timestamp / samplefreq);
            m = m + 1;
        else
            % This is a spike event packet.
            class = packetData(7); % Spike classification unit
            if (waveson)
                waveform_raw = typecast(packetData(9:datapacketsize), 'int16');
                uvolt_conversion = double(nVperBit(electrode)) * 0.001;

                switch waveFormat
                    case 'uvolt'
                        waves{m} = double(waveform_raw) .* uvolt_conversion;
                    case 'rawint'
                        waves{m} = waveform_raw;
                    case 'uvoltint' % Note: This results in non-integer values.
                        waves{m} = waveform_raw .* uvolt_conversion;
                    otherwise
                        error('Invalid Wave Format specified.');
                end
            end

            % Store the spike time, class, and channel.
            spike(m, 1) = electrode;
            spike(m, 2) = class;
            spike(m, 3) = timestamp / samplefreq;
            m = m + 1;
        end
    end
end
fprintf('\nFinished reading NEV file.\n');

%% Finalize Output
% Truncate the pre-allocated arrays to the actual number of events read.
if m > 1
    spike = spike(1:m-1, :);
    if (waveson)
        waves = waves(1:m-1);
    end
else % Handle case with no valid spikes found
    spike = [];
    if (waveson)
        waves = {};
    end
end

fclose(fid);
end
