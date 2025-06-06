function plotDiscrimThreshByFreq(subjectID, NDLabel, refFreqSetHz, targetPhotoContrast)
% Create some figures that summarize the psychometric fitting
% Also saves pdfs of the psychometric fits
% % e.g.,
%{

subjectID = 'HERO_kik';
refFreqSetHz = [3.0000, 4.8206, 7.746, 12.4467, 20.0000];
modDirections = {'LminusM_wide' 'LightFlux'};
targetPhotoContrast = [0.025, 0.10; 0.075, 0.30];  % [Low contrast levels; high contrast levels] 
% L minus M is [0.025, 0.075] and Light Flux is [0.10, 0.30]
NDLabel = {'0x5'};
%}
if ~exist("targetPhotoContrast", 'var')
    targetPhotoContrast = [0.025, 0.075; 0.10, 0.30]; % rows = mod dir, columns high low
end

nContrasts = numel(targetPhotoContrast(2,:));
% Define a path to save figures
figureOutDir = '~/Desktop/FlickerFigures';
mkdir(figureOutDir);

sides = {'hi' 'low'};

modDirLabels = {'L - M', 'Light Flux'};

% Set our file path
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
experimentName = 'DCPT';

% Define the modulation and data directories
subjectDir = fullfile(...
    dropBoxBaseDir,...
    dropBoxSubDir,...
    projectName,...
    subjectID);

% Define modulation directions
modDirections = {'LminusM_wide','LightFlux'};

% Loop through mod directions
for dd = 1:length(modDirections)
    for ss = 1:length(sides) % hi and low % for cc = 1:nContrasts
        figure; hold on

        % Bootstrap params
        nBoots = 100; confInterval = 0.68;

        numFreqs = numel(refFreqSetHz);
        plotSpec = {'-ro', '-bo'};
        markerColors = {'r', 'b'};
        legHandles = {};


        experimentDir = fullfile(subjectDir,[char(modDirections{dd}) '_ND' char(NDLabel) '_shifted'],experimentName);
        for cc = 1:nContrasts % hi anbd low
            for ff = 1:numFreqs
                % Loading in psychObj file for each test frequency and mod direction
                fileStem = [experimentDir, '/' , subjectID ,'_', modDirections{dd}, '_DCPT_cont-' ...
                    replace(num2str(targetPhotoContrast(cc,dd)), '.', 'x') '_refFreq-', num2str(refFreqSetHz(ff)), 'Hz_' sides{ss}];
                discrimData.(modDirections{dd}).(['Freq_',num2str(ff)]) = load([fileStem, '.mat']);
                currentFile = discrimData.(modDirections{dd}).(['Freq_',num2str(ff)]);
                % Plot the psychometric function for each frequency and mod dir,
                % save as pdf
                figHandle = currentFile.psychObj.plotOutcome('off');
                filename = fullfile(figureOutDir,[subjectID '_ND' char(NDLabel) '_' char(modDirections{dd}) sprintf('_Freq_%2.1f',refFreqSetHz(ff)) '.pdf']);
                saveas(figHandle,filename,'pdf')
                close(figHandle)

                % Report psiParams
                psiParamsDomainList = currentFile.psychObj.psiParamsDomainList;
                psiParamsDomainList{2} = linspace(0,6.75, 51);
                lb = cellfun(@(x) min(x),psiParamsDomainList);
                ub = cellfun(@(x) max(x),psiParamsDomainList);
                ub(2) = 15; % we forgot to update psiParamsDomainList oops
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

            legHandles{end + 1} = (sprintf(num2str(targetPhotoContrast(cc, dd),'%2.2d Contrast')));

        end
        % Add labels
        legend(legHandles, 'Location','northwest');
        ylim([0 1.2]);
        ylabel('Sensitivity (1/discrim threshold)');
        xlabel('Frequency (Hz)');
        xscale log;
        xticks(refFreqSetHz);
        xlim([2,30]);
        title([modDirLabels{dd}, ' ' char(sides(ss)), ' Side']);

        pause(0.25);

    end
end

end