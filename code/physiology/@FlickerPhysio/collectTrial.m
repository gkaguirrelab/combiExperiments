function collectTrial(obj)

% Determine if we are simulating the stimuli
simulateStimuli = obj.simulateStimuli;

% Get the time we started
    startTime = datetime();

% There is a roll-off (attenuation) of the amplitude of
% modulations with frequency. We can adjust for this property,
% and detect those cases which are outside of our ability to
% correct
stimFreqHz = obj.stimFreqHz;
stimContrastSet = obj.stimContrastSet;
stimContrastSetAdjusted = stimContrastSet ./ ...
    contrastAttentionByFreq(stimFreqHz);

% Get the stimulus order
stimContrastOrder = obj.stimContrastOrder;

% Check that the adjusted contrast does not exceed unity
mustBeInRange(stimContrastSetAdjusted,0,1);

% Prepare the sounds
Fs = 8192; % Sampling Frequency
dur = 0.1; % Duration in seconds
t  = linspace(0, dur, round(Fs*dur));
lowTone = sin(2*pi*500*t);
midTone = sin(2*pi*750*t);
highTone = sin(2*pi*1000*t);
readySound = [lowTone midTone highTone];
audioObjs.ready = audioplayer(readySound,Fs);
audioObjs.finished = audioplayer(fliplr(readySound),Fs);

% Handle verbosity
if obj.verbose
    fprintf('Freq [%2.2f Hz]...contrast: ', stimFreqHz);
end

% Update the file prefix for the pupil and VEP objects
filePrefix = sprintf('freq_%2.1f_trial_%02d_',obj.stimFreqHz,obj.trialIdx);
obj.vepObj.filePrefix = filePrefix;
obj.vepObj.trialIdx = 1;
filePrefix = sprintf('freq_%2.1f_',obj.stimFreqHz);
obj.pupilObj.filePrefix = filePrefix;
obj.pupilObj.trialIdx = obj.trialIdx;

% Present the stimuli
if ~simulateStimuli

    % Jittered inter trial interval
    jitterTimeSecs = (rand*range(obj.preTrialJitterRangeSecs) + min(obj.preTrialJitterRangeSecs));
    stopTime = tic() + 1e9 * jitterTimeSecs;
    obj.waitUntil(stopTime);
    
    % Set the video recording in motion.
    stopTime = tic() + 1e9 * obj.pupilVidStartDelaySec;
    obj.pupilObj.recordTrial;

    % Alert the subject the trial is about to start
    audioObjs.ready.play;

    % configure the CombiLED overall. This is a half-cosine windowed step
    % pulse.
    obj.CombiLEDObj.setFrequency(stimFreqHz);
    obj.CombiLEDObj.setAMIndex(2); % half-cosine ramped
    obj.CombiLEDObj.setAMFrequency(1/(2*obj.pulseDurSecs));
    obj.CombiLEDObj.setAMPhase(0);
    obj.CombiLEDObj.setAMValues([obj.halfCosineRampDurSecs, 0]);
    obj.CombiLEDObj.setDuration(obj.pulseDurSecs)

    % Finish waiting for pupil recording to have started
    obj.waitUntil(stopTime);

    % Loop over the elements of stimContrastOrder
    vepDataStructs={};
    cycleStopTimes = [];
    modulationStartTime = tic();
    for ii=1:length(stimContrastOrder)

        % Update the contrast for the stimulus
        contrastIdx = stimContrastOrder(ii);
        obj.CombiLEDObj.setContrast(stimContrastSetAdjusted(contrastIdx));

        % Handle verbosity
        if obj.verbose
            fprintf('%2.2f, ', stimContrastSet(contrastIdx));
        end

        % Start the stimulus
        stopTime = tic() + 1e9 * (obj.pulseDurSecs + obj.interStimIntervalSecs);
        obj.CombiLEDObj.startModulation;

        % Set the ssVEP recording in motion. This results in about a 75
        % msec delay until recording starts
        vepDataStructs{ii} = obj.vepObj.recordTrial;

        % Wait for the trial duration
        obj.waitUntil(stopTime);

        % Calculate and store the cycle overage, so we can adjust for the
        % actual modulation frequency in the pupil analysis
        cycleStopTimes(ii)=tic()-modulationStartTime;
    end

    % Store the ssVEP data
    for ii=1:length(stimContrastOrder)
        contrastIdx = stimContrastOrder(ii);
        contrastLabel = sprintf('contrast_%2.1f_',stimContrastSet(contrastIdx));
        obj.vepObj.storeTrial(vepDataStructs{ii},contrastLabel);
    end

    % Get the vid delay
    vidDelaySecs = nan;
    while isnan(vidDelaySecs)
        vidDelaySecs = obj.pupilObj.calcVidDelay(obj.trialIdx);
    end
    obj.trialData(obj.trialIdx).vidDelaySecs = vidDelaySecs;

    % Store the cycleStopTimes
    obj.trialData(obj.trialIdx).cycleStopTimes = cycleStopTimes;

    % Store the stimulus properties    
    obj.trialData(obj.trialIdx).jitterTimeSecs = jitterTimeSecs;
    obj.trialData(obj.trialIdx).stimFreqHz = stimFreqHz;
    obj.trialData(obj.trialIdx).stimContrastSet = stimContrastSet;
    obj.trialData(obj.trialIdx).stimContrastSetAdjusted = stimContrastSetAdjusted;
    obj.trialData(obj.trialIdx).stimContrastOrder = stimContrastOrder;

    % Play the finished tone
    audioObjs.finished.play;
    obj.waitUntil(tic() + 1e9);
    
end

% Store the startTime
obj.trialData(obj.trialIdx).startTime = startTime;

% Iterate the trialIdx
obj.trialIdx = obj.trialIdx+1;

% Finish the line of text output
if obj.verbose
    fprintf('\n');
end

end