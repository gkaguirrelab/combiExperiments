function [outputArg1,outputArg2] = plotDiscomf(subjectID, modDirections, NDLabel)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
% which directions to analyze
%{
    subjectID = 'HERO_kik';
    modDirections = {'LminusM_wide' 'LightFlux'};
    NDLabel = {'0x5'};
    plotDiscomf(subjectID, modDirections, NDLabel);
%}

modDirectionsLabels = {'LminusM', 'LightFlux'}; 

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
%% Plot the data
figure
hold on;

colors = {'r', 'k'};
markers = {'o', 's'};

for directionIdx = 1:length(modDirections)
    y = ratings(directionIdx, :);
    x = refFreq(directionIdx, :);
    c = contrast(directionIdx, :);

    plot(x, y, [colors{directionIdx}, markers{directionIdx}], 'LineWidth', 1.5, 'DisplayName', modDirections{directionIdx});
end

xlabel('Freqeuncy');
ylabel('Discomford Rating');
titel('Discomfort Ratings by Frequency and Contrast');
legend('Location', 'north' );
hold off; 

   
       


% 
% outputArg1 = inputArg1;
% outputArg2 = inputArg2;
