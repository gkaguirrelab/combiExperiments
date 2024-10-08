function [stimulus,stimTime,stimLabels] = makeStimMatrix(nAcqs,stimSeq,stimLabelSet,extendedModelFlag,fixedStimDelaySecs)

% How many non-trial events to be added before the start of the sequence,
% for the purpose of modeling the period just before the experiment begins
nPreISIs = 1;

% Basic stimulus properties
nStimTypes = length(unique(stimSeq));
isi = 4.5;
dT = 0.25;

% Ensure that there is one label for every passed stim type
assert(nStimTypes == length(stimLabelSet));

% Add labels for the extended model if requested
if extendedModelFlag
    stimLabelSet = [stimLabelSet,'caryOver','newStim'];
end
nParams = length(stimLabelSet);

% Add the preISIs as "-1" events
stimSeq = [repmat(-1,1,nPreISIs) stimSeq];

% Create a single stimulus matrix
stimVecLength = length(stimSeq)*(isi/dT);
singleStimMat = zeros(nStimTypes,stimVecLength);
carryOver = zeros(1,stimVecLength);
newStim = zeros(1,stimVecLength);
for ii = 1:length(stimSeq)
    if stimSeq(ii) > 0
        idx = (ii-1)*(isi/dT)+1+round(fixedStimDelaySecs/dT);
        singleStimMat(stimSeq(ii)+1,idx) = 1;
        if ii > 1
            if stimSeq(ii-1) > 0
                carryOver(idx) = stimSeq(ii) - stimSeq(ii-1);
            else
                newStim(idx) = 1;
            end
        end
    end
end

% Mean center the matrix
for ii = 1:nStimTypes
    vec = singleStimMat(ii,:);
    singleStimMat(ii,:) = vec - mean(vec);
end

% Add the carry over and new stim vectors
if extendedModelFlag
    idx = carryOver ~= 0;
    carryOver(idx) = carryOver(idx) - mean(carryOver(idx));
    idx = newStim == 0;
    newStim(idx) = -mean(newStim);
    singleStimMat = [singleStimMat; carryOver; newStim];
end

% Create a single stimTime
singleStimTime = (0:dT:(stimVecLength-1)*dT)-(nPreISIs*isi);

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


