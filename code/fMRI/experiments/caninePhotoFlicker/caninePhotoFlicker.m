
% Housekeeping
clear
close all
clc
rng(cputime); % Ensure that the attention events differ each time

% Flag to simulate the combiLED
simulateCombiLED = false;

% The name of the calibration file to use
calName = 'CombiLED-B_shortLLG_cassetteND1_longRandomA_classicEyePiece_ND0';
calSubDir = 'LDOG';

% Get observer properties
observerID = GetWithDefault('Subject ID','xxxx');

% The name of the directory in which to store the results files
dropboxBaseDir = getpref('combiExperiments','dropboxBaseDir');
sessionID = string(datetime('now','Format','yyyy-MM-dd'));

% Create the directory in which to save the data
resultDir = fullfile(dropboxBaseDir,'LDOG_data','Experiments','combiLED','photoFlicker',observerID,sessionID);
if ~isfolder(resultDir)
    mkdir(resultDir)
end

% Define some experiment properties
% 36 trials per acquition. Start with "on" (flicker) trial, then alternate
stimDirs = {'LightFlux','MLplusS','MLminusS'};
blockDirections = [2 3 1]; % Collect the acquisitions in the order L+S, L-S, LF
desiredContrastLevelsByDir = [0.949,0.35,0.25]; % The photoreceptor contrast levels we had in the original Mt Sinai data
freqHzByDir = [16,32,4];
trialDurSecs = 12;
trialDurShrink = 0.95; % Set the actual stimulus profile be slightly less than 12 seconds to allow time for updating settings in between blocks
halfCosineRampDurSecs = 1.5;
seq = [1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0];
nTrialsPerAcq = length(seq);
experimentStartKey = 't';

% Check if we are close to midnight, in which case there is a chance that
% the time-keeping mechanism in this routine (seconds of the day) will fail
if hour(datetime()) > 22
    warning('This routine uses the second-of-the-day to keep time. The experiment therefore turns into a pumpkin at midnight.')
end

% Load the calibration file
cal = loadCalByName(calName,calSubDir);

% Get the photoreceptor set for this observer
photoreceptors = photoreceptorDictionaryCanine();

% Different stimulus directions need different match constraints for the
% modulation search
matchConstraintSet = [3, 2.15, 2];

% Define some default background settings that produce good modulations for
% these directions and this calibration file
backgroundVecs{1} = [0.5000    0.5000    0.5000    0.5000    0.5000    0.5000    0.5000    0.5000]';
backgroundVecs{2} = [0.2048    0.4345    0.2000    0.2000    0.2000    0.5000    0.5000    0.4999]';
backgroundVecs{3} = [0.3990    0.2886    0.2012    0.2044    0.2004    0.5074    0.3501    0.4451]';

% Loop over the stimulus directions and create, store, and plot the
% resulting modulations
for ss = 1:3
    modResult{ss} = designModulation(stimDirs{ss},photoreceptors,cal,...
        'searchBackground',false,...
        'backgroundPrimary',backgroundVecs{ss},...
        'primaryHeadRoom',0.025,...
        'contrastMatchConstraint',matchConstraintSet(ss));
    plotModResult(modResult{ss});
end

% We want to replicate the contrast levels used in the prior canine
% studies. To do so, we have to scale down the modulations to match the
% prior (lower) contrast levels
for ss = 1:3
    maxContrastByDir(ss) = ...
        modResult{ss}.contrastReceptorsBipolar(modResult{ss}.meta.whichReceptorsToTarget(1));
end
modContrastByDir = desiredContrastLevelsByDir./maxContrastByDir;

% We need to adjust the contrast by frequency to account for a small amount
% of roll-off. This has the effect of "boosting" the called-for contrast at
% high levels
modContrastByFreq = 1./contrastAttenuationByFreq(freqHzByDir);

