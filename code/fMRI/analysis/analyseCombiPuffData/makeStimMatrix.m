function [stimulus,stimTime,stimLabels] = makeStimMatrix(nAcqs)

% The stim sequence and labels
stimLabelSet = {'0psi','1.4psi','3.5psi','9.0psi','23.3psi','caryOver','newStim'};
stimulusCoarse = [0,0,3,3,4,0,2,0,4,4,2,1,4,3,1,0,1,3,2,4,1,1,2,2,3,0,0,2,2,3,4,3,0,1,4,2,0,4,1,2,1,3,3,2,4,4,0,3,1,1,0,0,1,1,3,0,4,4,2,3,3,1,2,1,4,0,2,4,1,0,3,4,3,2,2,0,0,3,2,2,1,1,4,2,3,1,0,1,3,4,1,2,4,4,0,2,0,4,3,3,0,0];

% Basic stimulus properties
nStimTypes = length(unique(stimulusCoarse))-1;
isi = 4.5;
dT = 0.25;
nParams = length(stimLabelSet);

% Create a single stimulus matrix
stimVecLength = length(stimulusCoarse)*(isi/dT);
singleStimMat = zeros(nStimTypes,stimVecLength);
carryOver = zeros(1,stimVecLength);
newStim = zeros(1,stimVecLength);
for ii = 1:length(stimulusCoarse)
    idx = (ii-1)*(isi/dT)+1;
    singleStimMat(stimulusCoarse(ii)+1,idx) = 1;
    if ii > 1
        if stimulusCoarse(ii-1) ~=0
            carryOver(idx) = stimulusCoarse(ii) - stimulusCoarse(ii-1);
        else
            newStim(idx) = 1;
        end
    end
end

% Mean center the matrix
for ii = 1:nStimTypes
    vec = singleStimMat(ii,:);
    singleStimMat(ii,:) = vec - mean(vec);
end

% Add the carry over and new stim vectors
idx = carryOver ~= 0;
carryOver(idx) = carryOver(idx) - mean(carryOver(idx));
idx = newStim == 0;
newStim(idx) = -mean(newStim);
singleStimMat = [singleStimMat; carryOver; newStim];

% Create a single stimTime
singleStimTime = 0:dT:(stimVecLength-1)*dT;

% Loop over the number of acquisitions and create an integrated matrix
stimLabels = {};
for ii=1:nAcqs
    thisStimMat = zeros(nParams*nAcqs,stimVecLength);
    thisStimMat((ii-1)*nParams+1:ii*nParams,:) = singleStimMat;
    stimulus{ii} = thisStimMat;
    stimTime{ii} = singleStimTime;
    stimLabels = [stimLabels, append(stimLabelSet,sprintf('_run%d',ii))];
end

end


