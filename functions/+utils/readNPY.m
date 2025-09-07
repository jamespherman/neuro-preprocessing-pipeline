

function data = readNPY(filename)
% READNPY Reads an N-dimensional array from a .npy file.
%
%   This function reads a subset of all possible .npy files, specifically
%   those containing N-dimensional arrays of standard data types. It does
%   not support structured arrays or object arrays.
%
%   Inputs:
%       filename (string) - The path to the .npy file.
%
%   Outputs:
%       data - The data from the file, reshaped to its original dimensions.
%
%   See also: readNPYheader, writeNPY.
%

% First, read the header to get metadata about the array.
[shape, dataType, fortranOrder, littleEndian, totalHeaderLength, ~] = ...
    utils.readNPYheader(filename);

% Open the file with the correct endianness ('l' for little, 'b' for big).
if littleEndian
    fid = fopen(filename, 'r', 'l');
else
    fid = fopen(filename, 'r', 'b');
end

% Use a try-catch block to ensure the file is closed even if an error occurs.
try
    % Skip the header to get to the data.
    fread(fid, totalHeaderLength, 'uint8');

    % Read the data from the file in a single, flat vector.
    data = fread(fid, prod(shape), [dataType '=>' dataType]);

    % Reshape the data to its original dimensions.
    if numel(shape) > 1
        if fortranOrder
            % For Fortran-ordered data (column-major, like MATLAB), a simple
            % reshape is sufficient.
            data = reshape(data, shape);
        else
            % For C-ordered data (row-major), we need to reshape with
            % reversed dimensions and then permute them back to the
            % original order.
            data = reshape(data, shape(end:-1:1));
            data = permute(data, [length(shape):-1:1]);
        end
    end

    fclose(fid);

catch me
    % If an error occurs, close the file and rethrow the error.
    fclose(fid);
    rethrow(me);
end
