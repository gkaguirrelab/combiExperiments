function plotDCPT_SDT_rxnTime(subjectID, refFreqSetHz, modDirections, targetPhotoContrast, NDLabel)
% % Function to plot the high and low ends of a psychometric funciton on the
% % same graph.
% % e.g.,
%{

subjectList = {'FLIC_0015','FLIC_0017','FLIC_0018','FLIC_0021'};
refFreqSetHz = logspace(log10(10),log10(30),5);
modDirections = {'LightFlux'};
targetPhotoContrast = [0.10; 0.30];  % [Low contrast levels; high contrast levels] 
% Light Flux is [0.10; 0.30]
NDLabel = {'3x0', '0x5'};
plotDCPT_SDT_rxnTime(subjectID, refFreqSetHz, modDirections, targetPhotoContrast, NDLabel);
%}

dropBoxBaseDir=getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir='FLIC_data';
projectName='combiLED';
experimentName = 'DCPT_SDT';

% Set the labels for the high and low stimulus ranges
stimParamLabels = {'low', 'hi'};
lightLevelLabels = {'Low Light', 'High Light'}; % to be used only for the title

% Set number of contrast levels and sides
nContrasts = 2;
nSides = 2;

% Define the modulation and data directories
subjectDir = fullfile(...
    dropBoxBaseDir,...
    dropBoxSubDir,...
    projectName,...
    subjectID);

%% Plot the full psychometric functions
rxnTimes = [];
correct = [];
stimdB = [];

% Set up a figure
figure; hold on
for ss = 1:length(subjectList)
    subjectID = subjectList{ss};

