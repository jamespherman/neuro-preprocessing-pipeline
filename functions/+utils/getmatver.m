function V = getmatver()
% GETMATVER returns MATLAB's version as a numerical value.
% For example, for R2020b (version string '9.9.0...'), this function returns 9.9.
% This is used for compatibility checks in older toolkits.

v_str = version;
dot_indices = strfind(v_str, '.');
if length(dot_indices) >= 2
    % Found at least two dots, e.g., '9.9.0'
    V = str2double(v_str(1:dot_indices(2)-1));
else
    % Fallback for versions like '7.3'
    V = str2double(regexp(v_str, '^\d+\.\d+', 'match', 'once'));
end

end