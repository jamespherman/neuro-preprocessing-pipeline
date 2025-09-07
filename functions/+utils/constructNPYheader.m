


function header = constructNPYheader(dataType, shape, varargin)
%CONSTRUCTNPYHEADER Creates a header for a .npy file.
%   This function generates the byte-level header required for the NumPy
%   .npy file format, specifying the data type, shape, and memory layout
%   of the array to be saved.
%
%   Inputs:
%       dataType (string) - The MATLAB data type (e.g., 'int16', 'double').
%       shape (vector)    - A vector representing the dimensions of the array.
%       varargin          - Optional arguments:
%                           {1}: fortranOrder (logical, default true)
%                           {2}: littleEndian (logical, default true)
%
%   Output:
%       header (uint8 vector) - The fully constructed .npy header.

    % Set default values for optional arguments.
    fortranOrder = true;
    littleEndian = true;
    if nargin > 2
        fortranOrder = varargin{1};
    end
    if nargin > 3
        littleEndian = varargin{2};
    end

    % Define the mapping from MATLAB data types to NumPy's type strings.
    dtypesMatlab = {'uint8','uint16','uint32','uint64','int8','int16', ...
        'int32','int64','single','double', 'logical'};
    dtypesNPY = {'u1', 'u2', 'u4', 'u8', 'i1', 'i2', ...
        'i4', 'i8', 'f4', 'f8', 'b1'};

    % The .npy format starts with a "magic string" and version number.
    magicString = uint8([147, 78, 85, 77, 80, 89]); % x93NUMPY
    majorVersion = uint8(1);
    minorVersion = uint8(0);

    % Build the dictionary string that describes the array.
    % This is a Python-style dictionary literal.
    shapeStr = strjoin(arrayfun(@num2str, shape, 'UniformOutput', false), ', ');
    if numel(shape) == 1
        shapeStr = [shapeStr, ',']; % Add trailing comma for 1D arrays.
    end
    
    if littleEndian, endianChar = '<'; else, endianChar = '>'; end
    if fortranOrder, orderStr = 'True'; else, orderStr = 'False'; end
    
    dtypeStr = dtypesNPY{strcmp(dtypesMatlab, dataType)};
    
    dictString = sprintf("{'descr': '%s%s', 'fortran_order': %s, 'shape': (%s), }", ...
        endianChar, dtypeStr, orderStr, shapeStr);
    
    % The total header length must be a multiple of 16 bytes.
    % The header consists of the magic string (6), version (2), header
    % length field (2), and the dictionary string.
    baseHeaderLength = 6 + 2 + 2 + length(dictString);
    
    % Calculate the required padding.
    headerLengthPadded = ceil(baseHeaderLength / 16) * 16;
    
    % The header length field itself is a 16-bit little-endian integer.
    headerLength = typecast(int16(headerLengthPadded - 10), 'uint8');
    
    % Pad the header with spaces (ASCII 32) and end with a newline (ASCII 10).
    padding = repmat(uint8(32), 1, headerLengthPadded - baseHeaderLength);
    padding(end) = uint8(10);
    
    % Concatenate all parts to form the final header.
    header = [magicString, majorVersion, minorVersion, headerLength, ...
              uint8(dictString), padding];
end