for lightIdx = 1:length(NDLabel)
      
    title(['subj: ', subjectID, ' Reaction Times']);

    for freqIdx = 1:length(refFreqSetHz)
        dataDir = fullfile(subjectDir,[modDirections{1} '_ND' NDLabel{lightIdx} '_shifted'],experimentName);

        for contrastIdx = 1:nContrasts

            % To plot the psychometric functions on the same graph - collect the high and low side
            % estimate objects in an array
            psychObjArray = {};

            for sideIdx = 1:nSides

                % Load this measure
                psychFileStem = [subjectID '_' modDirections{1} ...
                    '_' experimentName...
                    '_cont-' strrep(num2str(targetPhotoContrast(contrastIdx)),'.','x') ...
                    '_refFreq-' num2str(refFreqSetHz(freqIdx)) 'Hz' ...
                    '_' stimParamLabels{sideIdx}];
                filename = fullfile(dataDir,psychFileStem);
                load(filename,'psychObj');

                % Store some of these parameters
                questData = psychObj.questData;
                stimParamsDomainList = psychObj.stimParamsDomainList;
                psiParamsDomainList = psychObj.psiParamsDomainList;
                psiParamsDomainList{2} = stimParamsDomainList;
                nTrials = length(psychObj.questData.trialData);

                rxnTimes = [rxnTimes, [questData.trialData.responseTimeSecs]];
                correct = [correct, [questData.trialData.correct]];
                stimdB = [stimdB, [questData.trialData.stim]];

                % Plot these
                % markerSizeIdx = discretize(nTrials,3);
                % markerSizeSet = [25,50,100];
                % markerShapeSet = ['o', '^'];   
                % markerColorSet = [0, 0, 0.5; 0.5, 0, 0];   % blue, red. low, high

                % for cc = 1:nTrials
                %     scatter(stim(cc),pRespondDifferent(cc),markerSizeSet(markerSizeIdx(cc)), ...
                %         'Marker', markerShapeSet(sideIdx), ...
                %         'MarkerFaceColor', markerColorSet(sideIdx,:), ...
                %         'MarkerEdgeColor','k', ...
                %         'MarkerFaceAlpha',nTrials(cc)/max(nTrials));
                %          % 'MarkerFaceColor',[pRespondDifferent(cc) 0 1-pRespondDifferent(cc)], 
                %     hold on
                % end

                psychObjArray{sideIdx} = psychObj;

            end

            
            % % Plotting
            % % Low side
            % hold on
            % for cc = 1:length(stimParamsDomainListLow)
            %     outcomes = psychObjArray{1}.questData.qpPF(stimParamsDomainListLow(cc),psiParamsFitLow);
            %     fitRespondDiff(cc) = outcomes(2);
            % end
            % plot(abs(stimParamsDomainListLow),fitRespondDiff,'Color', [0, 0, 0.5]);
            % 
            % fitRespondDiff = [];
            % 
            % % High side
            % for cc = 1:length(stimParamsDomainListHigh)
            %     outcomes = psychObjArray{2}.questData.qpPF(stimParamsDomainListHigh(cc),psiParamsFitHigh);
            %     fitRespondDiff(cc) = outcomes(2);
            % end
            % plot(stimParamsDomainListHigh,fitRespondDiff,'Color', [0.5, 0, 0]);
            % hold off

            % Add a marker for the 50% point
            %        outcomes = psychObj.questData.qpPF(psiParamsFit(1),psiParamsFit);
            %        plot([psiParamsFit(1), psiParamsFit(1)],[0, outcomes(2)],':k')
            %        plot([min(stimParamsDomainList), psiParamsFit(1)],[0.5 0.5],':k')

            % % Labels and range
            % xlim([0 6.75]);
            % ylim([-0.1 1.1]);
            % if freqIdx == length(refFreqSetHz)  % Bottom row
            %     xlabel('absolute stimulus difference [dB]');
            % end
            % if contrastIdx == 1 % Left column
            %     ylabel('proportion respond different');
            % end
            % 
            % % Add a title
            % str = sprintf('%2.1d Hz; [μ,σ,λ] = [%2.2f,%2.2f,%2.2f]', psychObjArray{1}.refFreqHz, psiParamsFit);
            % title(str);
            % box off

            % Store the slope of the psychometric function
            % if lightIdx == 1
            %     slopeVals(rr) = normpdf(0,psiParamsFit(1),psiParamsFit(2));
            %     slopeValCI(rr,1) = normpdf(0,psiParamsCI(1,1),psiParamsCI(1,2));
            %     slopeValCI(rr,2) = normpdf(0,psiParamsCI(2,1),psiParamsCI(2,2));
            %
            % end
            %
            % if lightIdx == 2
            %     slopeVals2(rr) = normpdf(0,psiParamsFit(1),psiParamsFit(2));
            %     slopeValCI2(rr,1) = normpdf(0,psiParamsCI(1,1),psiParamsCI(1,2));
            %     slopeValCI2(rr,2) = normpdf(0,psiParamsCI(2,1),psiParamsCI(2,2));
            % end

        end

    end

end
nBins = 50;
histogram(rxnTimes, nBins);
ylabel('Count');
xlabel('Reaction Time (sec)')


% --- Plotting Code ---
figure;
hold on

% Find the indices for correct and incorrect trials
correctIdx = find(correct);
wrongIdx = find(~correct);

% Plot the correct trials with a transparent blue fill.
scatter(stimdB(correctIdx), rxnTimes(correctIdx), 40, 'o', ...
    'MarkerFaceColor', 'b', ...
    'MarkerFaceAlpha', 0.15, ...
    'MarkerEdgeColor', 'b', ...
    'MarkerEdgeAlpha', 0.5);

% Plot the incorrect trials with a transparent red fill.
scatter(stimdB(wrongIdx), rxnTimes(wrongIdx), 40, 'o', ...
    'MarkerFaceColor', 'r', ...
    'MarkerFaceAlpha', 0.15, ...
    'MarkerEdgeColor', 'r', ...
    'MarkerEdgeAlpha', 0.5);

% Fit a linear line to the data
p = polyfit(stimdB, rxnTimes, 1);
xFit = linspace(min(stimdB), max(stimdB), 100);
yFit = polyval(p, xFit);

% Plot the fitted line
plot(xFit, yFit, 'k:', 'LineWidth', 2);

% Add labels and a title
ylabel('Reaction Time (sec)');
xlabel('Stim Params (dB)');
title('Stim Domain vs. Reaction Time');
legend('correct', 'incorrect', 'Linear Fit');

end

hold off







