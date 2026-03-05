function [palpFissureHeightCleaned, pupilDiameterCleaned] = loadBlinkCleanedData( eyeFeaturesPath, options )
% Returns the palpebral fissure and pupil diameter with blink events nan'd
%
% Syntax:
%   [palpFissureHeightCleaned, pupilDiameterCleaned] = loadBlinkCleanedData(eyeFeaturesPath);
%
% Description:
%   This function is used to extract a cleaned measure of the palpebral
%   fissure and pupil diameter from a video recorded while subjects view a
%   dark visual field. From this a median width / diameter can be derived.
%   This function is designed to work in situations with minimal squinting
%   and occasional blinks.
%
% Inputs:
%   eyeFeaturesPath       - Char vector or string. Full path to an
%                           eyeFeatures results file.
%
% Optional key/value pairs:
%  'bar'                  - Scalar. Bar bar bar bar bar bar bar bar bar bar
%                           bar bar bar bar bar bar bar bar bar bar bar bar
%                           bar bar bar bar bar bar
%
% Outputs:
%   palpFissureHeightCleaned
%   pupilDiameterCleaned
%
% Examples:
%{
%}


%% argument block
arguments
    eyeFeaturesPath
    options.videoDurSecs = 55
    options.fps = 180
    options.blinkDurSecs = 0.5
    options.makePlotFlag = false
    options.addToExistingPlot = false
end

% How many frames should we expect?
nFrames = options.videoDurSecs*options.fps;

% Load the data
load(eyeFeaturesPath,'eyeFeatures');

% Detect if the length of the video is markedly different from as expected,
% and trim if necessary
nDataCells = length(eyeFeatures.data);
if abs(nFrames-nDataCells)/nFrames > 0.01
    warning('The number of frames in this eyeFeatures file is not as expected');
end
if nDataCells < nFrames
    nFrames = nDataCells;
end
data = eyeFeatures.data(1:nFrames);

% Extract the upper and lower lid to calculate the height of the palpebral
% fissure over time
palpFissureHeight = nan(1,nFrames);
pupilDiameter = nan(1,nFrames);

% Loop over the frames and calculate the palpebral fissure width at the
% midpoint of the upper and lower lid
for tt = 1:nFrames
    xVals = data{tt}.eyelids.eyelid_x;
    lidUpper = data{tt}.eyelids.eyelid_up_y;
    lidLower = data{tt}.eyelids.eyelid_lo_y;
    [~,xIdx] = min(abs(xVals-mean(xVals)));
    val = lidLower(xIdx) - lidUpper(xIdx);
    if val > 0 && val < 100
        palpFissureHeight(tt) = val;
    end
    pupilDiameter(tt) = data{tt}.pupil.diameter;
end

% This is a vector of blink events
blinkVec = diff(palpFissureHeight < median(palpFissureHeight,'omitmissing')/2)>0;

% Slide a window along and ensure that no more than one blink event exists
% within a 0.25 second window
for tt = 1:length(blinkVec)
    if blinkVec(tt) == 1
        blinkVec(tt+1:tt+options.fps/4)=0;
    end
end

% NaN the palp and pupil vectors around the time of each blink
offsets = -floor(0.33*options.blinkDurSecs*options.fps) : floor(0.66*options.blinkDurSecs*options.fps);
idx = find(blinkVec)' + offsets;
idx = idx(:); 
idx = idx(idx >= 1 & idx <= nFrames);
palpFissureHeightCleaned = palpFissureHeight;
palpFissureHeightCleaned(unique(idx)) = NaN;
pupilDiameterCleaned = pupilDiameter;
pupilDiameterCleaned(unique(idx)) = NaN;

% Plot the original and cleaned vectors
if options.makePlotFlag
    t = 0:1/options.fps:(nFrames-1)/options.fps;
    if ~options.addToExistingPlot
    figure
    tiledlayout("vertical");
    end
    nexttile
    plot(t,repmat(median(palpFissureHeightCleaned,'omitmissing'),size(t)),'-b','LineWidth',2);
    hold on
    plot(t,palpFissureHeight,'-k');
    plot(t,palpFissureHeightCleaned,'.r');
    [~,filename]=fileparts(eyeFeaturesPath);
    title({filename,'Palpebral fissure height'},'Interpreter','none');
end


end

