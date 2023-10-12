function values = inverseTransVals(obj,refValues,testValue)

% The raw reference stimulus values (in frequency) undergo a transformation
% to be in log units, and are set relative to the test frequency
values = 10.^(refValues + log10(testValue));

end