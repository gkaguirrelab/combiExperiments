function runDelayedMatchExperiment(subjectID,modDirection,testContrast,varargin)
% Psychometric measurement of accuracy and bias in reproduction of the
% frequency of a flickering stimulus after a delay. The code manages a
% series of files that store the data from the experiment. As configured,
% each testing "session" has 20 trials and is about 4 minutes in duration.
%
% Examples:
%{
    subjectID = 'DEMO_001';
    modDirection = 'LightFlux';
    runDetectThreshExperiment(subjectID,modDirection);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiLEDToolbox','dropboxBaseDir'),@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('cal',loadCalByName('CombiLED_shortLLG_classicEyePiece_ND2x5'),@isstruct);
p.addParameter('refFreqRangeHz',[2 10],@isnumeric);
p.addParameter('nTrials',25,@isnumeric);
p.addParameter('observerAgeInYears',25,@isnumeric);
p.addParameter('pupilDiameterMm',4.2,@isnumeric);
p.addParameter('verboseCombiLED',false,@islogical);
p.addParameter('verbosePsychObj',false,@islogical);
p.addParameter('updateFigures',true,@islogical);
p.parse(varargin{:})

%  Pull out of the p.Results structure
cal = p.Results.cal;
refFreqRangeHz = p.Results.refFreqRangeHz;
nTrials = p.Results.nTrials;
verboseCombiLED = p.Results.verboseCombiLED;
verbosePsychObj = p.Results.verbosePsychObj;
updateFigures = p.Results.updateFigures;

% Set our experimentName
experimentName = 'DMTF';

% Set a random seed
rng('shuffle');

% Define the modulation and data directories
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
    photoreceptors = photoreceptorDictionaryHuman(...
        'observerAgeInYears',p.Results.observerAgeInYears,...
        'pupilDiameterMm',p.Results.pupilDiameterMm);
    modResult = designModulation(modDirection,photoreceptors,cal);
    save(filename,'modResult');
    figHandle = plotModResult(modResult,'off');
    filename = fullfile(modDir,'modResult.pdf');
    saveas(figHandle,filename,'pdf')
    close(figHandle)
end

% Set up the CombiLED
CombiLEDObj = CombiLEDcontrol('verbose',verboseCombiLED);

% Update the gamma table
CombiLEDObj.setGamma(cal.processedData.gammaTable);

% Send the modulation direction to the CombiLED
CombiLEDObj.setSettings(modResult);
CombiLEDObj.setBackground(modResult.settingsBackground);

% Define the filestem for this psychometric object
psychFileStem = [subjectID '_' modDirection '_' experimentName ...
    '_' strrep(num2str(testContrast),'.','x')];

% Create or load the psychometric object
filename = fullfile(dataDir,[psychFileStem '.mat']);
if isfile(filename)
    % Load the object
    load(filename,'psychObj');
    % Put in the fresh CombiLEDObj
    psychObj.CombiLEDObj = CombiLEDObj;
    % Initiate the CombiLED settings
    psychObj.initializeDisplay;
    % Increment blockIdx
    psychObj.blockIdx = psychObj.blockIdx+1;
    psychObj.blockStartTimes(psychObj.blockIdx) = datetime();
else
    psychObj = DelayedMatchToFreq(CombiLEDObj,refFreqRangeHz,testContrast,'verbose',verbosePsychObj);
end

% Start the session
fprintf('Press any key to start trials\n');
pause

% Store the block start time
psychObj.blockStartTimes(psychObj.blockIdx) = datetime();

% Present nTrials.
for ii = 1:nTrials
    psychObj.presentTrial
end

% Play a "done" tone
Fs = 8192; % Sampling Frequency
dur = 0.1; % Duration in seconds
t  = linspace(0, dur, round(Fs*dur));
lowTone = sin(2*pi*500*t);
midTone = sin(2*pi*750*t);
highTone = sin(2*pi*1000*t);
doneSound = [highTone midTone lowTone];
donePlayer = audioplayer(doneSound,Fs);
donePlayer.play;
pause(0.5);

% empty the CombiLEDObj handle and save the psychObj
psychObj.CombiLEDObj = [];
save(filename,'psychObj');

% Plot the data
if updateFigures
    loglog([psychObj.trialData.refFreq],[psychObj.trialData.testFreqInitial],'xb')
    hold on
    loglog([psychObj.trialData.refFreq],[psychObj.trialData.testFreq],'.r')
    loglog(refFreqRangeHz,refFreqRangeHz,'-k')
    xlim([1 30])
    ylim([1 30])
    axis square
end

end
