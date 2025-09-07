function datToNPY(inFilename, outFilename, dataType, shape, varargin)
% DATTOPNY Creates a .npy file from a raw binary .dat file.
%
% This function efficiently creates a NumPy .npy file by prepending a
% valid header to an existing flat binary file, without loading the entire
% file into memory. It achieves this by writing the header to a temporary
% file and then using system commands to concatenate the header and the
% original data file.
%
%   Inputs:
%       inFilename (string)   - Path to the input flat binary (.dat) file.
%       outFilename (string)  - Path to the output .npy file.
%       dataType (string)     - MATLAB data type (e.g., 'int16', 'double').
%       shape (vector)        - Vector of the array's dimensions.
%       varargin              - Optional arguments:
%                               {1}: fortranOrder (logical, default true)
%                               {2}: littleEndian (logical, default true)

% Set default values for optional arguments.
fortranOrder = true;
littleEndian = true;
if nargin > 4
    fortranOrder = varargin{1};
end
if nargin > 5
    littleEndian = varargin{2};
end

% Prevent in-place operations which are unsafe with this method.
if strcmp(inFilename, outFilename)
    error('Input and output filenames must be different.');
end

% Construct the NPY header.
header = utils.constructNPYheader(dataType, shape, fortranOrder, littleEndian);

% Create a temporary file to hold the header.
tempFilename = [tempname, '.tmp'];
fid = fopen(tempFilename, 'w');
if fid == -1
    error('Could not create temporary file for header.');
end

% Ensure the temporary file is deleted when the function exits.
cleanupTask = onCleanup(@() delete(tempFilename));

% Write the header to the temporary file.
fwrite(fid, header, 'uint8');
fclose(fid);

% Use OS-specific system commands to concatenate the header and data file.
os = computer;
switch os
    case {'PCWIN', 'PCWIN64'}
        % For Windows, use 'copy /b' for binary concatenation.
        command = sprintf('copy /b "%s"+"%s" "%s"', ...
            tempFilename, inFilename, outFilename);
    case {'GLNXA64', 'MACI64'}
        % For Linux/macOS, use 'cat'.
        command = sprintf('cat "%s" "%s" > "%s"', ...
            tempFilename, inFilename, outFilename);
    otherwise
        error('datToNPY:UnsupportedOS', ...
            'Your OS (%s) is not supported for file concatenation.', os);
end

[status, cmdout] = system(command);
if status ~= 0
    error('datToNPY:ConcatFailed', ...
        'File concatenation failed:\n%s', cmdout);
end

end
