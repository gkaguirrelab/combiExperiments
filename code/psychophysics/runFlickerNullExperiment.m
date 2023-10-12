function runFlickerNullExperiment(subjectID,modDirection,toBeNulledDirection,modDirectionNulledName,varargin)
% 
%
% Examples:
%{
    subjectID = 'HERO_gka1';
    modDirection = 'LminusM_wide';
    toBeNulledDirection = 'LightFlux';
    modDirectionNulledName = 'LminusM_LMSNull';
    runFlickerNullExperiment(subjectID,modDirection,toBeNulledDirection,,modDirectionNulledName);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiLEDToolbox','dropboxBaseDir'),@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('observerAgeInYears',25,@isnumeric);
p.addParameter('pupilDiameterMm',4.2,@isnumeric);
p.addParameter('stimContrast',0.175,@isnumeric);
p.addParameter('stimTestSet',linspace(-0.5,0.5,31),@isnumeric);
p.addParameter('nFullSets',3,@isnumeric);
p.addParameter('simulateStimuli',false,@islogical);
p.addParameter('simulateResponse',false,@islogical);
p.addParameter('verboseCombiLED',false,@islogical);
p.addParameter('verbosePsychObj',true,@islogical);
p.addParameter('updateFigures',true,@islogical);
p.parse(varargin{:})

%  Pull out of the p.Results structure
simulateStimuli = p.Results.simulateStimuli;
simulateResponse = p.Results.simulateResponse;
verboseCombiLED = p.Results.verboseCombiLED;
verbosePsychObj = p.Results.verbosePsychObj;
updateFigures = p.Results.updateFigures;

% Set our experimentName
experimentName = 'flickerNull';

% Set a random seed
rng('shuffle');

% Define where to save the data
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
    load(filename,'modResult');
else
    photoreceptors = photoreceptorDictionary(...
        'observerAgeInYears',p.Results.observerAgeInYears,...
        'pupilDiameterMm',p.Results.pupilDiameterMm);
    modResult = designModulation(modDirection,photoreceptors);
    save(filename,'modResult');
    figHandle = plotModResult(modResult,'off');
    filename = fullfile(modDir,'modResult.pdf');
    saveas(figHandle,filename,'pdf')
    close(figHandle)   
end

% Create or load a nulling direction. This is saved within the flickerNull
% experiment directory, as opposed to the top level modulation direction
% directory
filename = fullfile(dataDir,'modResultToBeNulled.mat');
if isfile(filename)
    load(filename,'modResultToBeNulled');
else
    photoreceptors = photoreceptorDictionary(...
        'observerAgeInYears',p.Results.observerAgeInYears,...
        'pupilDiameterMm',p.Results.pupilDiameterMm);
    modResultToBeNulled = designModulation(toBeNulledDirection,photoreceptors);
    save(filename,'modResultToBeNulled');
    figHandle = plotModResult(modResultToBeNulled,'off');
    filename = fullfile(dataDir,'modResultToBeNulled.pdf');
    saveas(figHandle,filename,'pdf')
    close(figHandle)   
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

% Initiate the PsychJava code. This silences a warning and prevents a
% problem with recording the first trial on startup
warnState = warning();
warning('off','MATLAB:Java:DuplicateClass');
PsychJavaTrouble();
warning(warnState);

% Create or load the measurementRecord
filesuffix = ['_' subjectID '_' modDirectionNulledName '_' experimentName ...
    sprintf('_cntrst-%2.2f',p.Results.stimContrast) ];
filename = fullfile(dataDir,['measurementRecord' filesuffix '.mat']);
if isfile(filename)
    load(filename,'measurementRecord');
    stimContrast = measurementRecord.experimentProperties.stimContrast;
    nStims = measurementRecord.experimentProperties.nStims;
    nTrialsPerSession = measurementRecord.experimentProperties.nTrialsPerSession;
    nTrialsPerStim = measurementRecord.experimentProperties.nTrialsPerStim;
else
    % The stimulus and experiment properties
    nStims = 2;
    nTrialsPerSession = 40;
    nTrialsPerStim = 100; % Total n trials per stimulus
    stimContrast = p.Results.stimContrast;

    % Store the values
    measurementRecord.subjectProperties.subjectID = subjectID;
    measurementRecord.subjectProperties.observerAgeInYears = p.Results.observerAgeInYears;
    measurementRecord.experimentProperties.modDirection = modDirection;
    measurementRecord.experimentProperties.stimContrast = stimContrast;
    measurementRecord.experimentProperties.stimTestSet = p.Results.stimTestSet;    
    measurementRecord.experimentProperties.experimentName = experimentName;
    measurementRecord.experimentProperties.pupilDiameterMm = p.Results.pupilDiameterMm;
    measurementRecord.experimentProperties.nStims = nStims;
    measurementRecord.experimentProperties.nTrialsPerSession = nTrialsPerSession;
    measurementRecord.experimentProperties.nTrialsPerStim = nTrialsPerStim;
    measurementRecord.sessionData = [];
    measurementRecord.trialIdx = 1;
    save(filename,'measurementRecord');
end

% First check if we are done
if measurementRecord.trialIdx > nTrialsPerStim*nStims*p.Results.nFullSets
    fprintf('Done with this experiment!\n')
    return
end

% Set up the variables that hold this session information
fprintf('Preparing psychometric objects...');
sessionData = struct();
for ii=1:nStims
    if mod(ii,2)==0
        searchDirection = 'adjustHighSettings';
    else
        searchDirection = 'adjustLowSettings';
    end

    sessionData.fileStem{ii} = [subjectID '_' modDirectionNulledName '_' experimentName ...
        sprintf('_cntrst-%2.2f',stimContrast) '_' searchDirection];

    % Create or load the psychometric objects
    filename = fullfile(dataDir,[sessionData.fileStem{ii} '.mat']);
    if isfile(filename)
        tmpObj = load(filename,'psychObj');
        sessionObj{ii} = tmpObj.psychObj;
        clear tmpObj
        sessionObj{ii}.CombiLEDObj = CombiLEDObj;
        % Initiate the CombiLED settings
        sessionObj{ii}.initializeDisplay;
    else
        sessionObj{ii} = PsychFlickerNull(CombiLEDObj,...
            modResult,...
            'adjustHighSettings',strcmp(searchDirection,'adjustHighSettings'),...
            'adjustSettingsVec',modResultToBeNulled.settingsHigh,...
            'stimContrast',stimContrast,...
            'stimTestSet',p.Results.stimTestSet,...
            'giveFeedback',true,...
            'simulateStimuli',simulateStimuli,...
            'simulateResponse',simulateResponse,...
            'verbose',verbosePsychObj);
    end
    % Clear out the first, bad "getResponse". Not sure why but the first
    % call to this function after restart always fails. This fixes the
    % problem
    if ~simulateResponse
        storeResponseDur = sessionObj{ii}.responseDurSecs;
        sessionObj{ii}.responseDurSecs = 0.1;
        sessionObj{ii}.getResponse;
        sessionObj{ii}.responseDurSecs = storeResponseDur;
    end
    % Update the console text
    fprintf([num2str(ii) '...']);
end
fprintf('\n');

% Check if we should reset the search for any of our psych objects
if mod(measurementRecord.trialIdx-1,nTrialsPerStim*nStims)==0
    for ii=1:nStims
        sessionObj{ii}.resetSearch;
    end
end

% Start the session
if ~simulateResponse
    fprintf('Press any key to start trials\n');
    pause
end

% Store the block start time
for ii=1:nStims
    sessionObj{ii} .blockStartTimes(end+1) = datetime();
end

% Present nTrialsPerSession. We repeat trials that did not elicit a valid
% response (wrong key, or outside of response interval)
psychObjIdx = 1;
trialIdx = 1;
while trialIdx<=nTrialsPerSession
    validResponse = sessionObj{psychObjIdx}.presentTrial;
    if validResponse
        trialIdx = trialIdx + 1;
        psychObjIdx = psychObjIdx + 1;
        if psychObjIdx > nStims
            psychObjIdx = 1;
        end
    end
end

% Play a "done" tone
if ~simulateResponse
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
end

% Save the sessionObjs and create and save an updated figure
for ii=1:nStims
    % psychometric object
    fileStem = sessionData.fileStem{ii};
    filename = fullfile(dataDir,[fileStem '.mat']);
    clear psychObj
    psychObj = sessionObj{ii};
    % empty the CombiLEDObj handle
    psychObj.CombiLEDObj = [];
    save(filename,'psychObj');
    % figure
    if updateFigures
        figHandle = psychObj.plotOutcome('off');
        filename = fullfile(dataDir,[fileStem '.pdf']);
        saveas(figHandle,filename,'pdf')
    end
end

% Update and save the measurementRecord. First transfer fields from the
% sessionData.
fields = fieldnames(sessionData);
for ff = 1:length(fields)
    if ff==1
        measurementRecord.sessionData(end+1).(fields{ff}) = sessionData.(fields{ff});
    end
    measurementRecord.sessionData(end).(fields{ff}) = sessionData.(fields{ff});
end
measurementRecord.trialIdx = measurementRecord.trialIdx + nTrialsPerSession;

% Save it
filesuffix = ['_' subjectID '_' modDirectionNulledName '_' experimentName ...
    sprintf('_cntrst-%2.2f',p.Results.stimContrast) ];
filename = fullfile(dataDir,['measurementRecord' filesuffix '.mat']);
save(filename,'measurementRecord');


end