% Check if we are going to clip the contrast levels
clipStimIdx = find(modContrastByDir>1);
if ~isempty(clipStimIdx)
    for ii = 1:length(clipStimIdx)
        rr = clipStimIdx(ii);
        str = ['WARNING: Contrast clipping for ' stimDirs{rr} ', ' num2str(freqHzByDir(rr)) ' Hz. Called for contrast = ' num2str(modContrastByDir(rr)) '\n'];
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
    obj.setRampIndex(1); % half-cosine windowing
    obj.setRampDuration(1.5); % 1.5 second ramp on
    obj.setDuration(trialDurSecs*trialDurShrink);
    obj.setSettings(modResult{1}); % send some settings so we are presenting the background

end

% Wait during the preliminary acquisitions and soak up any stray keystrokes
% (e.g., testing the button box; TRs produced by the field map acquisition)
fprintf('****************************************************\n')
fprintf('   Press return when prelim acquisitions are done\n')
fprintf('(button presses and TRs will be ignored untill then)\n')
input(': ','s');
fprintf('****************************************************\n')

% Repeat acquisitions until we get a quit key
notDone = true;
acqIdx = 1;
while notDone

    % Create an empty variable that will store information about this
    % acquisition
    results = [];

    % Get the modulation direction, frequency, and contrast for this
    % acquisition
    thisDir = blockDirections(mod(acqIdx-1,3)+1);
    thisModResult = modResult{thisDir};
    thisFreq = freqHzByDir(thisDir);
    deviceContrast = min([1,modContrastByDir(thisDir) * modContrastByFreq(thisDir)]);

    % Send the modulation settings to the combiLED
    if ~simulateCombiLED
        obj.setSettings(thisModResult);
        obj.setFrequency(thisFreq);
        obj.setContrast(deviceContrast);
    end

    % Create a keypress response window and wait for a t
    fh = figure( 'units','pixels',...
        'Name','Wait for t...',...
        'position',[500 500 200 260],...
        'menubar','none',...
        'numbertitle','off','resize','off');
    waitforbuttonpress;
    notValidKeyFlag = true;
    while notValidKeyFlag
        if strcmp(fh.CurrentCharacter,experimentStartKey)
            notValidKeyFlag = false;
        else
            waitforbuttonpress;
        end
    end
    close(fh);

    % Announce we are starting
    fprintf('starting\n')
    fprintf([sprintf('Acquisition %d: ',acqIdx),stimDirs{thisDir},'\n']);
    fprintf('   trial: ');

    % Start the timer for this acquisition
    acqStartTimeDateTime = datetime();
    acqStartTimeSecs = second(datetime(),'secondofday');    
    trialStartTimeSecs = acqStartTimeSecs;
    trialCounter = 1;

    % Loop over trials in the acquisition
    while trialCounter <= nTrialsPerAcq

        % How long this trial will last?
        trialStartTimeSecs = second(datetime(),'secondofday');
        trialStopTimeSecs = acqStartTimeSecs+trialDurSecs*trialCounter;

        % Announce the trial to the console
        fprintf('%d ',trialCounter);

        % Start the combiLED if we are not simulating
        if ~simulateCombiLED
            obj.setContrast(deviceContrast*seq(trialCounter));
            obj.startModulation;
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
        trialStartTimeSecs = trialStartTimeSecs+trialDurSecs;
        trialCounter = trialCounter+1;
    end

    % Get the time when we were done presenting trials
    acqStopTimeDateTime = datetime();
    acqStopTimeSecs = second(datetime(),'secondofday');

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
    fprintf('\nFinished acquisition. Press space to prepare for the next acquisition, or q to quit...')

    % Create a keypress response window and wait for space or q
    fh = figure( 'units','pixels',...
        'Name','Next acquisition...',...
        'position',[500 500 200 260],...
        'menubar','none',...
        'numbertitle','off','resize','off');
    waitforbuttonpress;
    notValidKeyFlag = true;
    while notValidKeyFlag
        switch fh.CurrentCharacter
            case ' '
                acqIdx = acqIdx + 1;
                fprintf('preparing\n')
                notValidKeyFlag = false;
            case 'q'
                notDone = false;
                notValidKeyFlag = false;
            otherwise
                waitforbuttonpress;
        end
    end
    close(fh);

end

% Announce that we are done
fprintf('Finished experiment.\n')

% Clean up combiLED
if ~simulateCombiLED; obj.serialClose; end

