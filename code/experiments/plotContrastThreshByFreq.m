function plotContrastThreshByFreq(subjectID, NDlabel, testFreqSetHz)
% Create some figures that summarize the psychometric fitting

% Set our file path
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
experimentName = 'DCPT_detect';

% Define the modulation and data directories
subjectDir = fullfile(...
    dropBoxBaseDir,...
    dropBoxSubDir,...
    projectName,...
    subjectID);

% Define modulation directions
modDirections = {'LminusM_wide','LightFlux'};

% Plot L minus M and light flux on the same figure
figure; hold on

numFreqs = numel(testFreqSetHz);
colors = {'-ro', '-ko'};
markerColors = {'r', 'k'};

 % Define a struct with psychObj files
 %for dd = 1:length(modDirections)
 for dd = 1:2

     experimentDir = fullfile(subjectDir,[modDirections{dd} '_ND' NDlabel],experimentName);
     results = [];

     for ff = 1:numFreqs
        % Loading in psychObj file for each test frequency and mod direction
        detectionData.(modDirections{dd}).(['Freq_',num2str(ff)]) = load([experimentDir, '/' , subjectID ,'_', modDirections{dd}, '_DCPT_detect.x_refFreq-', num2str(testFreqSetHz(ff)), 'Hz.mat']); % +2 to skip '.' and '..' directories
        currentFile = detectionData.(modDirections{dd}).(['Freq_',num2str(ff)]);

        % Report psiParams
        lb = cellfun(@(x) min(x),currentFile.psychObj.psiParamsDomainList);
        ub = cellfun(@(x) max(x),currentFile.psychObj.psiParamsDomainList);
        [~, psiParamsFit] = currentFile.psychObj.reportParams('lb',lb,'ub',ub);
          
        % Save the threshold modulation contrast on a linear scale
        rawThreshold(ff) = 10^(psiParamsFit(1));

        modResult1 = currentFile.psychObj.modResult1;
        modResult2 = currentFile.psychObj.modResult2;

        photoContrast1 = mean(abs(modResult1.contrastReceptorsBipolar(modResult1.meta.whichReceptorsToTarget)));
        % photoContrast2 = mean(abs(modResult2.contrastReceptorsBipolar(modResult2.meta.whichReceptorsToTarget)));

        threshPhotoContrasts(dd, ff) = photoContrast1 * currentFile.psychObj.relativePhotoContrastCorrection(1) * rawThreshold(ff); 
        frequencies(dd, ff) = currentFile.psychObj.testFreqHz;

        % Obtain boot-strapped params
        nBoots = 200; confInterval = 0.68;
        [~,fitParams,fitParamsCI] = currentFile.psychObj.reportParams(...
            'nBoots',nBoots,'confInterval',confInterval);
        results(ff).freqHz = currentFile.psychObj.testFreqHz;
        results(ff).logContrastThresh = fitParams(1);
        results(ff).logContrastThreshLow = fitParamsCI(1,1);
        results(ff).logContrastThreshHigh = fitParamsCI(2,1);

     end

     [frequencies(dd, :), idx] = sort(frequencies(dd, :), 2); 
     sensitivity = 1./threshPhotoContrasts(dd, idx);

     for ff = 1:numFreqs
         if dd == 1
             yyaxis left
             plot(frequencies(dd,:), sensitivity, colors{dd}, 'MarkerSize', 6,'MarkerFaceColor', markerColors{dd}, 'lineWidth', 2);
             errorbar(frequencies(dd,:), sensitivity, results(ff).logContrastThreshLow, results(ff).logContrastThreshHigh, 'bo-', 'LineWidth', 2, 'MarkerSize', 6);
             ylim([100 1000])
             ylabel('[1/contrast L-M]');
         else
             yyaxis right
             plot(frequencies(dd,:), sensitivity, colors{dd}, 'MarkerSize', 6,'MarkerFaceColor', markerColors{dd}, 'lineWidth', 2);
             errorbar(frequencies(dd,:), sensitivity, results(ff).logContrastThreshLow, results(ff).logContrastThreshHigh, 'bo-', 'LineWidth', 2, 'MarkerSize', 6);
             ylim([1 350])
             ylabel('[1/contrast Light Flux]');
         end
     end

     % Add a fit using the Watson temporal senisitivity function, weighted by
     % the bootstrapped error
     % y = sensitivity;
     % w = 1./(1./(modContrast*10.^[results.logContrastThreshLow])- 1./(modContrast*10.^[results.logContrastThreshHigh]));
     % myWatson = @(p,x) p(1).*watsonTemporalModel(x, p(2:4));
     % myObj = @(p) sqrt(sum(w.*((myWatson(p,x)-y).^2)));
     % pFit = fmincon(myObj,p0,[],[],[],[],[1,0,0,0]);
     % 
     % % Add the fit
     % xFit = logspace(0,2,50);
     % yFit = myWatson(pFit,xFit);
     % plot(log10(xFit),(yFit),'-','Color',plotColor,'LineWidth',1.5)

 end

 % Add labels
xlabel('Frequency (Hz)');
xscale log;
xticks(frequencies(1, :));
xlim([2,50]);
title('Frequency vs. Contrast Sensitivity');
legend('L minus M wide','Light Flux');

% Change the color of the axes
ax = gca;
ax.YAxis(1).Color = 'red';
ax.YAxis(2).Color = 'black';


end