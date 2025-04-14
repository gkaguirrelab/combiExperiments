function runDetectThreshExperiment(subjectID,modDirection,varargin)
% Code that interleaves psychometric measurements for measurements of a
% contrast detection threshold in a 2AFC experiment. The purpose is to
% measure threshold sensitivity across a range of stimulus frequencies. The
% code manages a series of files that store the data from the experiment.
% As configured, each testing "session" has 20 trials and is about 4
% minutes in duration.
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
p.addParameter('testFreqSetHz',[4,6,10,14,20,28,40],@isnumeric);
p.addParameter('observerAgeInYears',25,@isnumeric);
p.addParameter('pupilDiameterMm',4.2,@isnumeric);
p.addParameter('simulateStimuli',false,@islogical);
p.addParameter('simulateResponse',false,@islogical);
p.addParameter('verboseCombiLED',false,@islogical);
p.addParameter('verbosePsychObj',false,@islogical);
p.addParameter('updateFigures',true,@islogical);
p.parse(varargin{:})

%  Pull out of the p.Results structure
simulateStimuli = p.Results.simulateStimuli;
simulateResponse = p.Results.simulateResponse;
verboseCombiLED = p.Results.verboseCombiLED;
verbosePsychObj = p.Results.verbosePsychObj;
updateFigures = p.Results.updateFigures;

% Set our experimentName
experimentName = 'CDT';

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
    modResult = designModulation(modDirection,photoreceptors);
    save(filename,'modResult');
    figHandle = plotModResult(modResult,'off');
    filename = fullfile(modDir,'modResult.pdf');
    saveas(figHandle,filename,'pdf')
    close(figHandle)   
end

% Initiate the PsychJava code. This silences a warning and prevents a
% problem with recording the first trial on startup
warnState = warning();
warning('off','MATLAB:Java:DuplicateClass');
PsychJavaTrouble();
warning(warnState);

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
    testFreqSetHz = measurementRecord.stimulusProperties.testFreqSetHz;
    nTrialsPerStim = measurementRecord.experimentProperties.nTrialsPerStim;
    nTrialsPerSession = measurementRecord.experimentProperties.nTrialsPerSession;
    nStimsPerSession = measurementRecord.experimentProperties.nStimsPerSession;
    nTrialsPerSearch = measurementRecord.experimentProperties.nTrialsPerSearch;
else
    % The stimulus and experiment properties
    testFreqSetHz = p.Results.testFreqSetHz;
    nStims = length(testFreqSetHz);
    nTrialsPerStim = 120; % Total n trials per stimulus
    nTrialsPerSession = 40; % ntrials in a session
    nStimsPerSession = 4; % n stimuli that will be intermixed in a session
    nTrialsPerSearch = 40; % n trials before resetting the QP search

    % Check that we will have an integer number of trials for each stimulus
    % type within a session
    assert( mod(nTrialsPerSession,nStimsPerSession)==0 );
    nTrialsPerStimPerSession = nTrialsPerSession/nStimsPerSession;

    % Check that we can have an integer number of sessions before we reset
    % the QP search
    assert( mod(nTrialsPerSearch,nTrialsPerStimPerSession)==0 );
    
    % Check that we will have an integer number of sessions
    assert( mod(nStims*nTrialsPerStim,nTrialsPerSession)==0);

    % Store the values
    measurementRecord.subjectProperties.subjectID = subjectID;
    measurementRecord.subjectProperties.observerAgeInYears = p.Results.observerAgeInYears;
    measurementRecord.experimentProperties.modDirection = modDirection;
    measurementRecord.experimentProperties.experimentName = experimentName;
    measurementRecord.experimentProperties.pupilDiameterMm = p.Results.pupilDiameterMm;
    measurementRecord.stimulusProperties.testFreqSetHz = testFreqSetHz;
    measurementRecord.experimentProperties.nTrialsPerStim = nTrialsPerStim;
    measurementRecord.experimentProperties.nTrialsPerSession = nTrialsPerSession;
    measurementRecord.experimentProperties.nStimsPerSession = nStimsPerSession;
    measurementRecord.experimentProperties.nTrialsPerSearch = nTrialsPerSearch;
    measurementRecord.trialCount = zeros(1,length(testFreqSetHz));
    measurementRecord.sessionData = [];
    save(filename,'measurementRecord');
end

% Select the stimuli to test for this session. We select randomly from the
% set of stimuli that have the lowest number of collected trials.
trialCountSet = sort(unique(measurementRecord.trialCount(:)));

% First check if we are done
if min(trialCountSet) >= nTrialsPerStim
    fprintf('Done with this experiment!\n')
    return
end

% Find some stimuli that need measuring
countSetIdx = 1;
nStimsStillNeeded = nStimsPerSession;
stimIdx = [];
stillLooking = true;
while stillLooking
    availStimIdx = find(measurementRecord.trialCount==trialCountSet(countSetIdx));
    nAvail = length(availStimIdx);
    if nAvail == 0
        countSetIdx = countSetIdx+1;
        if min(measurementRecord.trialCount(:))>=nTrialsPerStim
            fprintf('Done with this experiment!\n')
            return
        end
    end
    if nAvail >= nStimsStillNeeded
        availStimIdx = availStimIdx(randperm(length(availStimIdx)));
        stimIdx = [stimIdx availStimIdx(1:nStimsStillNeeded)];
        stillLooking = false;
    end
    if nAvail < nStimsPerSession
        availStimIdx = availStimIdx(randperm(length(availStimIdx)));
        stimIdx = [stimIdx availStimIdx];
        nStimsStillNeeded = nStimsStillNeeded - length(availStimIdx);
        countSetIdx = 2;
    end
end

% Randomly order the stimIdx, so that the order of the intermixed stimuli
% will vary on every pass
stimIdx = stimIdx(randperm(length(stimIdx)));

% Set up the variables that hold this session information
fprintf('Preparing psychometric objects...');
sessionData = struct();
sessionData.stimIdx = stimIdx;
for ii=1:nStimsPerSession
    IdxX = stimIdx(ii);
    sessionData.measureIdx(ii) = IdxX;
    sessionData.testFreqHz(ii) = testFreqSetHz(IdxX);
    sessionData.fileStem{ii} = [subjectID '_' modDirection '_' experimentName ...
        '_' strrep(num2str(sessionData.testFreqHz(ii)),'.','x')];

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
        sessionObj{ii} = PsychDetectionThreshold(CombiLEDObj,...
            sessionData.testFreqHz(ii),...
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

% Start the session
if ~simulateResponse
    fprintf('Press any key to start trials\n');
    pause
end

% Store the block start time
for ii=1:nStimsPerSession
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
        if psychObjIdx > nStimsPerSession
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

% Check if we should reset the search for any of our psych objects
for ii=1:nStimsPerSession
    nCompletedTrials = measurementRecord.trialCount(sessionData.stimIdx(ii))+(nTrialsPerSession/nStimsPerSession);
    if mod(nCompletedTrials,nTrialsPerSearch)==0
        sessionObj{ii}.resetSearch;
    end
end

% Save the sessionObjs and create and save an updated figure
for ii=1:nStimsPerSession
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

% Update the trialCount record
measurementRecord.trialCount(sessionData.stimIdx) = ...
    measurementRecord.trialCount(sessionData.stimIdx)+(nTrialsPerSession/nStimsPerSession);

% Save it
filename = fullfile(dataDir,'measurementRecord.mat');
save(filename,'measurementRecord');

end
