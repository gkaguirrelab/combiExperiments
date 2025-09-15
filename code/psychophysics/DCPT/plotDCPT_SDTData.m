function plotDCPT_SDTData(subjectID, refFreqSetHz, modDirections, targetPhotoContrast, NDLabel)
% % Function to plot the high and low ends of a psychometric funciton on the
% % same graph.
% % e.g.,
%{

subjectID = 'FLIC_0018';
refFreqSetHz = logspace(log10(10),log10(30),5);
modDirections = {'LightFlux'};
targetPhotoContrast = [0.10; 0.30];  % [Low contrast levels; high contrast levels] 
% Light Flux is [0.10; 0.30]
NDLabel = {'3x0'};
plotDCPT_SDTData(subjectID, refFreqSetHz, modDirections, targetPhotoContrast, NDLabel);
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

for lightIdx = 1:length(NDLabel)
  
    % Set up a figure
    figHandle = figure(lightIdx);
    figuresize(750,1200,'units','pt')

    tcl = tiledlayout(length(refFreqSetHz),nContrasts);
    title(tcl, [lightLevelLabels{lightIdx} ' with Photo Contrasts: ' num2str(targetPhotoContrast(1)) ', ' num2str(targetPhotoContrast(2))]);

    for freqIdx = 1:length(refFreqSetHz)
        dataDir = fullfile(subjectDir,[modDirections{1} '_ND' NDLabel{lightIdx} '_shifted'],experimentName);

        for contrastIdx = 1:nContrasts

            nexttile;
            hold on

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

                % Get the Max Likelihood psi params, temporarily turning off verbosity.
                lb = cellfun(@(x) min(x),psychObj.psiParamsDomainList);
                ub = cellfun(@(x) max(x),psychObj.psiParamsDomainList);
                ub(2) = 10; % because we messed up when we collected data
                storeVerbose = psychObj.verbose;
                psychObj.verbose = false;
                % questData.qpPF = @qpPFWeibull;
                [psiParamsQuest, psiParamsFit, psiParamsCI, fVal] = psychObj.reportParams('lb',lb,'ub',ub,'nBoots',100);
                psychObj.verbose = storeVerbose;

                % Get the proportion respond "different" for each stimulus
                stimCounts = qpCounts(qpData(questData.trialData),questData.nOutcomes);
                stim = zeros(length(stimCounts),questData.nStimParams);
                for cc = 1:length(stimCounts)
                    stim(cc) = stimCounts(cc).stim;
                    nTrials(cc) = sum(stimCounts(cc).outcomeCounts);
                    pRespondDifferent(cc) = stimCounts(cc).outcomeCounts(2)/nTrials(cc);
                end

                % Plot these
                markerSizeIdx = discretize(nTrials,3);
                markerSizeSet = [25,50,100];
                markerShapeSet = ['o', '^'];   
                markerColorSet = [0, 0, 0.5; 0.5, 0, 0];   % blue, red. low, high
                for cc = 1:length(stimCounts)
                    scatter(stim(cc),pRespondDifferent(cc),markerSizeSet(markerSizeIdx(cc)), ...
                        'Marker', markerShapeSet(sideIdx), ...
                        'MarkerFaceColor', markerColorSet(sideIdx,:), ...
                        'MarkerEdgeColor','k', ...
                        'MarkerFaceAlpha',nTrials(cc)/max(nTrials));
                         % 'MarkerFaceColor',[pRespondDifferent(cc) 0 1-pRespondDifferent(cc)], 
                    hold on
                end

                psychObjArray{sideIdx} = psychObj;

            end

            % Add the psychometric functions
            stimParamsDomainListLow = [psychObjArray{1}.stimParamsDomainList];
            stimParamsDomainListHigh = [psychObjArray{2}.stimParamsDomainList];

            % Get the Max Likelihood psi params, temporarily turning off verbosity.

            % Finding ub and lb for the high and low side psychometric objects
            lbLow = cellfun(@(x) min(x),psychObjArray{1}.psiParamsDomainList);
            ubLow = cellfun(@(x) max(x),psychObjArray{1}.psiParamsDomainList);
            % ubLow = [0,50,0];

            lbHigh = cellfun(@(x) min(x),psychObjArray{2}.psiParamsDomainList);
            ubHigh = cellfun(@(x) max(x),psychObjArray{2}.psiParamsDomainList);
            % ubHigh = [0,50,0];

            % Low side
            % Temporarily turn off verbosity
            storeVerboseLow = psychObjArray{1}.verbose;
            psychObjArray{1}.verbose = false;

            [psiParamsQuestLow, psiParamsFitLow, psiParamsCILow, fValLow] = psychObjArray{1}.reportParams('lb',lbLow,'ub',ubLow,'nBoots',100);

            psychObjArray{1}.verbose = storeVerboseLow;

            % High side
            % Temporarily turn off verbosity
            storeVerboseHigh = psychObjArray{2}.verbose;
            psychObjArray{2}.verbose = false;

            [psiParamsQuestHigh, psiParamsFitHigh, psiParamsCIHigh, fValHigh] = psychObjArray{2}.reportParams('lb',lbHigh,'ub',ubHigh,'nBoots',100);

            psychObjArray{2}.verbose = storeVerboseHigh;
    
            % Plotting
            % Low side
            hold on
            for cc = 1:length(stimParamsDomainListLow)
                outcomes = psychObjArray{1}.questData.qpPF(stimParamsDomainListLow(cc),psiParamsFitLow);
                fitRespondDiff(cc) = outcomes(2);
            end
            plot(abs(stimParamsDomainListLow),fitRespondDiff,'Color', [0, 0, 0.5]);

            fitRespondDiff = [];

            % High side
            for cc = 1:length(stimParamsDomainListHigh)
                outcomes = psychObjArray{2}.questData.qpPF(stimParamsDomainListHigh(cc),psiParamsFitHigh);
                fitRespondDiff(cc) = outcomes(2);
            end
            plot(stimParamsDomainListHigh,fitRespondDiff,'Color', [0.5, 0, 0]);
            hold off

            % Add a marker for the 50% point
            %        outcomes = psychObj.questData.qpPF(psiParamsFit(1),psiParamsFit);
            %        plot([psiParamsFit(1), psiParamsFit(1)],[0, outcomes(2)],':k')
            %        plot([min(stimParamsDomainList), psiParamsFit(1)],[0.5 0.5],':k')

            % Labels and range
            xlim([0 6.75]);
            ylim([-0.1 1.1]);
            if freqIdx == length(refFreqSetHz)  % Bottom row
                xlabel('absolute stimulus difference [dB]');
            end
            if contrastIdx == 1 % Left column
                ylabel('proportion respond different');
            end

            % Add a title
            str = sprintf('%2.1d Hz; [μ,σ,λ] = [%2.2f,%2.2f,%2.2f]', psychObjArray{1}.refFreqHz, psiParamsFit);
            title(str);
            box off

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

