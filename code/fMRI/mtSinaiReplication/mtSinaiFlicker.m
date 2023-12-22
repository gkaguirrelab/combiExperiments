
% Housekeeping
clear
close all
clc
rng(cputime); % Ensure that the attention events differ each time

% Flag to simulate the combiLED
simulateCombiLED = true;

% The name of the calibration file to use
calName = 'CombiLED_shortLLG_cassetteND1_longRandomA_stubby7TEyePiece_ND0';

% The name of the directory in which to store the results files
resultDir = '/Users/aguirre/Aguirre-Brainard Lab Dropbox/Geoffrey Aguirre/_Papers/Patterson_2023_EccentricityFlicker/HERO_cpg1_2023/scanResultFiles';

% Define some experiment properties
stimDirs = {'LightFlux','LminusM_wide','S_wide'};
desiredContrastLevelsByDir = [0.9,0.08,0.5]; % The photoreceptor contrast levels we had in the original Mt Sinai data
trialDurSecs = 12;
trialDurShrink = 0.95; % Set the actual stimulus profile be slightly less than 12 seconds to allow time for updating settings in between blocks
halfCosineRampDurSecs = 1.5;
freqSetHz = [0,2,4,8,16,32,64];
seqA = [5 2 4 5 7 2 5 4 2 7 3 6 5 1 2 3 7 6 1 7 1 3 5 6 4 1 1 1];
seqB = [1 6 6 2 1 5 3 2 2 6 7 4 6 3 3 4 4 3 1 1 4 7 7 5 5 1 1 1];
nTrialsPerAcq = length(seqA);
blockDirections = [1 2 3 3 2 1];
blockSeqs = {'A','A','A','B','B','B'};
nAcqsPerBlock = length(blockDirections);
attentionEventProbPerTrial = 0.33;
blinkDurSecs = 0.25;
attentionResponseDurSecs = 1.5;
validAttentionResponseSet = {'r','g','b','y'};
experimentStartKey = {'t'};

% Check if we are close to midnight, in which case there is a chance that
% the time-keeping mechanism in this routine (seconds of the day) will fail
if hour(datetime()) > 22
    warning('This routine uses the second-of-the-day to keep time. The experiment therefore turns into a pumpkin at midnight.')
end

% Load the calibration file
cal = loadCalByName(calName);

% Get observer properties
observerID = GetWithDefault('Subject ID','HERO_cpg1');
observerAgeInYears = str2double(GetWithDefault('Age in years','39'));
pupilDiameterMm = str2double(GetWithDefault('Pupil diameter in mm','7'));

% Get the photoreceptor set for this observer
photoreceptors = photoreceptorDictionaryHuman('observerAgeInYears',observerAgeInYears,'pupilDiameterMm',pupilDiameterMm);

% Modify the receptors to account for the transmittance of the contact lens
% worn by the observer
load('srf_filter_ContactLensMaterial_0_5mm_011216.mat','S_filter_ContactLensMaterial_0_5mm','srf_filter_ContactLensMaterial_0_5mm');
for ii=1:length(photoreceptors)
    photoreceptors(ii).ef.S = S_filter_ContactLensMaterial_0_5mm;
    photoreceptors(ii).ef.trans = srf_filter_ContactLensMaterial_0_5mm;
    photoreceptors(ii).ef.label = '0.5 mm Hioxifilcon D contact lens';
end

% This is a hard-coded, shifted background primary that does well for all
% stimulus directions
backgroundPrimary = [0.5222    0.4528    0.1896    0.5264    0.2302    0.3250    0.4875    0.4882]';

% Different stimulus directions need different match constraints for the
% modulation search
matchConstraintSet = [4, 2, 3];

% Loop over the stimulus directions and create, store, and plot the
% resulting modulations
for ss = 1:3
    modResult{ss} = designModulation(stimDirs{ss},photoreceptors,cal,...
        'searchBackground',false,...
        'contrastMatchConstraint',matchConstraintSet(ss),...
        'backgroundPrimary',backgroundPrimary);
    plotModResult(modResult{ss});
end

