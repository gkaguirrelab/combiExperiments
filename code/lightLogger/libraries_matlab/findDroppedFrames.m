function flagged_indices = findDroppedFrames(signal, threshold)
% Finds potentially dropped frames in a sinusoidal signal
%
% Syntax:
%   flagged_indices = findDroppedFrames(signal, threshold)
%
% Description:
%   Finds potentially dropped frames in a sinusoidal signal by 
%   looking at the absolute value of its derivative, then returning 
%   indices above a certain threshold. By default, this is the 
%   98th percentile of the derivative. 
%
%
% Inputs:
%   signal                - Vector. A one dimensional vector 
%                           representing the signal to analyze
%
%   threshold             - Double. The value above which the derivative
%                           of the signal will be considered anomalous.  
%
% Outputs:
%   flagged_indices       - Vector. A one dimensional vector 
%                           representing the indices in the signal 
%                           flagged for beginning a series of dropped
%                           frames. 
%
% Examples:
%{
    signal = [1,2,5,6,7,10,11,12,19];
    threshold = prctile(abs(diff(signal)), 99); 
    flagged_indices = findDroppedFrames(signal);
%}
    
% Validate the arguments in terms of type and assign default 
% values
arguments 
    signal {mustBeVector}; 
    threshold (1,1) {mustBeNumeric} = prctile(abs(diff(signal)), 98);
end


% First, take the absolute difference between all sequential frames 
% aka, the approximation of the derivative 
sequential_differences = abs(diff(signal));

% Next, find where the sequential differences are greater
% than or equal to the provided threshold 
flagged_indices = find(sequential_differences >= threshold);

end

