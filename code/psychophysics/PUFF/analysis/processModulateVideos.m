function results = processModulateVideos( subjectID, options )
% Extract measure of eye closure in videos from the modulate experiment
%
% Syntax:
%   results = processModulateVideos( subjectID)
%
% Description:
%   Process the data for a subject in the PuffLight modulate experiment
%
% Inputs:
%   subjectID             - Char vector. E.g., 'BLNK_1001'
%
% Optional key/value pairs:
%  'bar'                  - Scalar. Bar bar bar bar bar bar bar bar bar bar
%                           bar bar bar bar bar bar bar bar bar bar bar bar
%                           bar bar bar bar bar bar
%
% Outputs:
%   results               - Structure
%
% Examples:
%{

%}


%% argument block
arguments
    subjectID
    options.vecDurSecs = 60
    options.initialSecsToDiscard = 0
    options.fps = 180
    options.makePlotFlag = true
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
nFrames = options.vecDurSecs * options.fps;

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
        medianDarkWidth(2,dd) = median(loadBlinkCleanedData(fullfile(dataDir,filenameL),'makePlotFlag',true,'addToExistingPlot',true),'omitmissing');
    end
end

% Loop through the stimulus properties
for dd = 1:length(directions)
    for cc = 1:length(contrasts)
        for pp = 1:length(phases)

            % Initialize the results and confidence fields
            results.(directionLabels{dd}).(contrastLabels{cc}).(phaseLabels{pp}).palpFissure = nan(4,nFrames);
            results.(directionLabels{dd}).(contrastLabels{cc}).(phaseLabels{pp}).confidenceL = nan(4,nFrames);
            results.(directionLabels{dd}).(contrastLabels{cc}).(phaseLabels{pp}).confidenceR = nan(4,nFrames);

            % Loop over trials
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
                    results.(directionLabels{dd}).(contrastLabels{cc}).(phaseLabels{pp}).palpFissure(tt,1:nFrames) = nan;
                    continue
                end

                % See if we have a custom duration for this video (which
                % happens in a couple cases in which the subject removed
                % their face from the apparatus prematurely
                vecEndSecs = excludeDataDict(fileNameStem);

                % Calculate the lag of the L vector relative to R
                if isempty(vecEndSecs)
                    vecDurSecs = options.vecDurSecs;
                else
                    vecDurSecs = vecEndSecs - options.initialSecsToDiscard;
                end
                [lagFrames, output] = calcTemporalOffset(fileNameL,fileNameR,'vecDurSecs',vecDurSecs);                
                if isnan(output.rFinal) || output.rFinal < 0.7
                    calcTemporalOffset(fileNameL,fileNameR,'vecDurSecs',vecDurSecs,'makePlotFlag',true);
                    warning(['Poor L-R alignment for ' fileNameStem]);
                end

                % Load the videos, correct lag on the left, convert to
                % proportion eye open
                [palpFissureR, confidenceR] = loadSquintVector(fileNameR,'vecDurSecs',vecDurSecs);
                [palpFissureL, confidenceL] = loadSquintVector(fileNameL,'vecDurSecs',vecDurSecs);
                palpFissureL = circshift(palpFissureL,lagFrames);
                confidenceL = circshift(confidenceL,lagFrames);
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
                results.(directionLabels{dd}).(contrastLabels{cc}).(phaseLabels{pp}).palpFissure(tt,1:length(palpFissure)) = palpFissure;
                results.(directionLabels{dd}).(contrastLabels{cc}).(phaseLabels{pp}).confidenceL(tt,1:length(palpFissure)) = confidenceL;
                results.(directionLabels{dd}).(contrastLabels{cc}).(phaseLabels{pp}).confidenceR(tt,1:length(palpFissure)) = confidenceR;
                results.(directionLabels{dd}).(contrastLabels{cc}).(phaseLabels{pp}).meta.lagFrames = lagFrames;
                results.(directionLabels{dd}).(contrastLabels{cc}).(phaseLabels{pp}).meta.rFinal = output.rFinal;
                results.(directionLabels{dd}).(contrastLabels{cc}).(phaseLabels{pp}).meta.mdw = mdw;
            end
        end
    end
end

% Make some plots if requested
if options.makePlotFlag
    plotColors = {'c','y','b','k'};
    lineWidth = [1,2];
    t = 0:1/options.fps:(nFrames-1)/options.fps;
    figure
    for dd = 1:length(directions)
        for cc = 1:length(contrasts)
            vecs=-results.(directionLabels{dd}).(contrastLabels{cc}).OffOn.palpFissure;
            vecs(5:8,:)=results.(directionLabels{dd}).(contrastLabels{cc}).OnOff.palpFissure;
            mu = mean(vecs,'omitmissing');
            plot(t,mu,[plotColors{dd} '-'],'LineWidth',lineWidth(cc));
            hold on
        end
    end
    xlabel('Time [secs]');
    ylabel('proportion ∆ eye closure');
    title(subjectID,'Interpreter','none');
end

end