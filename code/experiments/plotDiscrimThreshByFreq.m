function plotDiscrimThreshByFreq(subjectID, NDlabel, testFreqSetHz, testContrasts)
% Create some figures that summarize the psychometric fitting
% Also saves pdfs of the psychometric fits
if ~exist("testContrasts", 'var')
    testContrasts = [0.025, 0.075; 0.10, 0.30]; % rows = mod dir, columns high low
end

nContrasts = numel(testContrasts(2));
% Define a path to save figures
figureOutDir = '~/Desktop/FlickerFigures';
mkdir(figureOutDir);

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

        numFreqs = numel(testFreqSetHz);
        plotSpec = {'-ro', '-ko'};
        markerColors = {'r', 'k'};



        experimentDir = fullfile(subjectDir,[modDirections{dd} '_ND' NDlabel '_shifted'],experimentName);

        for ff = 1:numFreqs
            % Loading in psychObj file for each test frequency and mod direction
            fileStem = [experimentDir, '/' , subjectID ,'_', modDirections{dd}, '_DCPT.x_refFreq-', num2str(testFreqSetHz(ff)), 'Hz'];
            detectionData.(modDirections{dd}).(['Freq_',num2str(ff)]) = load([fileStem, '.mat']);
            currentFile = detectionData.(modDirections{dd}).(['Freq_',num2str(ff)]);
            % Plot the psychometric function for each frequency and mod dir,
            % save as pdf
            figHandle = currentFile.psychObj.plotOutcome('off');
            filename = fullfile(figureOutDir,[subjectID '_ND' NDlabel '_' modDirections{dd} sprintf('_Freq_%2.1f',testFreqSetHz(ff)) '.pdf']);
            saveas(figHandle,filename,'pdf')
            close(figHandle)

            % Report psiParams
            lb = cellfun(@(x) min(x),currentFile.psychObj.psiParamsDomainList);
            ub = cellfun(@(x) max(x),currentFile.psychObj.psiParamsDomainList);
            [~, psiParamsFit,psiParamsCI] = currentFile.psychObj.reportParams('lb',lb,'ub',ub,'nBoots',nBoots,'confInterval',confInterval);

            % Prepare to calculate photoreceptor contrast
            modResult1 = currentFile.psychObj.modResult1;
            modResult2 = currentFile.psychObj.modResult2;

            photoContrast1 = mean(abs(modResult1.contrastReceptorsBipolar(modResult1.meta.whichReceptorsToTarget)));
            % photoContrast2 = mean(abs(modResult2.contrastReceptorsBipolar(modResult2.meta.whichReceptorsToTarget)));

            threshPhotoContrasts(dd, ff) = photoContrast1 * currentFile.psychObj.relativePhotoContrastCorrection(1) * 10^(psiParamsFit(1));
            threshPhotoContrastsCILow(dd, ff) = photoContrast1 * currentFile.psychObj.relativePhotoContrastCorrection(1) * 10^psiParamsCI(1,1);
            threshPhotoContrastsCIHigh(dd, ff) = photoContrast1 * currentFile.psychObj.relativePhotoContrastCorrection(1) * 10^psiParamsCI(2,1);
            frequencies(dd, ff) = currentFile.psychObj.testFreqHz;

        end

        if dd == 1
            yyaxis left
            plot(frequencies(dd,:), 1./threshPhotoContrasts(dd, :), plotSpec{dd}, 'MarkerSize', 6,'MarkerFaceColor', markerColors{dd});
            hold on
            for ff = 1:numFreqs
                plot([frequencies(dd,ff) frequencies(dd,ff)],[1./threshPhotoContrastsCILow(dd,ff) 1./threshPhotoContrastsCIHigh(dd,ff)], 'r-', 'LineWidth', 2, 'MarkerSize', 6);
            end
            ylim([1 1250]);
            ylabel('[1/contrast L-M]');
        else
            yyaxis right
            plot(frequencies(dd,:), 1./threshPhotoContrasts(dd, :), plotSpec{dd}, 'MarkerSize', 6,'MarkerFaceColor', markerColors{dd});
            for ff = 1:numFreqs
                plot([frequencies(dd,ff) frequencies(dd,ff)],[1./threshPhotoContrastsCILow(dd,ff) 1./threshPhotoContrastsCIHigh(dd,ff)], 'k-', 'LineWidth', 2, 'MarkerSize', 6);
            end
            ylim([1 500]);
            ylabel('[1/contrast Light Flux]');
        end

        % Add a fit using the Watson temporal senisitivity function, weighted by
        % the bootstrapped error
        % y = 1./threshPhotoContrasts(dd, :);
        % w = 1./(1./threshPhotoContrastsCILow(dd,:) - 1./threshPhotoContrastsCIHigh(dd,:));
        % p0 = [500,1,5,2];
        % myWatson = @(p,x) p(1).*watsonTemporalModel(x, p(2:4));
        % myObj = @(p) sqrt(sum(w.*((myWatson(p,frequencies(dd,:))-y).^2)));
        % pFit = fmincon(myObj,p0,[],[],[],[],[1,0,0,0]);

        % Add the fit
        % xFit = logspace(log10(1),log10(50),50);
        % yFit = myWatson(pFit,xFit);
        %    plot(xFit,(yFit),'-','Color','b','LineWidth',1.5)



        % Add labels
        xlabel('Frequency (Hz)');
        xscale log;
        xticks(frequencies(1, :));
        xlim([2,50]);
        title('Frequency vs. Contrast Sensitivity');
        legend('L minus M wide','','','', '', '', 'Light Flux');

        % Change the color of the axes
        ax = gca;
        ax.YAxis(1).Color = 'red';
        ax.YAxis(2).Color = 'black';
    end
end

end