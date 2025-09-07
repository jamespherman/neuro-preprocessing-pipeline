

function [arrayShape, dataType, fortranOrder, littleEndian, totalHeaderLength, npyVersion] = readNPYheader(filename)
% READNPYHEADER Parses the header of a .npy file.
%
%   This low-level utility reads the header of a NumPy .npy file to extract
%   metadata about the stored array, such as its shape, data type, and
%   memory layout.
%
%   Inputs:
%       filename (string) - The path to the .npy file.
%
%   Outputs:
%       arrayShape        - A vector of the array's dimensions.
%       dataType          - The MATLAB string for the data type.
%       fortranOrder      - A logical indicating if the data is column-major.
%       littleEndian      - A logical indicating the byte order.
%       totalHeaderLength - The total length of the header in bytes.
%       npyVersion        - The version of the .npy format.
%
%   See also: readNPY, writeNPY.

fid = fopen(filename, 'r');

% Verify that the file exists and can be opened.
if (fid == -1)
    % Distinguish between file not found and permission denied.
    if ~isempty(dir(filename))
        error('readNPYheader:PermissionDenied', 'Permission denied: %s', filename);
    else
        error('readNPYheader:FileNotFound', 'File not found: %s', filename);
    end
end

% Use a try-catch block to ensure the file is closed on error.
try
    % Define the mapping from MATLAB types to NumPy's type strings.
    dtypesMatlab = {'uint8','uint16','uint32','uint64','int8', ...
        'int16','int32','int64','single','double', 'logical'};
    dtypesNPY = {'u1', 'u2', 'u4', 'u8', 'i1', ...
        'i2', 'i4', 'i8', 'f4', 'f8', 'b1'};
    
    % Read the magic string to identify the file type.
    magicString = fread(fid, [1 6], 'uint8=>uint8');
    if ~all(magicString == [147,78,85,77,80,89]) % x93NUMPY
        error('readNPY:NotNUMPYFile', ...
            'This file does not appear to be a NUMPY file.');
    end
    
    % Read version and header length information.
    majorVersion = fread(fid, [1 1], 'uint8=>uint8');
    minorVersion = fread(fid, [1 1], 'uint8=>uint8');
    npyVersion = [majorVersion, minorVersion];
    headerLength = fread(fid, [1 1], 'uint16=>uint16');
    totalHeaderLength = 10 + headerLength;
    
    % Read the header dictionary string.
    arrayFormat = fread(fid, [1 headerLength], 'char=>char');
    
    % --- Parse the dictionary string using regular expressions ---
    
    % Extract the data type description (e.g., '<f4').
    r = regexp(arrayFormat, '''descr''\s*:\s*''(.*?)''', 'tokens');
    if isempty(r)
        error('readNPY:InvalidHeader', ...
            'Could not parse data type from header: "%s"', arrayFormat);
    end
    dtNPY = r{1}{1};    
    
    % Determine endianness ('<' is little-endian).
    littleEndian = ~strcmp(dtNPY(1), '>');
    
    % Map the NumPy type string to a MATLAB data type string.
    dataType = dtypesMatlab{strcmp(dtNPY(2:end), dtypesNPY)};
        
    % Determine the memory layout (Fortran/column-major or C/row-major).
    r = regexp(arrayFormat, '''fortran_order''\s*:\s*(\w+)', 'tokens');
    fortranOrder = strcmp(r{1}{1}, 'True');
    
    % Extract the shape of the array.
    r = regexp(arrayFormat, '''shape''\s*:\s*\((.*?)\)', 'tokens');
    shapeStr = r{1}{1};
    % Remove the 'L' suffix that numpy sometimes adds for long integers.
    arrayShape = str2num(shapeStr(shapeStr ~= 'L'));
    
    fclose(fid);
    
catch me
    fclose(fid);
    rethrow(me);
end
end
