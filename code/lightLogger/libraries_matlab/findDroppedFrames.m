function flagged_indices = findDroppedFrames(signal, threshold)
    
arguments 
    signal {mustBeVector}; 
    threshold (1,1) {mustBeNumeric} = prctile(signal, 98);
end


% First, take the absolute difference between all sequential frames 
% aka, the approximation of the derivative 
sequential_differences = abs(diff(signal));

% Next, find where the sequential differences are greater
% than or equal to the provided threshold 
flagged_indices = find(sequential_differences >= threshold);

end

