function values = forwardTransformVals(obj,refValues,testValue)

% The raw reference stimulus values (in frequency) undergo a transformation
% to be in log units, and are set relative to the test frequency
values = log10(refValues) - log10(testValue);
