function lcsLength = calculateLCSLength(vecA, vecB)
% CALCULATELCSLENGTH - Computes the length of the Longest Common Subsequence.
% Inputs:
%   vecA, vecB - Two numeric vectors to be compared.
%
% Output:
%   lcsLength  - A single integer representing the length of the LCS.

m = length(vecA);
n = length(vecB);

L = zeros(m+1, n+1);

for i = 1:m
    for j = 1:n
        if vecA(i) == vecB(j)
            L(i+1, j+1) = L(i, j) + 1;
        else
            L(i+1, j+1) = max(L(i, j+1), L(i+1, j));
        end
    end
end

lcsLength = L(m+1, n+1);
end
