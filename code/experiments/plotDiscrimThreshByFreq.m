function plotDiscrimThreshByFreq(subjectID, NDLabel, refFreqSetHz, targetPhotoContrast)
% Create some figures that summarize the psychometric fitting
% Also saves pdfs of the psychometric fits
% % e.g.,
%{

subjectID = 'HERO_sam';
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
    for cc = 1:nContrasts
        figure; hold on

        % Bootstrap params
        nBoots = 100; confInterval = 0.68;

        numFreqs = numel(refFreqSetHz);
        plotSpec = {'-ro', '-bo'};
        markerColors = {'r', 'b'};


        experimentDir = fullfile(subjectDir,[char(modDirections{dd}) '_ND' char(NDLabel) '_shifted'],experimentName);
        for ss = 1:length(sides) % hi anbd low
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
                lb = cellfun(@(x) min(x),currentFile.psychObj.psiParamsDomainList);
                ub = cellfun(@(x) max(x),currentFile.psychObj.psiParamsDomainList);
                ub(2) = 10; % we forgot to update psiParamsDomainList oops
                [~, psiParamsFit,psiParamsCI] = currentFile.psychObj.reportParams('lb',lb,'ub',ub,'nBoots',nBoots,'confInterval',confInterval);
                mu(ff) = psiParamsFit(2);
                CIlow(ff) = psiParamsCI(1,2);
                CIhi(ff) = psiParamsCI(2,2);

            end


            plot(refFreqSetHz, mu, plotSpec{ss}, 'MarkerSize', 6,'MarkerFaceColor', markerColors{ss});
            for ff = 1:numFreqs
                plot([refFreqSetHz(ff) refFreqSetHz(ff)],[CIlow(ff) CIhi(ff)], 'Color', markerColors{ss}, 'LineWidth', 2, 'MarkerSize', 6);
            end
            

        end
        % Add labels
        ylim([1 12]);
        ylabel('[Discrim Threshold (db)]');
        xlabel('Frequency (Hz)');
        xscale log;
        xticks(refFreqSetHz);
        xlim([2,30]);
        title([modDirLabels{dd}, ' ' num2str(targetPhotoContrast(cc, dd)), '% Contrast']);
        legend('Hi','','','', '', '', 'Low');

    end
end

end