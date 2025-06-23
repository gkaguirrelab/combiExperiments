function presentTrial(obj, currentPair, currTargetPhotoContrast)

% Get the EOGControl
EMGControl = obj.EMGControl;

% Get the questData
questData = obj.questData;

% Get the current trial index
currTrialIdx = size(questData.trialData,1)+1;

% The calling function sets the reference frequency, and the contrast of
% the test and ref
refFreqHz = obj.refFreqHz(currentPair(1));
refModContrast = obj.refModContrast(currentPair(2));

% Get the adjustment for the relative difference in photoreceptor contrast
% between the two modResults / combiLEDs
relativePhotoContrastCorrection = obj.relativePhotoContrastCorrection;


% Define the stimulus params. This is a 2x3 vector with the dimensions
% corresponding to:
%       combiLED (1 or 2), and param (contrast, freq,phase)
stimParams = zeros(2,3);


% Define the phase parameters for the reference interval. The phase is
% randomly selected and set to be pi/2 out of phase between the two sides.
% We have considered accounting for the delay in starting the 2nd combiLED
% relative to the first, but have decided this is too small of an effect to
% address.
refIntervalPhaseBySide(1) = rand()*pi;
refIntervalPhaseBySide(2) = refIntervalPhaseBySide(1) + 0.001*refFreqHz*2*pi; % Accounting for phase offset between combis

% The same contrast and frequency is shown on the two sides. 
for side = 1:2
    % Contrast
    stimParams(side,1) = ...
        relativePhotoContrastCorrection(side) * ...
        (refModContrast / contrastAttenuationByFreq(refFreqHz));
    % Frequency
    stimParams(side,2) = refFreqHz;
    % Phase 
    stimParams(side,3) = refIntervalPhaseBySide(side);
end

% Prepare the sounds
Fs = 8192; % Sampling Frequency
dur = 0.1; % Duration in seconds
t  = linspace(0, dur, round(Fs*dur));

lowTone = sin(2*pi*500*t);
midTone = sin(2*pi*750*t);
highTone = sin(2*pi*1000*t);

readySound = [highTone highTone highTone];
correctSound = [lowTone midTone highTone];

audioObjs.low = audioplayer(lowTone,Fs);
audioObjs.mid = audioplayer(midTone,Fs);
audioObjs.high = audioplayer(highTone,Fs);
audioObjs.ready = audioplayer(readySound,Fs);
audioObjs.correct = audioplayer(correctSound,Fs);

% Create a figure that will be used to collect key presses if we are using
% the keyboard
[currKeyPress,S] = createResponseWindow();

% Handle verbosity
if obj.verbose
    fprintf('Trial %d; Ref Contrast %2.2f; Ref freq %2.2f; Test freq %2.2f. Enter a number from 1-10 (0 for 10): ', ...
        currTrialIdx,stimParams(1,1),stimParams(1,2),stimParams(2,2));
end

% Present the stimuli

% Prepare the combiLEDs
for side = 1:2
    obj.CombiLEDObjArr{side}.setContrast(stimParams(side,1));
    obj.CombiLEDObjArr{side}.setFrequency(stimParams(side,2));
    obj.CombiLEDObjArr{side}.setPhaseOffset(stimParams(side,3));
end

% Wait half a second to make sure that the CombiLEDs have received
% these new settings
stopTime = cputime() + 0.5;
obj.waitUntil(stopTime);

% Start the stimuli and sound a tone. Wait for stimDurSecs.
% We observe that starting the combiLEDs in reverse order results in
% less of a timing discrepancy between them. We do not yet fully
% understand why this might be the case.
stopTime = cputime() + obj.stimDurSecs;
for side = [2 1]
    obj.CombiLEDObjArr{side}.startModulation;
end
audioObjs.low.play;

% Start the EMG recording - slightly shorter than stimulus duration
if obj.EMGFlag
    EMGControl.trialDurationSecs = obj.stimDurSecs - 0.5;  % To account for LabJack connection lag
    [EMGdata] = EMGControl.recordTrial();