% We want to replicate the contrast levels used in the ASB and GKA Mt Sinai
% data collection. To do so, we have to scale down the modulations to match
% the prior (lower) contrast levels
for ss = 1:3
    maxContrastByDir(ss) = ...
        mean(abs(modResult{ss}.contrastReceptorsBipolar(modResult{ss}.meta.whichReceptorsToTarget(abs(modResult{ss}.meta.desiredContrast)>0))));
end
modContrastByDir = desiredContrastLevelsByDir./maxContrastByDir;

% We need to adjust the contrast by frequency to account for a small amount
% of roll-off. This has the effect of "boosting" the called-for contrast at
% high levels
modContrastByFreq = [1, 1./contrastAttentionByFreq(freqSetHz(2:end))];

% Check if we are going to clip the contrast levels
contrastCheck = modContrastByDir.*modContrastByFreq';
clipStimIdx = find(contrastCheck>1);
if ~isempty(clipStimIdx)
    for ii = 1:length(clipStimIdx)
        [r,c]=ind2sub(size(contrastCheck),clipStimIdx(ii));
        str = ['WARNING: Contrast clipping for ' stimDirs{c} ', ' num2str(freqSetHz(r)) ' Hz. Called for contrast = ' num2str(contrastCheck(r,c)) '\n'];
        fprintf(str);
    end
end

% Set up the combiLED
if ~simulateCombiLED

    % Open a CombiLEDcontrol object
    obj = CombiLEDcontrol();

    % Update the gamma table
    obj.setGamma(cal.processedData.gammaTable);

    % Setup the basic modulation properties
    obj.setWaveformIndex(1); % sinusoidal flicker
    obj.setBimodal(); % bimodal flicker around mid-point of the settings
    obj.setAMIndex(2); % half-cosine windowing
    obj.setAMFrequency(1/(trialDurSecs*2*trialDurShrink));
    obj.setAMValues([halfCosineRampDurSecs,0]); % duration half-cosine ramp; second value unused
    obj.setDuration(trialDurSecs*trialDurShrink);
    obj.setBlinkDuration(blinkDurSecs);
    obj.setSettings(modResult{1}); % send some settings so we are presenting the background

end

% Wait during the preliminary acquisitions and soak up any stray keystrokes
% (e.g., testing the button box; TRs produced by the field map acquisition)
fprintf('****************************************************\n')
fprintf('   Press return when prelim acquisitions are done\n')
fprintf('(button presses and TRs will be ignored untill then)\n')
input(': ','s');
fprintf('****************************************************\n')

% Create a keypress response window
[currKeyPress,S] = createResponseWindow();

