function [fit, hrf] = forward(obj, x)
% Forward model
%
% Syntax:
%   [fit, hrf] = obj.forward(x)
%
% Description:
%   Returns a time-series vector that is the predicted response to the
%   stimulus, based upon the parameters provided in x.
%
% Inputs:
%   x                     - 1xnParams vector.
%
% Optional key/value pairs:
%   none
%
% Outputs:
%   fit                   - 1xtime vector.
%   hrf                   - 1xn vector.
%


% Obj variables
nParams = obj.nParams;
nAcqs = obj.nAcqs;
nStimTypes = obj.nStimTypes;
stimulus = obj.stimulus;
stimAcqGroups = obj.stimAcqGroups;
stimTime = obj.stimTime;
dataAcqGroups = obj.dataAcqGroups;

% Scale the stimulus matrix by the gain parameters
neuralSignal = stimulus*x(1:nStimTypes)';

% Create the HRF
hrf = makeFlobsHRF(x(nParams-2:nParams), obj.flobsbasis);

% Convolve the neuralSignal by the hrf, respecting acquisition boundaries
fit = conv2run(neuralSignal,hrf,stimAcqGroups);

% Shift each acquisition forward and back by the temporal shift params
for ii=1:nAcqs
    shiftVal = x(nStimTypes+ii);
    fit(dataAcqGroups==ii) = fshift(fit(dataAcqGroups==ii),shiftVal);
end

% If the stimTime variable is not empty, resample the fit to match
% the temporal support of the data.
if ~isempty(stimTime)
    dataTime = obj.dataTime;
    fit = resamp2run(fit,stimAcqGroups,stimTime,dataAcqGroups,dataTime);
end

% Apply the cleaning step
fit = obj.clean(fit);

end


%% LOCAL FUNCTIONS

function hrf = makeFlobsHRF(x, flobsbasis)

% Create the HRF
hrf = flobsbasis*x';

% Normalize the kernel to have unit area
hrf = hrf/sum(abs(hrf));

end


