function runDCPT_discomfort_entoptic(subjectID,NDlabel,EMGFlag, varargin)
% Show modulations and collect discomfort/entoptic ratings
%
% Syntax:
%   runDCPT_discomfort_entoptic(subjectID,NDlabel,'discomfortFlag',discomfortFlag);
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
%   discomfortFlag        - Bool for running discomfort ratings (true) or
%                           entoptic percept ratings (false)
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
    subjectID = 'FLIC_0015';
    NDlabel = '3x0';
    discomfortFlag = true; 
    EMGFlag = true;
    runDCPT_discomfort_entoptic(subjectID,NDlabel, EMGFlag, 'discomfortFlag', discomfortFlag);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('modDirections',{'LightFlux'},@iscell);
p.addParameter('refFreqHz',logspace(log10(10),log10(30),5),@isnumeric);
p.addParameter('targetPhotoContrast',[0.10; 0.30],@isnumeric);
p.addParameter('combiLEDLabels',{'C','D'},@iscell);
p.addParameter('combiLEDIDs',{"A10L31XJ","A10L31XZ"},@iscell);
p.addParameter('combiClockAdjust',[1.0006,0.9992],@isnumeric);
p.addParameter('nBlocks',1, @isnumeric);
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('dropBoxSubDir','FLIC_data',@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('verboseCombiLED',false,@islogical);
p.addParameter('verbosePsychObj',true,@islogical);
p.addParameter('simulateMode',false,@islogical);
p.addParameter('makeOrder',false, @islogical);
p.addParameter('discomfortFlag',true, @islogical);
p.parse(varargin{:})

%  Pull out some variables from the p.Results structure
modDirections = p.Results.modDirections;
refFreqHz = p.Results.refFreqHz;
targetPhotoContrast = p.Results.targetPhotoContrast;
combiLEDLabels = p.Results.combiLEDLabels;
combiLEDIDs = p.Results.combiLEDIDs;
nBlocks = p.Results.nBlocks;
verboseCombiLED = p.Results.verboseCombiLED;
verbosePsychObj = p.Results.verbosePsychObj;
simulateMode = p.Results.simulateMode;
combiClockAdjust = p.Results.combiClockAdjust;
makeOrder = p.Results.makeOrder;
discomfortFlag = p.Results.discomfortFlag;
dropBoxBaseDir = p.Results.dropBoxBaseDir;
dropBoxSubDir = p.Results.dropBoxSubDir;
projectName = p.Results.projectName;


% Set our experimentName
if discomfortFlag
    experimentName = 'DCPT_discomfort';
else
    experimentName = 'DCPT_entoptic';
end

% Set the labels discomfort and entoptic
if discomfortFlag
    discomfortStr = {'discomfort'};
else
    discomfortStr = {'entoptic'};
end

% Define some basic trial type quantities
nFreqs = length(refFreqHz);
nConstrasts = size(targetPhotoContrast,1);
nModDir = size(modDirections,1);
nTrials = nFreqs*nConstrasts*nModDir;
nTrialsPerBlock = nTrials/nModDir;
nSides = 2;

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
    if EMGFlag
        dataOutDir = '/Users/flicexperimenter/Aguirre-Brainard Lab Dropbox/Flic Experimenter/FLIC_data/combiLED/HERO_rsb';
        EMGControl = BiopackControl(dataOutDir);
        fprintf('------Collecting EMG Data------\n')
    else
        EMGControl = '';
    end
end


% Provide instructions
if discomfortFlag 

    fprintf('**********************************\n');
    fprintf('On each of many trials you will be presented with flickering\n');
    fprintf('lights in both eyes. When the lights stop flickering,\n');
    fprintf('your job is to rate your discomfort \n');
    fprintf('from watching the lights on a scale from 0 to 10.');
    fprintf('There are a total of %d trials.\n',nTrials);
    fprintf('**********************************\n\n');

else

    fprintf('**********************************\n');
    fprintf('On each of many trials you will be presented with flickering\n');
    fprintf('lights in both eyes. \n');
    fprintf('Question 1: When the lights stop flickering, your job is to rate \n');
    fprintf('the strength of the entoptic percept on a scale of 0-10, \n');
    fprintf('where 0 is no structure. \n');
    fprintf('Question 2: Did you see a Purkinje tree? \n');
    fprintf('There are a total of %d trials.\n',nTrials);
    fprintf('**********************************\n\n');

end

% Prepare to loop over blocks
for bb=1:nBlocks

    % One modulation direction - light flux
    directionIdx = 1; 

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

    % Define the filestem for this psychometric object
    dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabel, '_shifted'],experimentName);

    % Create or load the psychometric object
    psychObjFilename = fullfile(dataDir,[discomfortStr{1} '.mat']);

    if isfile(psychObjFilename)
        % Load the object
        load(psychObjFilename,'psychObj');
        % Update the path to the file in case this has changed
        psychObj.filename = psychObjFilename;
        % Put in the fresh CombiLEDObjs
        psychObj.CombiLEDObjArr = CombiLEDObjArr;
        % Put in the fresh EMGFlag
        psychObj.EMGFlag = EMGFlag;
        % Put in the fresh EMGControl
        if EMGFlag
            psychObj.EMGControl = EMGControl;
        else
            psychObj.EMGControl = '';
        end
        % Increment blockIdx
        psychObj.blockIdx = psychObj.blockIdx+1;
        psychObj.blockStartTimes(psychObj.blockIdx) = datetime();
    else
        % Create the object
        psychObj = PsychDichopticFlickerDiscomfort(...
            CombiLEDObjArr, modResultArr, EMGControl, EMGFlag, refFreqHz,...
            'refPhotoContrast',targetPhotoContrast(:,directionIdx), ...
            'discomfortFlag', discomfortFlag);
        % Store the filename
        psychObj.filename = psychObjFilename;
    end


    % Initialize the display for one of the psychObj elements. This routine
    % assumes that all of the psychObj elements that will be called during
    % the block use the same modulation, modulation background, temporal
    % profile (i.e., sinusoid), and trial duration.
    psychObj.initializeDisplay;

    % Start the block
    fprintf('Press enter to start block %d...',bb);
    input('');

    % TO DO make a set order we present to all participants.
    % Create a random ordering of the two stimulus crossings (frequencies and contrast levels)
    if makeOrder   % If creating a new random order
        pairs = zeros(nFreqs*nConstrasts,2);
        [a,b] = ndgrid(1:nFreqs,1:nConstrasts);
        pairs(:,1) = a(:); pairs(:,2) = b(:);
        pairs = repmat(pairs,nTrialsPerBlock,1);
        permutedPairs = pairs(randperm(nTrialsPerBlock),:);
        pairFileName = fullfile(dropBoxBaseDir,dropBoxSubDir,projectName,'DEMO_discrim/DCPT_discomfort_pairs.mat');
        save(pairFileName, 'permutedPairs');
    else    % If using the pre-set order
        pairFileName = fullfile(dropBoxBaseDir,dropBoxSubDir,projectName,'DEMO_discrim/DCPT_discomfort_pairs.mat');
        permutedPairs = load(pairFileName);
        permutedPairs = permutedPairs.permutedPairs;
    end

    % Store the block start time
    for freqIdx = 1:nFreqs
        for contrastIdx = 1:nConstrasts
            blockStartTime = datetime();
            psychObj.blockStartTimes(psychObj.blockIdx) = blockStartTime;
        end
    end
    % Present nTrials
    for ii = 1:nTrialsPerBlock
        currentPair = permutedPairs(ii,:);
        currTargetPhotoContrast = targetPhotoContrast((permutedPairs(ii,2)),directionIdx);
        psychObj.presentTrial(currentPair, currTargetPhotoContrast);
    end

    % Report completion of this block
    fprintf('done.\n');

    % empty the CombiLEDObj and EMGControl handles and save the psychObj
    psychObj.CombiLEDObjArr = {};
    psychObj.EMGControl = {};
    % Save the psychObj
    save(psychObj.filename,'psychObj');


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
for side = 1:nSides
    CombiLEDObjArr{side}.goDark;
    CombiLEDObjArr{side}.serialClose;
end
if EMGFlag
    EMGControl.labjackOBJ.shutdown();
end

clear CombiLEDObjArr
clear EMGControl

end % function
