function plotDCPTThreshByFreq(subjectID, NDLabel, refFreqSetHz, targetPhotoContrast)
% Create some figures that summarize the psychometric fitting
% Also saves pdfs of the psychometric fits
% % e.g.,
%{

subjectID = 'FLIC_0013';
refFreqSetHz = logspace(log10(3),log10(20),7);
modDirections = {'LightFlux'};
targetPhotoContrast = [0.10; 0.30];  % [Low contrast levels; high contrast levels] 
% Light Flux is [0.10; 0.30]
NDLabel = {'3x0','0x5'};
plotDCPTThreshByFreq(subjectID, NDLabel, refFreqSetHz, targetPhotoContrast);
%}
if ~exist("targetPhotoContrast", 'var')
    targetPhotoContrast = [0.10; 0.30]; % rows = mod dir, columns high low
end

nContrasts = numel(targetPhotoContrast);
% Define a path to save figures
figureOutDir = '~/Desktop/FlickerFigures';
mkdir(figureOutDir);

sides = {'hi' 'low'};

modDirLabels = {'Light Flux'};
lightLevelLabels = {'Low Light', 'High Light'};

% Set our file path
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
experimentName = 'DCPT_SDT';

% Define the modulation and data directories
subjectDir = fullfile(...
    dropBoxBaseDir,...
    dropBoxSubDir,...
    projectName,...
    subjectID);

% Define modulation directions
modDirections = {'LightFlux'};

% Loop through mod directions
for dd = 1:length(NDLabel)
    for ss = 1:length(sides) % hi and low % for cc = 1:nContrasts
        figure; hold on

        % Bootstrap params
        nBoots = 100; confInterval = 0.68;

        numFreqs = numel(refFreqSetHz);
        plotSpec = {'-ro', '-bo'};
        markerColors = {'r', 'b'};
        legHandles = {};


        experimentDir = fullfile(subjectDir,[char(modDirections{1}) '_ND' char(NDLabel{dd}) '_shifted'],experimentName);
        for cc = 1:nContrasts % hi anbd low
            for ff = 1:numFreqs
                % Loading in psychObj file for each test frequency and mod direction
                fileStem = [experimentDir, '/' , subjectID ,'_', modDirections{1}, '_DCPT_SDT_cont-' ...
                    replace(num2str(targetPhotoContrast(cc)), '.', 'x') '_refFreq-', num2str(refFreqSetHz(ff)), 'Hz_' sides{ss}];
                discrimData.(modDirections{1}).(['Freq_',num2str(ff)]) = load([fileStem, '.mat']);
                currentFile = discrimData.(modDirections{1}).(['Freq_',num2str(ff)]);
                % Plot the psychometric function for each frequency and mod dir,
                % save as pdf
                figHandle = currentFile.psychObj.plotOutcome('off');
                filename = fullfile(figureOutDir,[subjectID '_ND' char(NDLabel{dd}) '_' char(modDirections{1}) sprintf('_Freq_%2.1f',refFreqSetHz(ff)) '.pdf']);
                saveas(figHandle,filename,'pdf')
                close(figHandle)

                % Report psiParams
                psiParamsDomainList = currentFile.psychObj.psiParamsDomainList;
                psiParamsDomainList{2} = linspace(0,6.75, 51);
                lb = cellfun(@(x) min(x),psiParamsDomainList);
                ub = cellfun(@(x) max(x),psiParamsDomainList);
               % ub(2) = 15; % we forgot to update psiParamsDomainList oops
                [~, psiParamsFit,psiParamsCI, psiParamsFitBoot] = currentFile.psychObj.reportParams('lb',lb,'ub',ub,'nBoots',nBoots,'confInterval',confInterval);
                mu(ff) = psiParamsFit(2);

                % Finding the confidence intervals for sensitivity
                psiParamsFitBoot(:,2) = 1 ./ psiParamsFitBoot(:, 2);
                psiParamsFitBoot = sort(psiParamsFitBoot);

                idxCI = round(((1-confInterval)/2*nBoots));
                sensitivityCI(1,:) = psiParamsFitBoot(idxCI,:);
                sensitivityCI(2,:) = psiParamsFitBoot(nBoots-idxCI,:);

                CIlow(ff) = sensitivityCI(1,2);
                CIhi(ff) = sensitivityCI(2,2);

                % Alternate method of calculating sensitivity CIs - less accurate
                % sensitivityCI_hi(ff) = 1 ./ psiParamsCI(1,2);  % CIlow becomes the upper bound of sensitivity
                % sensitivityCI_low(ff)  = 1 ./ psiParamsCI(2,2); % CIhi becomes the lower bound of sensitivity

            end

            % Converting thresholds to sensitivities
            sensitivity = 1 ./ mu; 

            % Start by plotting one dot in each color for the legend
            plot(refFreqSetHz(1), sensitivity(1), plotSpec{1}, 'MarkerSize', 6,'MarkerFaceColor', markerColors{1});
            plot(refFreqSetHz(1), sensitivity(1), plotSpec{2}, 'MarkerSize', 6,'MarkerFaceColor', markerColors{2});

            % Plotting sensitivities
            plot(refFreqSetHz, sensitivity, plotSpec{cc}, 'MarkerSize', 6,'MarkerFaceColor', markerColors{cc});

            % Plotting confidence intervals
            for ff = 1:numFreqs
                plot([refFreqSetHz(ff) refFreqSetHz(ff)],[CIlow(ff) CIhi(ff)], 'Color', markerColors{cc}, 'LineWidth', 2, 'MarkerSize', 6);
            end

            legHandles{end + 1} = (sprintf(num2str(targetPhotoContrast(cc),'%2.2d Contrast')));

        end
        % Add labels
        legend(legHandles, 'Location','northwest');
        ylim([0 1.2]);
        ylabel('Sensitivity (1/discrim threshold)');
        xlabel('Frequency (Hz)');
        xscale log;
        xticks(refFreqSetHz);
        xlim([2,30]);
        title([lightLevelLabels{dd}, ' ' char(sides(ss)), ' Side']);

        pause(0.25);

    end
end

end