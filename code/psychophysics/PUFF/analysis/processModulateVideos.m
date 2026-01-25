function results = processModulateVideos( subjectID, options )
% Extract measure of eye closure in videos from the modulate experiment
%
% Syntax:
%   output = myFunc(input)
%
% Description:
%   Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aenean euismod
%   nulla a tempor scelerisque. Maecenas et lobortis est. Donec et turpis
%   sem. Sed fringilla in metus ut malesuada. Pellentesque nec eros
%   efficitur, pellentesque nisl vel, dapibus felis. Morbi eu gravida enim.
%   Sed sodales ipsum eget finibus dapibus. Fusce sagittis felis id orci
%   egestas, non convallis neque porttitor. Proin ut mi augue. Cras posuere
%   diam at purus dignissim, vel vestibulum tellus ultrices
%
% Inputs:
%   none
%   foo                   - Scalar. Foo foo foo foo foo foo foo foo foo foo
%                           foo foo foo foo foo foo foo foo foo foo foo foo
%                           foo foo foo
%
% Optional key/value pairs:
%   none
%  'bar'                  - Scalar. Bar bar bar bar bar bar bar bar bar bar
%                           bar bar bar bar bar bar bar bar bar bar bar bar
%                           bar bar bar bar bar bar
%
% Outputs:
%   none
%   baz                   - Cell. Baz baz baz baz baz baz baz baz baz baz
%                           baz baz baz baz baz baz baz baz baz baz baz baz
%                           baz baz baz
%
% Examples:
%{
% Get a list of the analysis files
directionSet = {'-LMS','-Mel','-S'};
dataDir = '/Users/aguirre/Aguirre-Brainard Lab Dropbox/Geoffrey Aguirre/BLNK_analysis/PuffLight/modulate/HERO_gka/videos';
mList = dir(fullfile(dataDir,'*trial*mat'));
%}


%% argument block
arguments
    subjectID
    options.videoDurSecs = 60
    options.initialSecsToDiscard = 0
    options.fps = 180
end

% Define some experiment properties
projectName = 'PuffLight';
experimentName = 'modulate';

% Define the stimulus properties
directions = {'Mel','LMS','S_peripheral','LightFlux'};
directionLabels = {'Mel','LMS','S','LF'};
phaseLabels = {'OnOff','OffOn'};
contrastLabels = {'Low','High'};
phases = [0,pi];
contrasts = [0.2,0.4];
nTrials = 4;

% Define the data properties
nFrames = options.videoDurSecs * options.fps;

% Get the path to the data files
dropboxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dataDir = fullfile(dropboxBaseDir,'BLNK_analysis',projectName,experimentName,subjectID);

% Get the median palpebral fissure width during the dark periods
medianDarkWidth = nan(2,4);
for dd = 1:4
    idx = (dd-1)*3+1;
    filenameR = sprintf([subjectID '_modulate_dark-%02d_R_eyeFeatures.mat'],idx);
    filenameL = sprintf([subjectID '_modulate_dark-%02d_L_eyeFeatures.mat'],idx);
    if isfile(fullfile(dataDir,filenameR))
        medianDarkWidth(1,dd) = median(loadBlinkCleanedData(fullfile(dataDir,filenameR),'makePlotFlag',true),'omitmissing');
        medianDarkWidth(2,dd) = median(loadBlinkCleanedData(fullfile(dataDir,filenameL),'makePlotFlag',true),'omitmissing');
    end
end

% Loop through the stimulus properties
for dd = 1:length(directions)
    for cc = 1:length(contrasts)
        for pp = 1:length(phases)
            for tt = 1:nTrials

                % Get the filenames for this trial
                whichDirection = directions{dd};
                thisContrast = contrasts(cc);
                thisPhase = phases(pp);
                fileNameStem = sprintf( [subjectID '_' experimentName ...
                    '_direction-' whichDirection '_contrast-%2.2f_phase-%2.2f_trial-%03d'], thisContrast, thisPhase, tt );
                fileNameR = fullfile(dataDir,[fileNameStem '_L_eyeFeatures.mat']);
                fileNameL = fullfile(dataDir,[fileNameStem '_R_eyeFeatures.mat']);

                % Check if the file exists
                if ~isfile(fileNameL)
                    continue
                end

                % Calculate the lag of the L vector relative to R
                [lagFrames, output] = calcTemporalOffset(fileNameL,fileNameR);
                if isnan(output.rFinal) || output.rFinal < 0.7
                    calcTemporalOffset(fileNameL,fileNameR,'makePlotFlag',true)
                    foo=1;
                end

                % Load the videos, correct lag on the left, convert to
                % proportion eye open
                palpFissureR = loadSquintVector(fileNameR);
                palpFissureL = loadSquintVector(fileNameL);
                palpFissureL = circshift(palpFissureL,lagFrames);
                if ~any(isnan(medianDarkWidth(:,tt)))
                    mdw = medianDarkWidth(:,tt);
                else
                    mdw(1) = mean(medianDarkWidth(1,:),'omitmissing');
                    mdw(2) = mean(medianDarkWidth(2,:),'omitmissing');
                end
                palpFissureR = palpFissureR / mdw(1);
                palpFissureL = palpFissureL / mdw(2);

                % Covert to proportion change around the mean
                palpFissureR = (palpFissureR - mean(palpFissureR))/mean(palpFissureR);
                palpFissureL = (palpFissureL - mean(palpFissureL))/mean(palpFissureL);

                % Average the two eyes
                palpFissure = mean([palpFissureR;palpFissureL],'omitmissing');

                % Store the vector
                results.(directionLabels{dd}).(contrastLabels{cc}).(phaseLabels{pp}).palpFissure(tt,1:nFrames) = palpFissure;
                results.(directionLabels{dd}).(contrastLabels{cc}).(phaseLabels{pp}).meta.lagFrames = lagFrames;
                results.(directionLabels{dd}).(contrastLabels{cc}).(phaseLabels{pp}).meta.rFinal = output.rFinal;
                results.(directionLabels{dd}).(contrastLabels{cc}).(phaseLabels{pp}).meta.mdw = mdw;
            end
        end
    end
end




end