function [outputArg1,outputArg2] = plotEntoptic(subjectID, modDirections, NDLabel)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
% which directions to analyze
%{
    subjectID = 'HERO_kik';
    modDirections = {'LminusM_wide' 'LightFlux'};
    NDLabel = {'0x5'};
    plotEntoptic(subjectID, modDirections, NDLabel);
%}

modDirectionsLabels = {'LminusM', 'LightFlux'}; 
contrastLabels = {'Low Contrast', 'High Contrast'};

%% Load the data
dropBoxBaseDir=getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir='FLIC_data';
projectName='combiLED';
experimentName = 'DCPT_entoptic';
subjectDir = fullfile(...
    dropBoxBaseDir,...
    dropBoxSubDir,...
    projectName,...
    subjectID);
for directionIdx = 1:length(modDirections)
    dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDLabel{1} '_shifted'],experimentName);

    psychFileStem = ['entoptic.mat'];
    filename = fullfile(dataDir,psychFileStem);
    load(filename,'psychObj');
    ratings(directionIdx, :) = psychObj.entopticResponse; % 1st dimension is mod direction, 2nd dimension is trial number.
    
    contrast(directionIdx, :) = psychObj.contrastOrder;
    refFreq(directionIdx, :) = psychObj.refFreqOrder;
end


% purkinje tree

for directionIdx = 1:length(modDirections)
    dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDLabel{1} '_shifted'],experimentName);

    psychFileStem = ['entoptic.mat'];
    filename = fullfile(dataDir,psychFileStem);
    load(filename,'psychObj');
    purkinje(directionIdx, :) = psychObj.purkinjeResponse; % 0 = yes, 1 = no
    
    contrast(directionIdx, :) = psychObj.contrastOrder;
    refFreq(directionIdx, :) = psychObj.refFreqOrder;
end
%% sort the data

[sortedFreqs(1,:), sortedIdx] = sort(refFreq(1,:), 2);
[sortedFreqs(2,:), sortedIdx] = sort(refFreq(2,:), 2);
sortedContrast = contrast(:, sortedIdx);
sortedRatings = ratings(:, sortedIdx);

% purkinje tree
    sortedPurkinje = purkinje(:, sortedIdx);
%% Plot the data
figure
hold on;

colors = {'r', 'k'};
markers = {'o--', 's-'};
markerSize = [12 6];

for directionIdx = 1:length(modDirections)
    y = sortedRatings(directionIdx, :);
    x = sortedFreqs(directionIdx, :);
    lowcontrastVal = min(sortedContrast(directionIdx, :));
    highcontrastVal = max(sortedContrast(directionIdx, :));
    lowcontrastIdx = find(sortedContrast(directionIdx, :) == lowcontrastVal)
    highcontrastIdx = find(sortedContrast(directionIdx, :) == highcontrastVal)

    plot(x(lowcontrastIdx), y(lowcontrastIdx), [colors{directionIdx}, markers{1}], 'LineWidth', 1.5, 'markerSize', markerSize(directionIdx),...
        'DisplayName', [modDirectionsLabels{directionIdx}, ' ', contrastLabels{1}]);
    plot(x(highcontrastIdx), y(highcontrastIdx), [colors{directionIdx}, markers{2}], 'LineWidth', 1.5, 'markerSize', markerSize(directionIdx),...
        'MarkerFaceColor', colors{directionIdx}, 'DisplayName', [modDirectionsLabels{directionIdx}, ' ', contrastLabels{2}]);

end

xlabel('Freqeuncy', 'FontSize', 16, 'FontWeight','bold');
set(gca, 'XScale', 'log', 'Color', 'white');
xlim([2.7 21]);
ylim([0 10]);
ylabel('Strength of Entoptic Percept(0-9)', 'FontSize', 16, 'FontWeight','bold');
title('Entoptic Response by Frequency and Contrast', 'FontSize', 18,'FontWeight','bold');
set(gcf, 'Color', 'w');
legend('Location', 'best', 'FontSize', 11);
hold off;

%% plot purkinje
figure
hold on;

markers = {'o', 's'};
for directionIdx = 1:length(modDirections)
    y = sortedPurkinje(directionIdx, :);
    x = refFreq(directionIdx, :);
    lowcontrastVal = min(sortedContrast(directionIdx, :));
    highcontrastVal = max(sortedContrast(directionIdx, :));
    lowcontrastIdx = find(sortedContrast(directionIdx, :) == lowcontrastVal);
    highcontrastIdx = find(sortedContrast(directionIdx, :) == highcontrastVal);

    plot(x(lowcontrastIdx), y(lowcontrastIdx), [colors{directionIdx}, markers{1}],'MarkerSize', markerSize(directionIdx), 'LineWidth', 1.5,...
        'DisplayName', [modDirectionsLabels{directionIdx}, ' ', contrastLabels{1}]);
    plot(x(highcontrastIdx), y(highcontrastIdx), [colors{directionIdx}, markers{2}], 'MarkerSize', markerSize(directionIdx), 'LineWidth', 1.5,...
        'MarkerFaceColor', colors{directionIdx}, 'DisplayName', [modDirectionsLabels{directionIdx}, ' ', contrastLabels{2}]);

end

xlabel('Freqeuncy', 'FontSize', 16, 'FontWeight','bold');
ylabel('Purkinje Tree Seen 1= Yes, 0= No', 'FontSize', 16, 'FontWeight','bold');
xlim([2.7 21]);
ylim([-0.2 1.2]);
title('Purkinje Tree Detection by Freqeuncy and Contrast', 'FontSize', 18,'FontWeight','bold');
set(gcf, 'Color', 'w');
legend('Location', 'best', 'FontSize', 11);
hold off;






% 
% outputArg1 = inputArg1;
% outputArg2 = inputArg2;
