function runDCPT_detect(subjectID,NDlabel,testFreqSetHz,varargin)
% Psychometric measurement of contrast detection thresholds using a
% dichoptic, binocular rig at a set of frequencies for two post-receptoral
% directions (LMS and L-M).
%
% Examples:
%{
    subjectID = 'SM';
    NDlabel = '1';
    testFreqSetHz = [3 5.4216 9.798 17.7069 32];
    runDCPT_detect(subjectID,NDlabel,testFreqSetHz);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('dropBoxSubDir','FLIC_data',@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('modDirections',{'LminusM_wide','LightFlux'},@iscell);
p.addParameter('testLogContrastSets',{...
    linspace(log10(0.01),log10(0.25),31),...
    linspace(log10(0.0011),log10(0.25),31)},@iscell);
p.addParameter('nTrialsPerBlock',30,@isnumeric);
p.addParameter('nBlocks',10,@isnumeric);
p.addParameter('useStaircase',false,@islogical);
p.addParameter('verboseCombiLED',false,@islogical);
p.addParameter('verbosePsychObj',true,@islogical);
p.addParameter('simulateResponse',false,@islogical);
p.addParameter('simulateStimuli',false,@islogical);
p.addParameter('randomCombi',true,@islogical);
p.addParameter('useKeyboardFlag',false,@islogical);
p.parse(varargin{:})

%  Pull out of the p.Results structure
nTrialsPerBlock = p.Results.nTrialsPerBlock;
nBlocks = p.Results.nBlocks;
useStaircase = p.Results.useStaircase;
modDirections = p.Results.modDirections;
testLogContrastSets = p.Results.testLogContrastSets;
verboseCombiLED = p.Results.verboseCombiLED;
verbosePsychObj = p.Results.verbosePsychObj;
simulateResponse = p.Results.simulateResponse;
simulateStimuli = p.Results.simulateStimuli;
randomCombi = p.Results.randomCombi;
useKeyboardFlag = p.Results.useKeyboardFlag;

% Set our experimentName
experimentName = 'DCPT_detect';

% Set a random seed
rng('shuffle');

% Define the modulation and data directories
subjectDir = fullfile(...
    p.Results.dropBoxBaseDir,...
    p.Results.dropBoxSubDir,...
    p.Results.projectName,...
    subjectID);

% Define the full paths to the modResult files
combiLEDLabelSet = {'C','D'};
for cc = 1:length(combiLEDLabelSet)
    for dd = 1:2
        modResultFiles{cc,dd} = ...
            fullfile(subjectDir,[modDirections{dd} '_ND' NDlabel],['modResult_' combiLEDLabelSet{cc} '.mat']);
    end
end

% Load modResult files and extract the calibrations. We need this to
% obtain a gamma table to pass to the combiLEDs, and this property of the
% device does not change with modulation direction
% CombiLED C
load(modResultFiles{1,1},'modResult');
calC = modResult.meta.cal;

% CombiLED D
load(modResultFiles{2,1},'modResult');
calD = modResult.meta.cal;

% Set up the CombiLED
if simulateStimuli
    CombiLEDObj1 = [];
    CombiLEDObj2 = [];
else
    % Open the CombiLED
    CombiLEDObj1 = CombiLEDcontrol('verbose',verboseCombiLED);
    CombiLEDObj2 = CombiLEDcontrol('verbose',verboseCombiLED);

    % Check the identifierString and swap objects if needed
    if CombiLEDObj1.identifierString == "A10L31XZ" % wrong identifier
        % Swap the objects
        tempObj = CombiLEDObj1;
        CombiLEDObj1 = CombiLEDObj2;
        CombiLEDObj2 = tempObj;
    end

    % Update the gamma table
    CombiLEDObj1.setGamma(calC.processedData.gammaTable);
    CombiLEDObj2.setGamma(calD.processedData.gammaTable);
end

% Provide instructions
if useKeyboardFlag

    fprintf('**********************************\n');
    fprintf('On each of many trials you will be presented with flicker\n');
    fprintf('on the left and right. Your job is to indicate which side\n');
    fprintf('had the faster flickering stimulus by pressing the 1(left) or 2(right) key on the\n');
    fprintf('keyboard. Each block has %d trials in a row after\n',nTrialsPerBlock);
    fprintf('which you may take a brief break. There are a total of %d blocks.\n',nBlocks);
    fprintf('**********************************\n\n');

else

    fprintf('**********************************\n');
    fprintf('On each of many trials you will be presented with flicker\n');
    fprintf('on the left and right. Your job is to indicate which side\n');
    fprintf('had the faster flickering stimulus by pressing the left or right\n');
    fprintf('bumpers on the game pad. Each block has %d trials in a row after\n',nTrialsPerBlock);
    fprintf('which you may take a brief break. There are a total of %d blocks.\n',nBlocks);
    fprintf('**********************************\n\n');

end

% Prepare to loop over blocks
for bb=1:nBlocks

    % Switch back and forth between the modulation directions
    directionIdx = mod(bb,2)+1;

    % Load the previously generated modResult file for this direction
    load(modResultFiles{1,directionIdx},'modResult');
    modResultC = modResult; clear modResult;

    load(modResultFiles{2,directionIdx},'modResult');
    modResultD = modResult;

    % Create a directory for the subject
    dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabel],experimentName);
    if ~isfolder(dataDir)
        mkdir(dataDir)
    end

    % Assemble the psychObj array, looping over the reference frequencies
    psychObjArray = cell(length(testFreqSetHz));

    for rr = 1:length(testFreqSetHz)

        % Define the filestem for this psychometric object
        dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabel ],experimentName);
        psychFileStem = [subjectID '_' modDirections{directionIdx} '_' experimentName,'.','x', ...
            '_refFreq-' num2str(testFreqSetHz(rr)) 'Hz' ];

        % Create or load the psychometric object
        filename = fullfile(dataDir,[psychFileStem '.mat']);
        if isfile(filename)
            % Load the object
            load(filename,'psychObj');
            % Put in the fresh CombiLEDObjs
            psychObj.CombiLEDObj1 = CombiLEDObj1;
            psychObj.CombiLEDObj2 = CombiLEDObj2;
            % Increment blockIdx
            psychObj.blockIdx = psychObj.blockIdx+1;
            psychObj.blockStartTimes(psychObj.blockIdx) = datetime();
            % Update the useStaircase flag in case this has changed
            psychObj.useStaircase = useStaircase;
            % Update the simulate stimuli and response flags in case this has changed
            psychObj.simulateResponse = simulateResponse;
            psychObj.simulateStimuli = simulateStimuli;
            % Update the random combi setting
            psychObj.randomCombi = randomCombi;
            % Update the keyboard flag
            psychObj.useKeyboardFlag = useKeyboardFlag;
        else
            % Create the object
            psychObj = PsychDichopticFlickerDetect(CombiLEDObj1, CombiLEDObj2, modResultC, modResultD, ...
                 testFreqSetHz(rr), ...
                'verbose',verbosePsychObj, ...
                'testLogContrastSet',testLogContrastSets{directionIdx},...
                'simulateResponse',simulateResponse,...
                'simulateStimuli',simulateStimuli,...
                'useStaircase', useStaircase,...
                'randomCombi', randomCombi, ...
                'useKeyboardFlag', useKeyboardFlag);
            % Store the filename
            psychObj.filename = filename;
        end

        % Store in the psychObjArray
        psychObjArray{rr} = psychObj;

        % Clear the psychObj
        clear psychObj

    end

    % Initialize the display for one of the psychObj elements. This routine
    % assumes that all of the psychObj elements that will be called during
    % the block use the same modulation, modulation background, temporal
    % profile (i.e., sinusoid), and trial duration.
    psychObjArray{1}.initializeDisplay;

    if useKeyboardFlag     % If using keyboard

        % Start the block
        fprintf('Press enter to start block %d...',bb);

        input('');

    else

        % Start the block
        fprintf('Press button 1, 2, 3, or 4 to start block %d...',bb);

        while true  % If using gamepad
            buttonState1 = Gamepad('GetButton', 1, 1);
            buttonState2 = Gamepad('GetButton', 1, 2);
            buttonState3 = Gamepad('GetButton', 1, 3);
            buttonState4 = Gamepad('GetButton', 1, 4);

            if buttonState1 == 1 || buttonState2 == 1 || buttonState3 == 1 || buttonState4 == 1
                break
            end

        end

    end

    % Store the block start time
    for rr = 1:length(testFreqSetHz)
        blockStartTime = datetime();
        psychObjArray{rr}.blockStartTimes(psychObjArray{rr}.blockIdx) = blockStartTime;
    end

    % Verify that the number of trials per block is compatible with the
    % number of test frequencies.
    if mod(nTrialsPerBlock, length(testFreqSetHz) * 2) ~= 0
        error(['The number of trials must be even and a ' ...
            'multiple of the number of reference frequencies.'])
    end

    % Randomizing the order that reference frequencies are presented in. 
    % Reference frequency vector, which will contain indices of testFreqSetHz
    testFreqHzIndex = zeros(1, nTrialsPerBlock);

    % Group the trials so each reference frequency is presented an equal
    % number of times
    group = ceil(nTrialsPerBlock / length(testFreqSetHz)); 
    startIdx = 1;

    % Loop through indices
    for ii = 1:length(testFreqSetHz)

        % Find the end index for the current group (range of columns)
        endIdx = startIdx + group - 1;
      
        % Assign the current testFreqSetHz index value to the current group
        testFreqHzIndex(1, startIdx:endIdx) = ii;

        startIdx = endIdx + 1;

    end

    % Now randomize the test frequency order
    testFreqHzIndex = testFreqHzIndex(randperm(nTrialsPerBlock));

    % Present nTrials
    for ii = 1:nTrialsPerBlock
        psychObjArray{testFreqHzIndex(ii)}.presentTrial();
    end

    % Report completion of this block
    fprintf('done.\n');

    % Store the psychObjArray entries
    for rr = 1:length(testFreqSetHz)
        % Grab the next psychObj
        psychObj = psychObjArray{rr};
        % empty the CombiLEDObj handles and save the psychObj
        psychObj.CombiLEDObj1 = [];
        psychObj.CombiLEDObj2 = [];
        save(psychObj.filename,'psychObj');
    end

end % block loop

% Clean up
if ~simulateStimuli
    CombiLEDObj1.goDark;
    CombiLEDObj1.serialClose;

    CombiLEDObj2.goDark;
    CombiLEDObj2.serialClose;
end
clear CombiLEDObj1
clear CombiLEDObj2


end % function
