function runVEPTCSFExperiment(subjectID,modDirection,varargin)
%
%
%{
    subjectID = 'HERO_gka1';
    modDirection = 'LightFlux';
    runVEPTCSFExperiment(subjectID,modDirection);
%}


% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiLEDToolbox','dropboxBaseDir'),@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('nTrialsToCollect',10,@isnumeric);
p.addParameter('nFullSets',3,@isnumeric);
p.addParameter('stimContrastSet',[0,0.2,0.4,0.8],@isnumeric);
p.addParameter('stimFreqSetHz',[3.0000, 4.7285, 7.4530, 11.7473, 18.5159, 29.1845, 46.0000],@isnumeric);
p.addParameter('observerAgeInYears',25,@isnumeric);
p.addParameter('pupilDiameterMm',4.2,@isnumeric);
p.addParameter('simulateStimuli',false,@islogical);
p.addParameter('verboseCombiLED',false,@islogical);
p.addParameter('verbosePhysioObj',true,@islogical);
p.parse(varargin{:})

%  Pull out of the p.Results structure
simulateStimuli = p.Results.simulateStimuli;
verboseCombiLED = p.Results.verboseCombiLED;
nFullSets = p.Results.nFullSets;

% Set our experimentName
experimentName = 'ssVEPTCSF';

% Set a random seed
rng('shuffle');

modDir = fullfile(...
    p.Results.dropBoxBaseDir,...
    'MELA_data',...,
    p.Results.projectName,...
    subjectID,modDirection);

dataDir = fullfile(modDir,experimentName);

% Create a directory for the subject
if ~isfolder(dataDir)
    mkdir(dataDir)
end

% Create or load a modulation and save it to the saveModDir
filename = fullfile(modDir,'modResult.mat');
if isfile(filename)
    % The modResult may be a nulled modulation, so handle the possibility
    % of the variable name being different from "modResult".
    tmp = load(filename);
    fieldname = fieldnames(tmp);
    modResult = tmp.(fieldname{1});

else
    photoreceptors = photoreceptorDictionary(...
        'observerAgeInYears',p.Results.observerAgeInYears,...
        'pupilDiameterMm',p.Results.pupilDiameterMm);
    % We get away with using zero headroom, as we will always be using
    % contrast levels that are less that 100%
    modResult = designModulation(modDirection,photoreceptors,...
        'primaryHeadroom',0);
    save(filename,'modResult');
end

% Handle the CombiLED object
if ~simulateStimuli
    % Set up the CombiLED
    CombiLEDObj = CombiLEDcontrol('verbose',verboseCombiLED);
    % Send the modulation direction to the CombiLED
    CombiLEDObj.setSettings(modResult);
    CombiLEDObj.setBackground(modResult.settingsBackground);
else
    CombiLEDObj = [];
end

% Create or load the measurementRecord
filename = fullfile(dataDir,'measurementRecord.mat');
if isfile(filename)
    load(filename,'measurementRecord');

    stimFreqSetHz = measurementRecord.stimulusProperties.stimFreqSetHz;
    stimContrastSet = measurementRecord.stimulusProperties.stimContrastSet;
    freqIdxOrder = measurementRecord.experimentProperties.freqIdxOrder;
    contrastIdxOrderMatrix = measurementRecord.experimentProperties.contrastIdxOrderMatrix;
else

    % The trial sequence order
    freqIdxOrder = [4, 1, 6, 5, 3, 7, 2, 2, 5, 1, 7, 4, 6, 3, 3, 1, 5, 2, 4, 7, 6, 6, 1, 4, 2, 7, 3, 5, 5, 4, 3, 2, 6, 7, 1, 1, 2, 3, 6, 4, 5, 7, 7, 5, 6, 2, 1, 3, 4];
    contrastIdxOrderMatrix = readmatrix(fullfile(fileparts(mfilename('fullpath')),'deBruijn_n4_Seqs.csv'));

    % The contrasts and frequencies themselves
    stimContrastSet = p.Results.stimContrastSet;
    stimFreqSetHz = p.Results.stimFreqSetHz;

    % Store the values
    measurementRecord.experimentProperties.freqIdxOrder = freqIdxOrder;
    measurementRecord.experimentProperties.contrastIdxOrderMatrix = contrastIdxOrderMatrix;
    measurementRecord.experimentProperties.modDirection = modDirection;
    measurementRecord.experimentProperties.experimentName = experimentName;
    measurementRecord.experimentProperties.pupilDiameterMm = p.Results.pupilDiameterMm;
    measurementRecord.subjectProperties.subjectID = subjectID;
    measurementRecord.subjectProperties.observerAgeInYears = p.Results.observerAgeInYears;
    measurementRecord.stimulusProperties.stimContrastSet = stimContrastSet;
    measurementRecord.stimulusProperties.stimFreqSetHz = stimFreqSetHz;
    measurementRecord.trialData = [];
    measurementRecord.trialIdx = 1;

    % Save the file
    save(filename,'measurementRecord');
end

% First check if we are done
if measurementRecord.trialIdx > length(freqIdxOrder)*nFullSets
    fprintf('Done with this experiment!\n')
    return
end

% How many trials to collect?
nTrialsToCollect = p.Results.nTrialsToCollect;
nTrialsToCollect = min([nTrialsToCollect,1+(nFullSets*length(freqIdxOrder))-measurementRecord.trialIdx]);

% Create a flickerPhysioObj object
flickerPhysioObj = FlickerPhysio(CombiLEDObj,subjectID,modDirection,experimentName);

% Loop over the trials to collect data
for ii=1:nTrialsToCollect

    % Wait for subject readiness
    fprintf('Press any key to start trial\n');
    pause

    % Update the stimulus settings for the flickerPhysioObj
    idx = mod(measurementRecord.trialIdx-1,length(freqIdxOrder))+1;
    flickerPhysioObj.trialIdx = measurementRecord.trialIdx;
    flickerPhysioObj.stimFreqHz = stimFreqSetHz(freqIdxOrder(idx));
    flickerPhysioObj.stimContrastSet = stimContrastSet;
    flickerPhysioObj.stimContrastOrder = contrastIdxOrderMatrix(idx,:);

    % Start the trial
    flickerPhysioObj.collectTrial;

    % Copy the trial data over to the measurementRecord
    for fn = fieldnames(flickerPhysioObj.trialData(measurementRecord.trialIdx))'
        measurementRecord.trialData(measurementRecord.trialIdx).(fn{1})=flickerPhysioObj.trialData(measurementRecord.trialIdx).(fn{1});
    end

    % Iterate the trialIdx and save
    measurementRecord.trialIdx = measurementRecord.trialIdx+1;
    filename = fullfile(dataDir,'measurementRecord.mat');
    save(filename,'measurementRecord');

end

% Close the labjack
flickerPhysioObj.vepObj.labjackOBJ.shutdown

end

