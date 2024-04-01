function x0 = update(obj,x,x0,floatSet,signal)
% Update x0 with the result of the search
%
% Syntax:
%   x0 = obj.update(x,x0, floatSet)
%
% Description:
%   Update the x0 parameters based upon the results of a stage of search.
%   Here we use regression to obtain the ampliude parameters of the model,
%   saving on time-consuming non-linear search.
%
% Inputs:
%   x                     - Vector of parameters that were the subject of
%                           the prior stage of search.
%   x0                    - Vector of the entire set of parameters of the
%                           model at the time of the start of the
%                           just-completed search
%   floatSet              - Vector of index values that indicate the
%                           mapping of vector x into vector x0 
%   signal                - 1 x time vector. The data to be fit.
%
% Outputs:
%   x0                    - Vector of the entire set of parameters of the
%                           model to be used in the next stage of search
%


% Obj variables
nParams = obj.nParams;
nAcqs = obj.nAcqs;
nStimTypes = obj.nStimTypes;
stimulus = obj.stimulus;
stimAcqGroups = obj.stimAcqGroups;
stimTime = obj.stimTime;
dataAcqGroups = obj.dataAcqGroups;

% Create the HRF
hrf = obj.flobsbasis*x(end-2:end)';

% Normalize the kernel to have unit area
hrf = hrf/sum(abs(hrf));

% Create a regression matrix for the HRF implied by the FLOBS params
X = zeros(size(obj.dataTime,1),nStimTypes);

for ss = 1:size(stimulus,2)
    
    % Grab this stimulus row
    neuralSignal = stimulus(:,ss);
    
    % Convolve the neuralSignal by the hrf, respecting acquisition boundaries
    fit = conv2run(neuralSignal,hrf,stimAcqGroups);

    % Shift each acquisition forward and back by the temporal shift params
    for ii=1:nAcqs
        shiftVal = x(ii);
        fit(dataAcqGroups==ii) = fshift(fit(dataAcqGroups==ii),shiftVal);
    end

    % If the stimTime variable is not empty, resample the fit to match
    % the temporal support of the data.
    if ~isempty(stimTime)
        dataAcqGroups = obj.dataAcqGroups;
        dataTime = obj.dataTime;
        fit = resamp2run(fit,stimAcqGroups,stimTime,dataAcqGroups,dataTime);
    end

    % Restore the DC component for neural signals with a sum of zero
    if abs(sum(neuralSignal)) < 1e-6
        fit = fit - mean(fit);
    end
    
    % Apply the cleaning step
    fit = obj.clean(fit);
    
    % Add the vector to the design matrix
    X(:,ss) = fit;
    
end

% Obtain the beta values
b = X\signal;

% Assemble the updated x0
x0 = [b' x];

end