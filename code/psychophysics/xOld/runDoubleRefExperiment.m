function runDiscrimExperiment(subjectID,modDirection,varargin)
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
    runDiscrimExperiment(subjectID,modDirection);
%}


% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('refContrastSetDb',[6,10],@isnumeric);
p.addParameter('testContrastSetDb',[4,6,8,10,12],@isnumeric);
p.addParameter('refFreqSetHz',[4,5,6,8,10,12,14,16,20,24,28,32,40],@isnumeric);
p.addParameter('testFreqSetHz',[6,10,14,20,28],@isnumeric);
p.addParameter('dataDirRoot','~/Desktop/flickerPsych',@ischar);
p.addParameter('observerAgeInYears',25,@isnumeric);
p.addParameter('pupilDiameterMm',4.2,@isnumeric);
p.addParameter('simulateStimuli',false,@islogical);
p.addParameter('simulateResponse',false,@islogical);
p.addParameter('verboseCombiLED',false,@islogical);
p.addParameter('verbosePsychObj',false,@islogical);
p.addParameter('updateFigures',false,@islogical);
p.parse(varargin{:})

%  Pull out of the p.Results structure
simulateStimuli = p.Results.simulateStimuli;
simulateResponse = p.Results.simulateResponse;
verboseCombiLED = p.Results.verboseCombiLED;
verbosePsychObj = p.Results.verbosePsychObj;
updateFigures = p.Results.updateFigures;

% Set our psychType
psychType = 'DoubleRef';

% Set a random seed
rng('shuffle');

% Initiate the PsychJava code. This silences a warning and prevents a
% problem with recording the first trial on startup
warnState = warning();
warning('off','MATLAB:Java:DuplicateClass');
PsychJavaTrouble();
warning(warnState);

% Define a location to save data
saveModDir = fullfile(p.Results.dataDirRoot,subjectID,modDirection);
saveDataDir = fullfile(p.Results.dataDirRoot,subjectID,modDirection,psychType);

% Create a directory for the subject
if ~isfolder(saveDataDir)
    mkdir(saveDataDir)
end

% Create or load a modulation and save it to the saveModDir
filename = fullfile(saveModDir,'modResult.mat');
if isfile(filename)
    load(filename,'modResult');
else
    % Issue a warning, as we should be working with the same modulation
    % that was used for the calculation of the contrast threshold. It is
    % possible that we have re-calibrated the device since then and that is
    % why we are re-creating the modulation
    warning('modResult not found; was expecting this from the CDT measurements')
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
filename = fullfile(saveDataDir,'measurementRecord.mat');
if isfile(filename)
    load(filename,'measurementRecord');
    testFreqSetHz = measurementRecord.stimulusProperties.testFreqSetHz;
    refFreqSetHz = measurementRecord.stimulusProperties.refFreqSetHz;
    refContrastSetDb = measurementRecord.stimulusProperties.refContrastSetDb;
    testContrastSetDb = measurementRecord.stimulusProperties.testContrastSetDb;
    refContrastSetMatrix = measurementRecord.stimulusProperties.refContrastSetMatrix;
    testContrastSetMatrix = measurementRecord.stimulusProperties.testContrastSetMatrix;
    nTrialsPerStim = measurementRecord.experimentProperties.nTrialsPerStim;
    nTrialsPerSession = measurementRecord.experimentProperties.nTrialsPerSession;
    nStimsPerSession = measurementRecord.experimentProperties.nStimsPerSession;
    nTrialsPerSearch = measurementRecord.experimentProperties.nTrialsPerSearch;
