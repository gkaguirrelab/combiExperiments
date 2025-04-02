function plotContrastThreshByFreq(subjectID, NDlabel)
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

 % Define a struct with psychObj files
 %for dd = 1:length(modDirections)
 for dd = 1:2

     experimentDir = fullfile(subjectDir,[modDirections{dd} '_ND' NDlabel],experimentName);
     numFreqs = numel(dir(experimentDir)) - 2; % Subtract 2 for '.' and '..'
     fileList = dir(experimentDir);

     for ff = 1:numFreqs
        % Loading in psychObj file for each test frequency and mod direction
        detectionData.(modDirections{dd}).(['Freq_',num2str(ff)]) = load([experimentDir, '/',fileList(ff + 2).name]); % +2 to skip '.' and '..' directories
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

     end

     [frequencies(dd, :), idx] = sort(frequencies(dd, :), 2); 
     threshPhotoContrasts(dd, :) = threshPhotoContrasts(dd, idx);
     sensitivity(dd,:) = 1./((threshPhotoContrasts(dd,:).*100));

     plot(frequencies(dd,:), sensitivity(dd,:))


 end
 % Add labels
xlabel('Frequency (Hz)');
ylabel('Contrast Sensitivity');
title('Threshold vs. Frequency');
xscale log;
xticks(frequencies(1, :));
xlim([2,50]);
legend('L minus M wide','Light Flux');


end