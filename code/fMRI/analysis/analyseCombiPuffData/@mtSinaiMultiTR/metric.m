function [metric, signal, modelFit,avgDataTime] = metric(obj, signal, x)
% Evaluates the match between a signal and a model fit
%
% Syntax:
%   [metric, signal, modelFit] = metric(obj, signal, x)
%
% Description:
%   Given a time series signal and the parameters of the forward model,
%   returns a metric that describes how well the two match.
%
% Inputs:
%   signal                - 1 x time vector. The data to be fit.
%   x                     - 1 x nParams vector of parameter values.
%
% Optional key/value pairs:
%   none
%
% Outputs:
%   metric                - Scalar.
%

% Filter the signal to remove the confound event (if one is present)
stimLabels = obj.stimLabels;
confoundStimLabel = obj.confoundStimLabel;
if ~isempty(confoundStimLabel)
    idx = startsWith(stimLabels,confoundStimLabel);
    if any(idx)
        % Obtain the modeled confound effect
        xSub = x;
        xSub(~idx)=0;
        signal = signal - obj.forward(xSub);

        % Remove the confound event from the model going forward
        x(idx)=0;
    end
end

% Obtain the model fit
modelFit = obj.forward(x);

% Average across acquisitions, resampling if necessary for differing TRs
dataAcqGroups = obj.dataAcqGroups;
dataTime = obj.dataTime;

for ii=1:max(dataAcqGroups)
    idx = dataAcqGroups == ii;
    thisFit = modelFit(idx);
    thisSignal = signal(idx);
    if ii == 1
        avgFit = thisFit;
        avgSignal = thisSignal;
        avgDataTime = dataTime(dataAcqGroups==1);
    else
        if length(thisFit) ~= length(avgFit)
            avgDataTime = dataTime(dataAcqGroups==1);
            acqSourceTime = dataTime(dataAcqGroups==ii);
            thisFit = interp1(acqSourceTime, thisFit,avgDataTime,'linear',0);
            thisSignal = interp1(acqSourceTime, thisSignal,avgDataTime,'linear',0);            
        end
        avgFit = avgFit + thisFit;
        avgSignal = avgSignal + thisSignal;
    end
end
modelFit = avgFit / max(dataAcqGroups);
signal = avgSignal / max(dataAcqGroups);

% Implement an R^2 metric
metric = calccorrelation(signal, modelFit)^2;

end

