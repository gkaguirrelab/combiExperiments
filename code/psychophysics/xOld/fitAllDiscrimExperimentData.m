function fitAllDiscrimExperimentData(subjectID,modDirection,varargin)
% Code that interleaves psychometric measurements for different "triplets"
% of stimulus parameters in a measurement of the double-reference 2AFC
% technique of Jogan & Stocker. The code manages a series of files that
% store the data from the experiment. As configured, each testing "session"
% has 40 trials and is about 8 minutes in duration. A complete measurement
% of 80 trials for each of the 50 triplets requires 100 sessions.
%
%{
    subjectID = 'HERO_gka';
    modDirection = 'LightFlux';
    fitAllDiscrimExperimentData(subjectID,modDirection);
%}


% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dataDirRoot','~/Desktop/flickerPsych',@ischar);
p.addParameter('updateFigures',false,@islogical);
p.parse(varargin{:})

updateFigures = p.Results.updateFigures;

% Set our psychType
psychType = 'DoubleRef';

% Set a random seed
rng('shuffle');

% Define a location to save data
saveDataDir = fullfile(p.Results.dataDirRoot,subjectID,modDirection,psychType);

% Load the measurementRecord
filename = fullfile(saveDataDir,'measurementRecord.mat');
load(filename,'measurementRecord');
testFreqSetHz = measurementRecord.stimulusProperties.testFreqSetHz;
refContrastSetDb = measurementRecord.stimulusProperties.refContrastSetDb;
testContrastSetDb = measurementRecord.stimulusProperties.testContrastSetDb;

% Load the psychometric objects
stimIdx = find(measurementRecord.trialCount>0);
for ii=1:length(stimIdx)
    [IdxX,IdxY,IdxZ] = ind2sub([length(testContrastSetDb),length(testFreqSetHz),length(refContrastSetDb)],stimIdx(ii));
    stimTriplet(ii).testContrastDb = testContrastSetDb(IdxX);
    stimTriplet(ii).testFreqHz = testFreqSetHz(IdxY);
    stimTriplet(ii).refContrastDb = refContrastSetDb(IdxZ);
    fileStem = [subjectID '_' modDirection '_' psychType ...
        '_' strrep(num2str(stimTriplet(ii).testContrastDb),'.','x') ...
        '_' strrep(num2str(stimTriplet(ii).testFreqHz),'.','x') ...
        '_' strrep(num2str(stimTriplet(ii).refContrastDb),'.','x')];
    % Create or load the psychometric objects
    filename = fullfile(saveDataDir,[fileStem '.mat']);
    tmpObj = load(filename,'psychObj');
    stimObj{ii} = tmpObj.psychObj;
    clear tmpObj
end

% Assemble a parameter vector
nTestStim = length(testFreqSetHz)*length(testContrastSetDb);
nRefStim = length(refContrastSetDb);
p0 = [zeros(1,nRefStim),zeros(1,nTestStim),zeros(1,nTestStim)];
lb = [zeros(1,nRefStim),zeros(1,nTestStim),-ones(1,nTestStim)];
ub = [ones(1,nRefStim),ones(1,nTestStim),ones(1,nTestStim)];

% Define an objective
myObj = @(p) multiStimObjective(p,stimObj,stimTriplet,testFreqSetHz,refContrastSetDb,testContrastSetDb);

options = optimset('fmincon');
options.Display = 'iter';

[p, fVal] = fmincon(myObj,p0,[],[],[],[],lb,ub,[],options);

% figure
if updateFigures
    figHandle = psychObj.plotOutcome('off');
    filename = fullfile(saveDataDir,[fileStem '.pdf']);
    saveas(figHandle,filename,'pdf')
end

end

%% LOCAL FUNCTIONS

function fVal = multiStimObjective(p,stimObj,stimTriplet,testFreqSetHz,refContrastSetDb,testContrastSetDb)

nTestStim = length(testFreqSetHz)*length(testContrastSetDb);
nRefStim = length(refContrastSetDb);

fVal = [];
for ii=1:length(stimObj)
    testFreqIdx = find(stimTriplet(ii).testFreqHz==testFreqSetHz);
    testContrastIdx = find(stimTriplet(ii).testContrastDb==testContrastSetDb);
    refContrastIdx = find(stimTriplet(ii).refContrastDb==refContrastSetDb);
    testInd = sub2ind([length(testFreqSetHz),length(testContrastSetDb)],testFreqIdx,testContrastIdx);
    refInd = sub2ind([1,nRefStim],1,refContrastIdx);
    subP(1) = p(testInd);
    subP(2) = p(nTestStim+testInd);
    subP(3) = p(nTestStim+nTestStim+refInd);

    [~, ~, ~, fVal(ii)] = stimObj{ii}.reportParams(...
        'lb',subP,'ub',subP);
end
fVal = max(fVal);
end
