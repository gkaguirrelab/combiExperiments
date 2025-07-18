function [outputArg1,outputArg2] = plotDiscomf(subjectID, modDirections, NDLabel)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
% which directions to analyze
%{
    subjectID = 'HERO_sam';
    modDirections = {'LminusM_wide' 'LightFlux'};
    NDLabel = {'0x5'};
    plotDiscomf(subjectID, modDirections, NDLabel);
%}

modDirectionsLabels = {'LminusM', 'LightFlux'}; 
contrastLabels = {'Low Contrast', 'High Contrast'};

%% Load the data
dropBoxBaseDir=getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir='FLIC_data';
projectName='combiLED';
experimentName = 'DCPT_discomfort';
subjectDir = fullfile(...
    dropBoxBaseDir,...
    dropBoxSubDir,...
    projectName,...
    subjectID);
for directionIdx = 1:length(modDirections)
    dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDLabel{1} '_shifted'],experimentName);

    psychFileStem = ['discomfort.mat'];
    filename = fullfile(dataDir,psychFileStem);
    load(filename,'psychObj');
    ratings(directionIdx, :) = psychObj.discomfortRating; % 1st dimension is mod direction, 2nd dimension is trial number.
    contrast(directionIdx, :) = psychObj.contrastOrder;
    refFreq(directionIdx, :) = psychObj.refFreqOrder;
end

%% sort the data

[sortedFreqs(1,:), sortedIdx] = sort(refFreq(1,:), 2);
[sortedFreqs(2,:), sortedIdx] = sort(refFreq(2,:), 2);
sortedContrast = contrast(:, sortedIdx);% try filling this in
sortedRatings = ratings(:, sortedIdx);% try filling this in

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
    lowcontrastIdx = find(sortedContrast(directionIdx, :) == lowcontrastVal);
    highcontrastIdx = find(sortedContrast(directionIdx, :) == highcontrastVal);

    plot(x(lowcontrastIdx), y(lowcontrastIdx), [colors{directionIdx}, markers{1}], 'LineWidth', 1.5, 'markerSize', markerSize(directionIdx),...
        'DisplayName', [modDirectionsLabels{directionIdx}, ' ', contrastLabels{1}]);
    plot(x(highcontrastIdx), y(highcontrastIdx), [colors{directionIdx}, markers{2}], 'LineWidth', 1.5, 'markerSize', markerSize(directionIdx),...
        'MarkerFaceColor', colors{directionIdx}, 'DisplayName', [modDirectionsLabels{directionIdx}, ' ', contrastLabels{2}]);

end

xlabel('Frequency', 'FontSize', 16, 'FontWeight','bold');
set(gca, 'XScale', 'log', 'Color', 'white');
xlim([2.7 21]);
ylim([0 11]);
ylabel('Discomfort Rating', 'FontSize', 16, 'FontWeight','bold');
title('Discomfort Ratings by Frequency and Contrast', 'FontSize', 18,'FontWeight','bold');
set(gcf, 'Color', 'w');
legend('Location', 'best', 'FontSize', 11);
hold off; 
% 
% outputArg1 = inputArg1;
% outputArg2 = inputArg2;