% Loop over acquisitions in a block
for aa=1:nAcqsPerBlock

    % Create an empty variable that will store information about this
    % acquisition
    results = [];

    % Get the stimulus direction and appropriate mod results
    thisDir = blockDirections(aa);
    thisModResult = modResult{thisDir};

    % Send the modulation settings to the combiLED
    if ~simulateCombiLED; obj.setSettings(thisModResult); end

    % Assign the sequence order for this acquisition
    switch blockSeqs{aa}
        case 'A'
            thisSeq = seqA;
        case 'B'
            thisSeq = seqB;
    end

    % Wait for a "t" stimulus to start the acquisition
    fprintf('Waiting for a TR trigger...')
    getResponse(currKeyPress,Inf,experimentStartKey);

    % Announce we are starting
    fprintf('starting\n')
    fprintf([sprintf('Acquisition %d: ',aa),stimDirs{thisDir},', seq ',blockSeqs{aa},'\n']);
    fprintf('   trial: ');

    % Start the timer for this acquisition
    acqStartTimeDateTime = datetime();
    acqStartTimeSecs = second(datetime(),'secondofday');    
    trialStartTimeSecs = acqStartTimeSecs;
    trialCounter = 1;
    attentionEventCounter = 1;

    % Loop over trials in the acquisition
    while trialCounter <= nTrialsPerAcq

        % How long this trial will last?
        trialStartTimeSecs = second(datetime(),'secondofday');
        trialStopTimeSecs = acqStartTimeSecs+trialDurSecs*trialCounter;

        % Announce the trial to the console
        fprintf('%d ',trialCounter);

        % Update the frequency and contrast
        thisFreq = freqSetHz(thisSeq(trialCounter));
        deviceContrast = min([1,modContrastByDir(thisDir) * modContrastByFreq(thisSeq(trialCounter))]);

        % Update the combiLED if we are not simulating
        if ~simulateCombiLED

            % Special case the 0 Hz condition to prevent device errors
            if thisFreq ~= 0
                obj.updateFrequency(freqSetHz(thisSeq(trialCounter)));
                obj.updateContrast(deviceContrast);
            else
                obj.updateFrequency(0.01);
                obj.updateContrast(0);
            end

            % Start the modulation
            obj.startModulation;

        end

        % Determine and handle if this an attention event trial
        attentionEventFlag = rand()<attentionEventProbPerTrial;
        if attentionEventFlag
            % Define and wait until the attention event time
            attentionTriggerTimeSecs = trialStartTimeSecs + halfCosineRampDurSecs + rand()*(trialDurSecs-halfCosineRampDurSecs*2-blinkDurSecs);
            while second(datetime(),'secondofday')<attentionTriggerTimeSecs
            end
            attentionEventTimeSecs = second(datetime(),'secondofday');
            % Blink and wait for the responseDur
            if ~simulateCombiLED
                obj.blink
            else
                fprintf('* ');
            end
            [keyPress, responseTimeSecs] = getResponse(currKeyPress,attentionResponseDurSecs,validAttentionResponseSet);
            % Store the details of the event
            results.attentionEvents(attentionEventCounter).eventTimeSecs = attentionEventTimeSecs - acqStartTimeSecs;
            results.attentionEvents(attentionEventCounter).responseTimeSecs = responseTimeSecs;
            results.attentionEvents(attentionEventCounter).keyPress = keyPress;
            attentionEventCounter = attentionEventCounter+1;
        end

        % Wait until we have reached our stop time
        while second(datetime(),'secondofday')<trialStopTimeSecs
        end

        % Store trial information
        results.trialEvents(trialCounter).startTimeSecs = trialStartTimeSecs - acqStartTimeSecs;
        results.trialEvents(trialCounter).trialDurSecs = trialDurSecs;
        results.trialEvents(trialCounter).stimFreqHz = thisFreq;
        results.trialEvents(trialCounter).deviceContrast = deviceContrast;
        results.trialEvents(trialCounter).phoreceptorContrast = maxContrastByDir(thisDir) * modContrastByDir(thisDir);

        % Stop the modulation; update the timer and counter
        if ~simulateCombiLED; obj.stopModulation; end
        trialCounter = trialCounter+1;
    end

    % Get the time when we were done presenting trials
    acqStopTimeDateTime = datetime();
    acqStopTimeSecs = second(datetime(),'secondofday');

    % Report the attention trial performance
    attenVec = ~isnan([results.attentionEvents.responseTimeSecs]);
    fprintf('-- %d/%d correct\n',sum(attenVec),length(attenVec));

    % Add some acquisition-level information to the results
    results.observerID = observerID;
    results.thisDir = stimDirs{thisDir};
    results.modResult = thisModResult;
    results.acqStartTimeDateTime = acqStartTimeDateTime;
    results.acqStopTimeDateTime = acqStopTimeDateTime;
    results.acqDurationSecs = acqStopTimeSecs - acqStartTimeSecs;

    % Save the results file to disk
    filename = strrep(strrep([observerID sprintf('_%s.mat', datetime())],' ','_'),':','.');
    save(fullfile(resultDir,filename),'results');

    % Announce that we are done this acquisition
    if aa<nAcqsPerBlock
        fprintf('Finished acquisition. Press space to prepare for the next acquisition...')
        getResponse(currKeyPress,Inf,{'space'});
        fprintf('preparing\n')
    end
end

% Announce that we are done this block
fprintf('Finished block.\n')

% Clean up combiLED
if ~simulateCombiLED; obj.serialClose; end

% Close the keypress window
close(S.fh);


