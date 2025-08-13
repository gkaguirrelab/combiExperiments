function runDCPT_oneInt(subjectID,NDlabel,EOGFlag,varargin)
% Collect a session of dichoptic flicker discrimination measure,emts
%
% Syntax:
%   runDCPT_discrim(subjectID,NDlabel,EOGFlag)
%
% Description:
%   This function organizes the collection of data using the
%   PsychDichopticFlickerDiscrim psychometric object. This is a measure of
%   the ability of an observer to discriminate a change in the appearance
%   of a flickering stimulus. On each of many trials the observer is shown
%   a "reference" flicker on both sides of a dichoptic apparatus. After
%   they have indicated readiness, the flicker is stopped and, after a
%   brief ISI, a different, "test" flicker is presented on one side
%   (selected randomly) while the reference flicker is re-presented on the
%   other side. The obserer is asked to report which side has changed. A
%   staircase or QUEST+ procedure is used to vary the test flicker to
%   identify the frequency difference required to produce threshold
%   discrimination performance.
%
%   This routine connects to the CombiLED stimulus devices, creates and
%   subsequently loads the psychometric objects, and presents trials. Trial
%   are organized into blocks. A given block presents each of several
%   reference frequencies crossed with one or more reference contrasts.
%   Blocks alternate between different photoreceptor directions.
%
% Inputs:
%   subjectID             - Char vector or string. The ID of the subject.
%   NDlabel               - Char vector or string. The ND filter used to
%                           adjust the light level of the stimulus
%
% Optional key/value pairs:
%  'modDirections'        - Cell array of char vectors. The names of the
%                           modulation directions to study.
%  'refFreqHz'            - Vector. The reference frequencies to study.
%                           Typically, this is a log spaced set.
%  'targetPhotoContrast'  - 2xd vector, where d is the number of modulation
%                           directions to be studied. columns mod dir, rows
%                           are contrast level. Provides the low and high
%                           contrast levels to be studied. The default
%                           values are approximately 10x and 30x detection
%                           thresholds from pilot temporal contrast
%                           sensitivity functions detection measures. We
%                           found thresholds of approximately 0.005
%                           contrast for L-M and 0.01 contrast for LF at
%                           lower temporal frequencies. This seemed too
%                           high fo L-M, so we used 5x and 15x instead.
%
% Outputs:
%   none
%
% Examples:
%{
    subjectID = 'DEMO_2';
    NDlabel = '0x5';
    EOGFlag = false;
    runDCPT_oneInt(subjectID,NDlabel, EOGFlag);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('modDirections',{'LminusM_wide','LightFlux'},@iscell);
p.addParameter('refFreqHz',[3.0000    4.8206    7.7460   12.4467   20.0000],@isnumeric);
p.addParameter('targetPhotoContrast',[0.025, 0.10; 0.075, 0.30],@isnumeric);
p.addParameter('combiLEDLabels',{'C','D'},@iscell);
p.addParameter('combiLEDIDs',{"A10L31XJ","A10L31XZ"},@iscell);
p.addParameter('combiClockAdjust',[1.0006,0.9992],@isnumeric);
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('dropBoxSubDir','FLIC_data',@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('stimParams',linspace(0,6.75,25),@isnumeric);
p.addParameter('nTrialsPerBlock',20,@isnumeric);
p.addParameter('nBlocks',10,@isnumeric);
p.addParameter('useStaircase',true,@islogical);
p.addParameter('stairCaseStartDb',1,@isnumeric);
p.addParameter('verboseCombiLED',false,@islogical);
p.addParameter('verbosePsychObj',true,@islogical);
p.addParameter('simulateMode',false,@islogical);
p.addParameter('useKeyboardFlag',false,@islogical);
p.parse(varargin{:})

%  Pull out some variablse from the p.Results structure
modDirections = p.Results.modDirections;
refFreqHz = p.Results.refFreqHz;
targetPhotoContrast = p.Results.targetPhotoContrast;
stimParams = p.Results.stimParams;
combiLEDLabels = p.Results.combiLEDLabels;
combiLEDIDs = p.Results.combiLEDIDs;
nTrialsPerBlock = p.Results.nTrialsPerBlock;
nBlocks = p.Results.nBlocks;
useStaircase = p.Results.useStaircase;
verboseCombiLED = p.Results.verboseCombiLED;
verbosePsychObj = p.Results.verbosePsychObj;
simulateMode = p.Results.simulateMode;
useKeyboardFlag = p.Results.useKeyboardFlag;
combiClockAdjust = p.Results.combiClockAdjust;

% Set our experimentName
experimentName = 'DCPT_OneInt';

% Set the labels for the high and low stimulus ranges
stimParamSide = {'hi','low'};

% Define some basic trial type quantities
nSides = 2;
nFreqs = length(refFreqHz);
nContrasts = size(targetPhotoContrast,1);
nRanges = length(stimParamSide);
nTrialsPerCondition = nBlocks*nTrialsPerBlock / (length(modDirections)*nFreqs*nRanges*nContrasts);

% Set a random seed
rng('shuffle');

% Define the modulation and data directories
subjectDir = fullfile(...
    p.Results.dropBoxBaseDir,...
    p.Results.dropBoxSubDir,...
    p.Results.projectName,...
    subjectID);

% Load modResult files and extract the calibrations. We need this to
% obtain a gamma table to pass to the combiLEDs, and this property of the
% device does not change with modulation direction
for side = 1:nSides
    modResultFile{side} = ...
        fullfile(subjectDir,[modDirections{1} '_ND' NDlabel '_shifted'],['modResult_' combiLEDLabels{side} '.mat']);
    load(modResultFile{side},'modResult');
    cal{side} = modResult.meta.cal;
end

% Set up the CombiLED
if simulateMode
    CombiLEDObjArr = {[],[]};
else
    % Open the CombiLED
    for side = 1:nSides
        CombiLEDObjArr{side} = CombiLEDcontrol('verbose',verboseCombiLED);
    end

    % Check the identifierString and swap objects if needed
    if CombiLEDObjArr{1}.identifierString ~= combiLEDIDs{1} % wrong identifier
        % Swap the objects
        tempObj = CombiLEDObjArr{1};
        CombiLEDObjArr{1} = CombiLEDObjArr{2};
        CombiLEDObjArr{2} = tempObj;
        clear tempObj
    end

    % Test that the CombiLED objects now have the correct identifier
    % strings, and update the gamma table
    for side = 1:nSides
        assert(CombiLEDObjArr{side}.identifierString == combiLEDIDs{side});
        CombiLEDObjArr{side}.setGamma(cal{side}.processedData.gammaTable);
        CombiLEDObjArr{side}.setClockAdjustFactor(combiClockAdjust(side));
    end

    % Open the connection to the LabJack
    if EOGFlag
        EOGControl = BiopackControl('');
        fprintf('------Collecting EOG Data------\n')
    else
        EOGControl = '';
    end
end


% Provide instructions
if useKeyboardFlag

    fprintf('**********************************\n');
    fprintf('On each of many trials you will be presented with flickering lights\n');
    fprintf('on the left and right. There will be two intervals showing the pairs of flickering lights.\n');
    fprintf('Your job is to indicate which interval had the mismatched pair.\n');
    fprintf('If the first interval had mismatched flicker, press the 1 key.\n');
    fprintf('If the second interval had mismatched flicker, press the 2 key.\n');
    fprintf('Each block has %d trials in a row after\n',nTrialsPerBlock);
    fprintf('which you may take a brief break. There are a total of %d blocks.\n',nBlocks);
    fprintf('**********************************\n\n');

else

    fprintf('**********************************\n');
    fprintf('On each of many trials you will be presented with flickering lights\n');
    fprintf('on the left and right. There will be two intervals showing the pairs of flickering lights.\n');
    fprintf('Your job is to indicate which interval had the mismatched pair.\n');
    fprintf('If the first interval had mismatched flicker, press one of the top bumpers.\n');
    fprintf('If the second interval had mismatched flicker, press one of the bottom bumpers.\n');
    fprintf('Each block has %d trials in a row after\n',nTrialsPerBlock);
    fprintf('which you may take a brief break. There are a total of %d blocks.\n',nBlocks);
    fprintf('**********************************\n\n');

end

% Prepare to loop over blocks
for bb=1:nBlocks

    % Switch back and forth between the modulation directions
    directionIdx = mod(bb,2)+1;
    

    % Load the mod results for this direction for the two combiLEDs
    for side = 1:nSides
        modResultFile{side} = ...
            fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabel '_shifted'],['modResult_' combiLEDLabels{side} '.mat']);
        load(modResultFile{side},'modResult');
        modResultArr{side} = modResult;
        clear modResult
    end

    % Create a directory for the subject
    dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabel, '_shifted'],experimentName);
    if ~isfolder(dataDir)
        mkdir(dataDir)
    end

    % Assemble the psychObj array, looping over the high and low range of
    % the discrimination function AND the reference frequencies AND the
    % contrast
    psychObjArray = cell(nRanges,nFreqs,nContrasts);
    for rangeIdx = 1:nRanges
        for freqIdx = 1:nFreqs
            for contrastIdx = 1:nContrasts

                % Define the filestem for this psychometric object
                dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabel, '_shifted'],experimentName);
                psychFileStem = [subjectID '_' modDirections{directionIdx} '_' experimentName ...
                    '_cont-' strrep(num2str(targetPhotoContrast(contrastIdx, directionIdx)),'.','x') ...
                    '_refFreq-' num2str(refFreqHz(freqIdx)) 'Hz' ...
                    '_' stimParamSide{rangeIdx}];

                % Create or load the psychometric object
                psychObjFilename = fullfile(dataDir,[psychFileStem '.mat']);
                if isfile(psychObjFilename)
                    % Load the object
                    load(psychObjFilename,'psychObj');
                    % Handle the possibility that the psychObj file has
                    % been moved
                    if ~strcmp(psychObj.filename, psychObjFilename) % file name is different from what is in the object
                        warning('File name stored in psychObj does not match generated filename. Overwriting stored filename to match.')
                        % Update the path to the file in case this has changed
                        psychObj.filename = psychObjFilename;
                    end
                    % After starting data collection we changed the form
                    % of the psychometric function. This happened mid-data
                    % collection for one participant. Here we update the
                    % function and psiParams domain, and issues a warning.
                    if ~strcmp(char(psychObj.psychometricFuncHandle),'qpCumulativeNormalShifted')
                        warning('Updating the psychometric function to qpCumulativeNormalShifted.');
                        psychObj.psychometricFuncHandle = @qpCumulativeNormalShifted;
                        psychObj.questData.qpPF = @qpCumulativeNormalShifted;
                        psychObj.psiParamsDomainList{1} = linspace(0,5,25);
                    end                   
                    % Put in the fresh CombiLEDObjs
                    psychObj.CombiLEDObjArr = CombiLEDObjArr;
                    % Put in the fresh EOGFlag
                    psychObj.EOGFlag = EOGFlag;
                    % Put in the fresh EOGControl
                    if EOGFlag
                        psychObj.EOGControl = EOGControl;
                    else
                        psychObj.EOGControl = '';
                    end
                    % Increment blockIdx
                    psychObj.blockIdx = psychObj.blockIdx+1;
                    psychObj.blockStartTimes(psychObj.blockIdx) = datetime();
                    % Update the simulateMode in case this has changed
                    psychObj.simulateMode = simulateMode;
                    % Update the keyboard flag
                    psychObj.useKeyboardFlag = useKeyboardFlag;
                    % Decide whether to use staircase or Quest+ based on
                    % number of sessions completed
                    % If less than 3 sessions completed, want staircase
                    % 3 sessions = 15 trials/cond in the current version
                    sessionsCompleted = length(psychObj.questData.trialData) / nTrialsPerCondition;
                    if sessionsCompleted < 3
                        psychObj.useStaircase = true;
                        if rangeIdx == 1 && freqIdx == 1 && contrastIdx == 1  % Print staircase status for 1st psychObj only
                            fprintf('Using staircase: %d\n', psychObj.useStaircase);
                        end
                    else
                        psychObj.useStaircase = false;
                        if rangeIdx == 1 && freqIdx == 1 && contrastIdx == 1
                            fprintf('Using staircase: %d\n', psychObj.useStaircase);
                        end
                    end

                else
                    % Create the object
                    psychObj = PsychDichopticFlickerOneInt(...
                        CombiLEDObjArr, modResultArr, EOGControl, EOGFlag, refFreqHz(freqIdx),...
                        'refPhotoContrast',targetPhotoContrast(contrastIdx,directionIdx),...
                        'testPhotoContrast',targetPhotoContrast(contrastIdx,directionIdx),...
                        'simulateMode',simulateMode,...
                        'useStaircase',useStaircase,...
                        'stimParamsDomainList',stimParams,...
                        'stimParamSide',stimParamSide{rangeIdx},...
                        'verbose',verbosePsychObj, ...
                        'useKeyboardFlag',useKeyboardFlag);
                    % Store the filename
                    psychObj.filename = psychObjFilename;
                    % Double check that the staircase is set to true for 1st psychObj
                    if rangeIdx == 1 && freqIdx == 1 && contrastIdx == 1
                        fprintf('Using staircase: %d\n', psychObj.useStaircase);
                    end

                end

                % Store in the psychObjArray
                psychObjArray{rangeIdx, freqIdx, contrastIdx} = psychObj;

                % Clear the psychObj
                clear psychObj
            end
        end

    end

    % Initialize the display for one of the psychObj elements. This routine
    % assumes that all of the psychObj elements that will be called during
    % the block use the same modulation, modulation background, temporal
    % profile (i.e., sinusoid), and trial duration.
    psychObjArray{1,1,1}.initializeDisplay;

    % Start the block
    if ~simulateMode
        if useKeyboardFlag
            % If using keyboard
            fprintf('Press enter to start block %d...',bb);
            input('');
        else
            fprintf('Press button 1, 2, 3, or 4 to start block %d...',bb);
            getGamepadResponse(inf,[1 2 3 4]);
        end
    end

    % Assert that we have a sufficient number of trials per block to
    % present every stimulus type an equal and integer number of times
    assert(mod(nTrialsPerBlock,nRanges*nFreqs*nContrasts)==0);

    % Create a random ordering of the three stimulus crossings (high and
    % low range, frequencies, contrast levels)
    nReps = nTrialsPerBlock / (nRanges*nFreqs*nContrasts);
    triplets = zeros(nRanges*nFreqs*nContrasts,3);
    [a,b,c] = ndgrid(1:nRanges,1:nFreqs,1:nContrasts);
    triplets(:,1) = a(:); triplets(:,2) = b(:); triplets(:,3) = c(:);
    triplets = repmat(triplets,nReps,1);
    permutedTriplets = triplets(randperm(nTrialsPerBlock),:);

    % Store the block start time
    for rangeIdx = 1:nRanges
        for freqIdx = 1:nFreqs
            for contrastIdx = 1:nContrasts
                blockStartTime = datetime();
                psychObjArray{rangeIdx, freqIdx, contrastIdx}.blockStartTimes(psychObjArray{rangeIdx,freqIdx, contrastIdx}.blockIdx) = blockStartTime;
            end
        end
    end

    % Present nTrials
    for ii = 1:nTrialsPerBlock
        % Present the trial
        psychObjArray{...
            permutedTriplets(ii,1),...
            permutedTriplets(ii,2),...
            permutedTriplets(ii,3)}.presentTrial
    end

    % Report completion of this block
    fprintf('done.\n');

    % Store the psychObjArray entries
    for rangeIdx = 1:nRanges
        for freqIdx = 1:nFreqs
            for contrastIdx = 1:nContrasts
                % Grab the next psychObj
                psychObj = psychObjArray{rangeIdx, freqIdx, contrastIdx};
                % empty the CombiLEDObj and EOGControl handles and save the psychObj
                psychObj.CombiLEDObjArr = {};
                psychObj.EOGControl = {};
                % Save the psychObj
                save(psychObj.filename,'psychObj');
            end
        end
    end
    % Make a sound for the end of the block
    BlockDone.fs = 8000;              % Sampling frequency (Hz)
    duration = 0.25;         % Duration (seconds)
    freq = 600;            % Tone frequency (Hz)
    freq2 = 1200;
    t = 0:1/BlockDone.fs:duration;    % Time vector
    BlockDone.y = sin(2*pi*freq*t);   % Generate sine wave
    BlockDone.y2 = sin(2*pi*freq2*t);
    
    if bb<nBlocks
        sound(BlockDone.y, BlockDone.fs);           % Play the sound
        pause (0.26);
        sound(BlockDone.y2, BlockDone.fs);           % Play the sound
    end
end % block loop

% Clean up
if ~simulateMode
    for side = 1:nSides
        CombiLEDObjArr{side}.goDark;
        CombiLEDObjArr{side}.serialClose;
    end
    if EOGFlag
        EOGControl.labjackOBJ.shutdown();
    end
end
clear CombiLEDObjArr
clear EOGControl

% Tell participant the task is done
ExperimentDone = load('handel');
sound(ExperimentDone.y,ExperimentDone.Fs)

CalcDCPTDiscrimBonus(subjectID, refFreqHz, modDirections, targetPhotoContrast, NDlabel);

end % function