else
    % The reference and test contrast levels in db multipliers of threshold
    refContrastSetDb = p.Results.refContrastSetDb;
    testContrastSetDb = p.Results.testContrastSetDb;
    % The reference and test frequencies
    testFreqSetHz = p.Results.testFreqSetHz;
    refFreqSetHz = p.Results.refFreqSetHz;

    % The first thing is we need to calculate absolute device contrast
    % levels corresponding to multiples of the detection contrast
    % threshold. We load up the results for this subject and mod direction:
    filename = fullfile(saveModDir,'CDT','ContrastThresholdByFreq.mat');
    load(filename,'deviceContrastByFreqHz');

    % Calculate the device contrast attenuation across frequency; we need
    % this to check that our modulations will be within gamut
    deviceAttenuation = contrastAttentionByFreq(refFreqSetHz);

    % Now create a matrix of frequency x contrast levels, where each entry
    % is the absolute device contrast to be used for reference stimuli
    refContrastSetMatrix = [];
    for ii=1:length(refContrastSetDb)
        % We express the desired contrast levels in terms of decibels of
        % threshold contrast. Here we convert the Db value to a power
        % multiple, and then apply that scaling to function that provides
        % an interpolated absolute device contrast value as a function of
        refContrastSetMatrix(ii,:) = ...
            db2pow(refContrastSetDb(ii)) .* ...
            deviceContrastByFreqHz(refFreqSetHz);
        % Check that none of the values exceed the maximum available device
        % contrast modulation after correcting for device attenuation at
        % higher temporal frequencies
        if any((refContrastSetMatrix(ii,:)./deviceAttenuation) > 1)
            error('A reference contrast is out of gamut; adjust the db range')
        end
    end

    % Now do the same for the testContrastSetMatrix
    deviceAttenuation = contrastAttentionByFreq(testFreqSetHz);
    testContrastSetMatrix = [];
    for ii=1:length(testContrastSetDb)
        testContrastSetMatrix(ii,:) = ...
            db2pow(testContrastSetDb(ii)) .* ...
            deviceContrastByFreqHz(testFreqSetHz);
        if any((testContrastSetMatrix(ii,:)./deviceAttenuation) > 1)
            error('A test contrast is out of gamut; adjust the db range')
        end
    end

    % The number of stims and trials
    nStims = length(testContrastSetDb)*length(testFreqSetHz)*length(refContrastSetDb);
    nTrialsPerStim = 80; % Total n trials per stimulus
    nTrialsPerSession = 40; % ntrials in a session
    nStimsPerSession = 4; % n stimuli that will be intermixed in a session
    nTrialsPerSearch = 80; % n trials before resetting the QP search

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
    measurementRecord.experimentProperties.psychType = psychType;
    measurementRecord.experimentProperties.pupilDiameterMm = p.Results.pupilDiameterMm;
    measurementRecord.stimulusProperties.refContrastSetDb = refContrastSetDb;
    measurementRecord.stimulusProperties.testContrastSetDb = testContrastSetDb;
    measurementRecord.stimulusProperties.testFreqSetHz = testFreqSetHz;
    measurementRecord.stimulusProperties.refFreqSetHz = refFreqSetHz;
    measurementRecord.stimulusProperties.refContrastSetMatrix = refContrastSetMatrix;
    measurementRecord.stimulusProperties.testContrastSetMatrix = testContrastSetMatrix;
    measurementRecord.experimentProperties.nTrialsPerStim = nTrialsPerStim;
    measurementRecord.experimentProperties.nTrialsPerSession = nTrialsPerSession;
    measurementRecord.experimentProperties.nStimsPerSession = nStimsPerSession;
    measurementRecord.experimentProperties.nTrialsPerSearch = nTrialsPerSearch;
    measurementRecord.trialCount = zeros(length(testContrastSetDb),length(testFreqSetHz),length(refContrastSetDb));
    measurementRecord.sessionData = [];

    % Save the file
    filename = fullfile(saveDataDir,'measurementRecord.mat');
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
        stimIdx = [stimIdx; availStimIdx(1:nStimsStillNeeded)];
        stillLooking = false;
    end
    if nAvail < nStimsStillNeeded
        availStimIdx = availStimIdx(randperm(length(availStimIdx)));
        stimIdx = [stimIdx; availStimIdx];
        nStimsStillNeeded = nStimsStillNeeded - length(availStimIdx);
        countSetIdx = countSetIdx+1;
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
    [IdxX,IdxY,IdxZ] = ind2sub([length(testContrastSetDb),length(testFreqSetHz),length(refContrastSetDb)],stimIdx(ii));
    sessionData.measureIdx(ii) = stimIdx(ii);
    sessionData.testContrastDb(ii) = testContrastSetDb(IdxX);
    sessionData.testFreqHz(ii) = testFreqSetHz(IdxY);
    sessionData.refContrastDb(ii) = refContrastSetDb(IdxZ);    
    sessionData.fileStem{ii} = [subjectID '_' modDirection '_' psychType ...
        '_' strrep(num2str(sessionData.testContrastDb(ii)),'.','x') ...
        '_' strrep(num2str(sessionData.testFreqHz(ii)),'.','x') ...
        '_' strrep(num2str(sessionData.refContrastDb(ii)),'.','x')];
    % Assemble the stimulus inputs
    testFreqHz = sessionData.testFreqHz(ii);
    testContrast = testContrastSetMatrix(IdxX,IdxY);
    refContrastVector = refContrastSetMatrix(IdxZ,:);
    % Create or load the psychometric objects
    filename = fullfile(saveDataDir,[sessionData.fileStem{ii} '.mat']);
    if isfile(filename)
        tmpObj = load(filename,'psychObj');
        sessionObj{ii} = tmpObj.psychObj;
        clear tmpObj
        sessionObj{ii}.CombiLEDObj = CombiLEDObj;
        % Initiate the CombiLED settings
        sessionObj{ii}.initializeDisplay;
    else
        sessionObj{ii} = PsychDoubleRefAFC(CombiLEDObj,...
            testFreqHz,testContrast,refFreqSetHz,refContrastVector,...
            'giveFeedback',false,...
            'simulateStimuli',simulateStimuli,...
            'simulateResponse',simulateResponse,...
            'refContrastLabel',num2str(sessionData.refContrastDb(ii),2),...
            'testContrastLabel',num2str(sessionData.testContrastDb(ii),2),...
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

% % Check if we should reset the search for any of our psych objects
% for ii=1:nStimsPerSession
%     nCompletedTrials = measurementRecord.trialCount(sessionData.stimIdx(ii))+(nTrialsPerSession/nStimsPerSession);
%     if mod(nCompletedTrials,nTrialsPerSearch)==0
%         sessionObj{ii}.resetSearch;
%     end
% end

% Save the sessionObjs and create and save an updated figure
for ii=1:nStimsPerSession
    % psychometric object
    fileStem = sessionData.fileStem{ii};
    filename = fullfile(saveDataDir,[fileStem '.mat']);
    clear psychObj
    psychObj = sessionObj{ii};
    % empty the CombiLEDObj handle
    psychObj.CombiLEDObj = [];
    save(filename,'psychObj');
    % figure
    if updateFigures
        figHandle = psychObj.plotOutcome('off');
        filename = fullfile(saveDataDir,[fileStem '.pdf']);
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
filename = fullfile(saveDataDir,'measurementRecord.mat');
save(filename,'measurementRecord');

end

