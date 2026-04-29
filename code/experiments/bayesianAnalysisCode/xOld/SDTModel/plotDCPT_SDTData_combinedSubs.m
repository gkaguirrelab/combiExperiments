function plotDCPT_SDTData_combinedSubs(subjectID, refFreqSetHz, modDirections, targetPhotoContrast, NDLabel)
% % Function to plot the high and low ends of a psychometric funciton on the
% % same graph, for DCPT SDT data collection. Plots data combined across
% % subjects. 
% % e.g.,
%{

subjectID = {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', 'FLIC_0018'};
refFreqSetHz = logspace(log10(10),log10(30),5);
modDirections = {'LightFlux'};
targetPhotoContrast = [0.10; 0.30];  % [Low contrast levels; high contrast levels] 
% Light Flux is [0.10; 0.30]
NDLabel = {'3x0', '0x5'};
plotDCPT_SDTData_combinedSubs(subjectID, refFreqSetHz, modDirections, targetPhotoContrast, NDLabel);
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
nSubjects = length(subjectID); 

% Define the modulation and data directories
subjectDir = fullfile(...
    dropBoxBaseDir,...
    dropBoxSubDir,...
    projectName,...
    subjectID);

%% Plot the full psychometric functions

for lightIdx = 1:length(NDLabel)
  
    % Set up a figure
    figHandle = figure(lightIdx);
    figuresize(750,1200,'units','pt')

    tcl = tiledlayout(length(refFreqSetHz),nContrasts);
    title(tcl, [lightLevelLabels{lightIdx} ' with Photo Contrasts: ' num2str(targetPhotoContrast(1)) ', ' num2str(targetPhotoContrast(2))]);

    for freqIdx = 1:length(refFreqSetHz)

        for contrastIdx = 1:nContrasts

            nexttile;
            hold on
            
            % To combine trial data across subjects
            comboTrialData = cell(1, nSides);

            % Store the first psychObj per side
            % All data is the same across subjects (within a condition) except for the trial data
            templatePsychObj = cell(1, nSides); 

            for sideIdx = 1:nSides

                for subjIdx = 1:nSubjects

                    subjectID_this = subjectID{subjIdx};
                    subjectDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, subjectID_this);
                    dataDir = fullfile(subjectDir,[modDirections{1} '_ND' NDLabel{lightIdx} '_shifted'],experimentName);

                    % Load this measure
                    psychFileStem = [subjectID_this '_' modDirections{1} ...
                        '_' experimentName...
                        '_cont-' strrep(num2str(targetPhotoContrast(contrastIdx)),'.','x') ...
                        '_refFreq-' num2str(refFreqSetHz(freqIdx)) 'Hz' ...
                        '_' stimParamLabels{sideIdx}];
                    filename = fullfile(dataDir,psychFileStem);
                    load(filename,'psychObj');
        
                    % Combine trial data for this side, across subjects
                    comboTrialData{sideIdx} = [comboTrialData{sideIdx}; psychObj.questData.trialData];

                    % PLOTTING INDIVIDUAL SUBJECT DATA POINTS
                    % Get the proportion respond "different" for each stimulus
                    % questData = psychObj.questData;
                    % stimCounts = qpCounts(qpData(questData.trialData),questData.nOutcomes);
                    % stim = zeros(length(stimCounts),questData.nStimParams);
                    % for cc = 1:length(stimCounts)
                    %     stim(cc) = stimCounts(cc).stim;
                    %     nTrials(cc) = sum(stimCounts(cc).outcomeCounts);
                    %     pRespondDifferent(cc) = stimCounts(cc).outcomeCounts(2)/nTrials(cc);
                    % end
                    % % Plot these
                    % markerSizeIdx = discretize(nTrials,3);
                    % markerSizeSet = [25,50,100];
                    % markerShapeSet = ['o', '^'];
                    % markerColorSet = [0, 0, 0.5; 0.5, 0, 0];   % blue, red. low, high
                    % for cc = 1:length(stimCounts)
                    %     scatter(stim(cc),pRespondDifferent(cc),markerSizeSet(markerSizeIdx(cc)), ...
                    %         'Marker', markerShapeSet(sideIdx), ...
                    %         'MarkerFaceColor', markerColorSet(sideIdx,:), ...
                    %         'MarkerEdgeColor','k', ...
                    %         'MarkerFaceAlpha',nTrials(cc)/max(nTrials));
                    %     % 'MarkerFaceColor',[pRespondDifferent(cc) 0 1-pRespondDifferent(cc)],
                    %     hold on
                    % end

                    % Store a template psychObj for this side
                    if subjIdx == 1
                        templatePsychObj{sideIdx} = psychObj;
                    end

                end

                % PLOTTING GROUP LEVEL DATA POINTS
                % Use the combined trial data across all subjects
                questDataCombined = templatePsychObj{sideIdx}.questData;
                questDataCombined.trialData = comboTrialData{sideIdx};

                % Count stimulus presentations and outcomes for combined data
                stimCounts = qpCounts(qpData(questDataCombined.trialData), questDataCombined.nOutcomes);

                stim = zeros(length(stimCounts), questDataCombined.nStimParams);
                nTrials = zeros(1, length(stimCounts));
                pRespondDifferent = zeros(1, length(stimCounts));

                for cc = 1:length(stimCounts)
                    stim(cc) = stimCounts(cc).stim;
                    nTrials(cc) = sum(stimCounts(cc).outcomeCounts);
                    pRespondDifferent(cc) = stimCounts(cc).outcomeCounts(2) / nTrials(cc);
                end

                % Marker properties (size by nTrials, fixed shape/color by side)
                markerSizeIdx = discretize(nTrials, 3);
                markerSizeSet = [50, 100, 150]; 
                markerShapeSet = ['o', '^'];
                markerColorSet = [0, 0, 0.5; 0.5, 0, 0]; % low side = blue, high side = red

                for cc = 1:length(stimCounts)
                    scatter(stim(cc), pRespondDifferent(cc), markerSizeSet(markerSizeIdx(cc)), ...
                        'Marker', markerShapeSet(sideIdx), ...
                        'MarkerFaceColor', markerColorSet(sideIdx, :), ...
                        'MarkerEdgeColor', 'k', ...
                        'MarkerFaceAlpha', nTrials(cc)/max(nTrials));  
                    hold on
                end

            end

            % For each side, build a new questData with trials combined across subjects
            questData = cell(1, nSides);
            for sideIdx = 1:2
                questData{sideIdx} = templatePsychObj{sideIdx}.questData;
                questData{sideIdx}.trialData = comboTrialData{sideIdx};
            end

            % Get the stim domain from the combined object
            stimParamsDomainListLow = [templatePsychObj{1}.stimParamsDomainList];
            stimParamsDomainListHigh = [templatePsychObj{2}.stimParamsDomainList];

            % Define bounds for fitting
            % Finding ub and lb for the high and low side psychometric objects
            lbLow = cellfun(@(x) min(x),templatePsychObj{1}.psiParamsDomainList);
            ubLow = cellfun(@(x) max(x),templatePsychObj{1}.psiParamsDomainList);
            % ubLow = [0,50,0];

            lbHigh = cellfun(@(x) min(x),templatePsychObj{2}.psiParamsDomainList);
            ubHigh = cellfun(@(x) max(x),templatePsychObj{2}.psiParamsDomainList);
            % ubHigh = [0,50,0];

            % Fit low side
            % Temporarily turn off verbosity
            storeVerboseLow = templatePsychObj{1}.verbose;
            templatePsychObj{1}.verbose = false;

            [psiParamsQuestLow, psiParamsFitLow, psiParamsCILow, fValLow] = templatePsychObj{1}.reportParams('lb',lbLow,'ub',ubLow,'nBoots',100, 'questData', questData{1});

            templatePsychObj{1}.verbose = storeVerboseLow;

            % Fit high side
            % Temporarily turn off verbosity
            storeVerboseHigh = templatePsychObj{2}.verbose;
            templatePsychObj{2}.verbose = false;

            [psiParamsQuestHigh, psiParamsFitHigh, psiParamsCIHigh, fValHigh] = templatePsychObj{2}.reportParams('lb',lbHigh,'ub',ubHigh,'nBoots',100, 'questData', questData{2});

            templatePsychObj{2}.verbose = storeVerboseHigh;
    
            % Plotting
            % Low side
            hold on
            for cc = 1:length(stimParamsDomainListLow)
                outcomes = questData{1}.qpPF(stimParamsDomainListLow(cc),psiParamsFitLow);
                fitRespondDiff(cc) = outcomes(2);
            end
            plot(abs(stimParamsDomainListLow),fitRespondDiff,'Color', [0, 0, 0.5]);

            fitRespondDiff = [];

            % High side
            for cc = 1:length(stimParamsDomainListHigh)
                outcomes = questData{2}.qpPF(stimParamsDomainListHigh(cc),psiParamsFitHigh);
                fitRespondDiff(cc) = outcomes(2);
            end
            plot(stimParamsDomainListHigh,fitRespondDiff,'Color', [0.5, 0, 0]);
            hold off

            % Labels and range
            xlim([0 6.75]);
            ylim([-0.1 1.1]);
            if freqIdx == length(refFreqSetHz)  % Bottom row
                xlabel('absolute stimulus difference [dB]');
            end
            if contrastIdx == 1 % Left column
                ylabel('proportion respond different');
            end

            % Add a title, dependent on side
            if sideIdx == 1
                str = sprintf('%2.1d Hz; [μ,σ,λ] = [%2.2f,%2.2f,%2.2f]', ...
                    templatePsychObj{1}.refFreqHz, psiParamsFitLow);
            else
                str = sprintf('%2.1d Hz; [μ,σ,λ] = [%2.2f,%2.2f,%2.2f]', ...
                    templatePsychObj{2}.refFreqHz, psiParamsFitHigh);
            end
            title(str);
            box off

        end

    end

end

