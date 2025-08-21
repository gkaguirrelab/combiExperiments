function  plotEOG(subjectID, refFreqSetHz, modDirections, targetPhotoContrast, NDLabel)
% % Function to plot the data for EOG during trials  
% % e.g.,
%{

    subjectID = 'FLIC_0007';
    refFreqSetHz = [3.0000, 4.8206, 7.746, 12.4467, 20.0000];
    modDirections = {'LminusM_wide' 'LightFlux'};
    targetPhotoContrast = [0.025, 0.10; 0.075, 0.30];  % [Low contrast levels; high contrast levels] 
            % L minus M is [0.025, 0.075] and Light Flux is [0.10, 0.30]
    NDLabel = {'0x5'};
    plotEOG(subjectID, refFreqSetHz, modDirections, targetPhotoContrast, NDLabel);

%}

for iSession = 1:10
    dropBoxBaseDir=getpref('combiExperiments','dropboxBaseDir');
    dropBoxSubDir='FLIC_data';
    projectName='combiLED';
    experimentName = 'DCPT';
    calFolder = 'EOGCalibration';
    calFile = ['EOGSession', num2str(iSession), 'Cal.mat'];

    % Set the labels for the high and low stimulus ranges
    stimParamLabels = {'low', 'hi'};
    modDirectionsLabels = {'LminusM', 'LightFlux'}; % to be used only for the title

    % Set number of contrast levels and sides
    nContrasts = 2;
    nSides = 2;
    trialsPerSession = 5;

    % Define the modulation and data directories
    subjectDir = fullfile(...
        dropBoxBaseDir,...
        dropBoxSubDir,...
        projectName,...
        subjectID);

    %% Load and Plot calibration data
    filename = fullfile(subjectDir, calFolder, calFile);
    if isfile(filename)
        calData = load(filename, 'sessionData');
        yData = calData.sessionData.EOGData.response;
        yMin = min(yData);
        yMax = max(yData);
        figure
        hold on
        title('EOG Calibration', 'FontSize', 18,'FontWeight','bold');
        plot(calData.sessionData.EOGData.timebase, calData.sessionData.EOGData.response);
    end
end
%array where each entry is the degrees/mv in each session. 10 numbers, 1
%for each session (repeat when calibrations repeat)
DegPerMv = [];

%% Plot the EOG data for each trial

    

for directionIdx = 1:length(modDirections)% black and white or red green
    figure('Name', ['EOG Direction: ' modDirectionsLabels{directionIdx}], 'Units', 'normalized', 'Position', [0.05 0.1 0.9 0.8]);
    t = tiledlayout(nContrasts*nSides, length(refFreqSetHz), 'TileSpacing', 'compact', 'Padding', 'compact');
    title(t, ['EOG Responses - ' modDirectionsLabels{directionIdx}]);
    for freqIdx = 1:length(refFreqSetHz) %stimulus frequency
        dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDLabel{1} '_shifted'],experimentName);
        for contrastIdx = 1:nContrasts
            psychObjArray = {};
            for sideIdx = 1:nSides %hi or low side
                % Compute row index: rows 1-4 correspond to [C1S1; C1S2; C2S1; C2S2]
                rowIdx = (contrastIdx - 1) * nSides + sideIdx;

                % Determine tile index (column-major): row + (col-1)*numRows
                tileIdx = rowIdx + (freqIdx - 1) * (nContrasts * nSides);
                nexttile(tileIdx);
                hold on

                % Load this measure
                psychFileStem = [subjectID '_' modDirections{directionIdx} ...
                    '_' experimentName...
                    '_cont-' strrep(num2str(targetPhotoContrast(contrastIdx, directionIdx)),'.','x') ...
                    '_refFreq-' num2str(refFreqSetHz(freqIdx)) 'Hz' ...
                    '_' stimParamLabels{sideIdx}];
                filename = fullfile(dataDir,psychFileStem);
                load(filename,'psychObj');

                % Store some of these parameters
                questData = psychObj.questData;
                nTrials = size(questData.trialData,1);
                nSessions = nTrials./trialsPerSession;

                % Generate base colors for each session (distinct hues)
                baseColors = lines(nSessions);  % Use 'lines' colormap for distinct base hues

                % For each session, create 5 lighter shades of its base color
                for s = 1:nSessions
                    baseColor = baseColors(s,:);
                    % Generate 5 shades: from dark to light by blending with white
                    for t = 1:trialsPerSession
                        alpha = (t - 1) / (trialsPerSession - 1);  % 0 (dark) to 1 (light)
                        trialColors{s}(t,:) = (1 - alpha) * baseColor + alpha * [1 1 1];  % blend with white
                    end
                end

                % figure
                % hold on

                title([num2str(refFreqSetHz(freqIdx)) ' Hz, ' num2str(targetPhotoContrast(contrastIdx, directionIdx)*100) '% contrast, ' stimParamLabels{sideIdx}])

                trialsPerSession = 5;
                for ss = 1:nSessions
                    for trialOffset = 1:trialsPerSession
                        trialIdx = (ss - 1) * trialsPerSession + trialOffset;

                        EOGTrialData = psychObj.questData.trialData(trialIdx).EOGdata1.response(1,:);
                        meanResponse(trialIdx,sideIdx,contrastIdx, freqIdx, directionIdx) = mean(EOGTrialData);
                        rawEOGdata(trialIdx,sideIdx,contrastIdx, freqIdx, directionIdx,:)= EOGTrialData;
                        stdResponse(trialIdx, sideIdx, contrastIdx, freqIdx, directionIdx,:)= std(EOGTrialData); %%added this
                        meanCorrected(trialIdx,:) = EOGTrialData - meanResponse(trialIdx,sideIdx,contrastIdx, freqIdx, directionIdx);
                        % convert to degrees using DegPerMv
                        meanCorrectedDeg(trialIdx,:)= meanCorrected(trialIdx,:)*DegPerMv(ss);
                        plot(psychObj.questData.trialData(trialIdx).EOGdata1.timebase, ...
                            meanCorrectedDeg(trialIdx,:), ...
                            'Color', trialColors{ss}(trialOffset,:), ...
                            'DisplayName', ['Trial ' num2str(trialIdx)]);
                        ylim([yMin yMax]);
                        ylabel('response (Degrees)')
                        xlabel('time (sec)')
                    end    
                end
            end % sides
        end % contrast
    end %frequencies
overallMean(directionIdx) = mean(meanResponse(:,:,:,:, directionIdx),[1 2 3 4]);
overallStd(directionIdx) = mean(stdResponse(:,:,:,:,directionIdx),[1 2 3 4]); %%added this
%add std of rawEOGdata for the mean here, use these for error bars
end % mod direction

%%Histogram added this

figure('Name', 'EOG Mean by Direction');
b = bar(overallMean);
hold on
errorbar(1:numel(overallMean), overallMean, overallStd,...
    'LineStyle', 'none');
hold off

set(gca, 'XTick', 1:numel(overallMean), ...
         'XTickLabel', modDirectionsLabels, ...
         'TickLabelInterpreter', 'none');

ylabel('response (mV)');
title('EOG mean ± SD by direction');
xlim([0.5, numel(overallMean)+0.5]);


end

