function presentTrial(obj)

% Create a figure that will be used to collect key presses
currKeyPress='0';
S.fh = figure( 'units','pixels',...
    'position',[500 500 200 260],...
    'menubar','none','name','move_fig',...
    'numbertitle','off','resize','off',...
    'keypressfcn',@f_capturekeystroke,...
    'CloseRequestFcn',@f_closecq);
S.tx = uicontrol('style','text',...
    'units','pixels',...
    'position',[60 120 80 20],...
    'fontweight','bold');
guidata(S.fh,S)

% Get the trialData
trialData = obj.trialData;

% Get the current trial index
if isempty(trialData)
    currTrialIdx = 1;
else
    currTrialIdx = length(trialData)+1;
end

% Pick a reference frequency from a uniform distribution of log frequencies
% within the test frequency range
refFreqRangeHz = obj.refFreqRangeHz;
refFreq = 10^(rand()*diff(log10(refFreqRangeHz))+log10(min(refFreqRangeHz)));

% Pick the initial state of the test stimulus, which is selected from a
% uniform log distribution around the reference frequency. The width of the
% distribution is set by the testRangeDecibels parameter.
testRangeDecibels = obj.testRangeDecibels;
testFreqRangeHz = [refFreq/db2mag(testRangeDecibels), ...
    refFreq*db2mag(testRangeDecibels)];
testFreq = 10^(rand()*diff(log10(testFreqRangeHz))+log10(min(testFreqRangeHz)));

% Save the initial testFreqState
testFreqInitial = testFreq;

% Determine the rate of change of the test stimulus in response to button
% presses
testFreqChangeRateDbsPerSec = obj.testFreqChangeRateDbsPerSec;
testRefreshIntervalSecs = obj.testRefreshIntervalSecs;
testFreqChangePerRefresh = testFreqChangeRateDbsPerSec / (1 / testRefreshIntervalSecs);

% Get the desired reference and test contrast
refContrast = obj.refContrast;
testContrast = obj.testContrast;

% Prepare the sounds
Fs = 8192; % Sampling Frequency
dur = 0.1; % Duration in seconds
t  = linspace(0, dur, round(Fs*dur));
lowTone = sin(2*pi*500*t);
midTone = sin(2*pi*750*t);
highTone = sin(2*pi*1000*t);
readySound = [lowTone midTone highTone];
correctSound = sin(2*pi*750*t);
incorrectSound = sin(2*pi*250*t);
badSound = [sin(2*pi*250*t) sin(2*pi*250*t)];
audioObjs.low = audioplayer(lowTone,Fs);
audioObjs.mid = audioplayer(midTone,Fs);
audioObjs.high = audioplayer(highTone,Fs);
audioObjs.ready = audioplayer(readySound,Fs);
audioObjs.correct = audioplayer(correctSound,Fs);
audioObjs.incorrect = audioplayer(incorrectSound,Fs);
audioObjs.bad = audioplayer(badSound,Fs);

% Determine if we have random phase or not
if obj.randomizePhase
    refPhase = round(rand())*pi;
    testPhase = round(rand())*pi;
else
    refPhase = 0;
    testPhase = 0;
end

% Store the trial start time
trialData(currTrialIdx).trialStartTime = datetime();


%% Present the reference
% Adjust the contrast of the stimulus to account for device attenuation of
% the modulation at high temporal frequencies
refContrastAdjusted = refContrast / contrastAttenuationByFreq(refFreq);

% Prepare the reference stimulus
obj.CombiLEDObj.setContrast(refContrastAdjusted);
obj.CombiLEDObj.setFrequency(refFreq);
obj.CombiLEDObj.setPhaseOffset(refPhase);

% Alert the subject the trial is about to start
audioObjs.ready.play;
stopTimeSeconds = cputime() + 2;
obj.waitUntil(stopTimeSeconds);

% Present the reference stimulus
audioObjs.correct.play;
stopTimeSeconds = cputime() + obj.refDurationSecs;
obj.CombiLEDObj.startModulation;
obj.waitUntil(stopTimeSeconds);
obj.CombiLEDObj.stopModulation;

% Wait for the inter-stimulus interval
stopTimeSeconds = cputime() + obj.interStimulusIntervalSecs;
obj.waitUntil(stopTimeSeconds);


%% Present the test
% Start the test stimulus
audioObjs.correct.play;
obj.CombiLEDObj.setFrequency(testFreq);
obj.CombiLEDObj.setPhaseOffset(testPhase);
testContrastAdjusted = testContrast / contrastAttenuationByFreq(testFreq);
obj.CombiLEDObj.updateContrast(testContrastAdjusted);
obj.CombiLEDObj.startModulation;

% Start the response interval
lastRefreshTime = cputime();
stopTimeSeconds = cputime() + obj.testDurationSecs;
stillWaiting = true;
while stillWaiting
    if cputime() > (lastRefreshTime + testRefreshIntervalSecs)
        drawnow
        switch currKeyPress
            case {'rightarrow'}
                testFreq = testFreq * db2mag(testFreqChangePerRefresh);
            case {'leftarrow'}
                testFreq = testFreq / db2mag(testFreqChangePerRefresh);
            case {'space','return','downarrow'}
                stillWaiting = false;
        end

        % Clear the keypress
        currKeyPress = '';

        % Keep the test frequency in bounds
        testFreq = min([testFreq,max(testFreqRangeHz)]);
        testFreq = max([testFreq,min(testFreqRangeHz)]);

        % Update the frequency
        obj.CombiLEDObj.updateFrequency(testFreq);

        % Adjust the contrast for the current frequency
        testContrastAdjusted = testContrast / contrastAttenuationByFreq(testFreq);
        obj.CombiLEDObj.updateContrast(testContrastAdjusted);

        % Update the refresh timer
        lastRefreshTime = cputime();
    end

    % Check if we have exceeded the response interval
    if cputime()>stopTimeSeconds
        stillWaiting = false;
    end

end

% Stop the modulation
obj.CombiLEDObj.stopModulation;

% Store the end time
trialData(currTrialIdx).trialStartTime = datetime();

% Close the keypress window
close(S.fh);

% Store the trial information
trialData(currTrialIdx).blockIdx = obj.blockIdx;
trialData(currTrialIdx).refFreq = refFreq;
trialData(currTrialIdx).refPhase = refPhase;
trialData(currTrialIdx).testFreq = testFreq;
trialData(currTrialIdx).testPhase = testPhase;
trialData(currTrialIdx).testFreqInitial = testFreqInitial;
obj.trialData = trialData;

% Handle verbosity
if obj.verbose
    fprintf('trial: %d, contrast %2.1f, test freq Hz = %2.1f, choice Hz = %2.1f, initial Hz = %2.1f \n', currTrialIdx, testContrast, refFreq, testFreq, testFreqInitial);
end

end

%% LOCAL FUNCTIONS

function  f_capturekeystroke(H,E)
% Get the keystroke
S2 = guidata(H);
set(S2.tx,'string',E.Key)
% Pass it back to the calling function
assignin('caller','currKeyPress',E.Key)
end

function f_closecq(src,callbackdata)
% Clean up for the window. Not doing anything currently.
delete(gcf)
end