end

obj.waitUntil(stopTime);

% Start the response interval
currKeyPress = '';  % To make sure currKeyPress doesn't have old data in it
if obj.discomfortFlag
    [keyPress, responseTimeSecs] = getKeyboardResponse(currKeyPress,Inf,{'0','1','2','3','4','5','6','7','8','9','hyphen'});
    if ~isempty(keyPress)
        switch keyPress
            case {'0'}
                discomfortRating = 0;
            case {'1'}
                discomfortRating = 1;
            case {'2'}
                discomfortRating = 2;
            case {'3'}
                discomfortRating = 3;
            case {'4'}
                discomfortRating = 4;
            case {'5'}
                discomfortRating = 5;
            case {'6'}
                discomfortRating = 6;
            case {'7'}
                discomfortRating = 7;
            case {'8'}
                discomfortRating = 8;
            case {'9'}
                discomfortRating = 9;
            case {'hyphen'}
                discomfortRating = 10;
        end
    end
    % Close the response window
    close(S.fh);
else
    [keyPress, responseTimeSecs] = getKeyboardResponse(currKeyPress,Inf,{'0','1','2','3','4','5','6','7','8','9','-'});
    if ~isempty(keyPress)
        switch keyPress
            case {'0'}
                entopticResponse = 0;
            case {'1'}
                entopticResponse = 1;
            case {'2'}
                entopticResponse = 2;
            case {'3'}
                entopticResponse = 3;
            case {'4'}
                entopticResponse = 4;
            case {'5'}
                entopticResponse = 5;
            case {'6'}
                entopticResponse = 6;
            case {'7'}
                entopticResponse = 7;
            case {'8'}
                entopticResponse = 8;
            case {'9'}
                entopticResponse = 9;
            case {'-'}
                entopticResponse = 10;
        end
    end
    % Close the response window
    close(S.fh);

    % New response window for second question - Purkinje
    [currKeyPress,S] = createResponseWindow();
    currKeyPress = '';

    fprintf('\nDid the participant see a Purkinje tree? 0 (no) 1 (yes): ');

    [keyPress, responseTimeSecs] = getKeyboardResponse(currKeyPress,Inf,{'0','1'});

    switch keyPress
        case {'0'}
            purkinjeResponse = 0;
        case {'1'}
            purkinjeResponse = 1;
    end

    % Close the response window
    close(S.fh);

end

% Stop the stimuli (needed as the subject may have responded before the
% stimuli have completed)
for side = 1:2
    obj.CombiLEDObjArr{side}.stopModulation;
end

% Wait half a second for an inter-trial-interval
stopTime = cputime() + 0.5;
obj.waitUntil(stopTime);

% We will play the "correct" tone when they enter a response
audioObjs.correct.play;
obj.waitUntil(cputime()+1);


% Finish the line of text output
if obj.verbose
    fprintf('\n');
end

% Put staircaseData back into the obj

if ~iscell(obj.discomfEMGdata)
    obj.discomfEMGdata = {};
    obj.entoptEMGdata = {};
end

if obj.discomfortFlag
    obj.discomfortRating(end+1) = discomfortRating;
    obj.responseTimeSecs(end+1) = responseTimeSecs;
    obj.contrastOrder(end+1) = currTargetPhotoContrast;
    obj.refFreqOrder(end+1) = stimParams(1,2);
    if obj.EMGFlag
        obj.discomfEMGdata{end+1} = EMGdata;
    end
else
    obj.entopticResponse(end+1) = entopticResponse;
    obj.purkinjeResponse(end+1) = purkinjeResponse;
    obj.contrastOrder(end+1) = currTargetPhotoContrast;
    obj.refFreqOrder(end+1) = stimParams(1,2);
    obj.responseTimeSecs(end+1) = responseTimeSecs;
    if obj.EMGFlag
        obj.entoptEMGdata{end+1} = EMGdata;
    end

end

end