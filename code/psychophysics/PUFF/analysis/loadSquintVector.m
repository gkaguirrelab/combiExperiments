function [palpFissureHeight, confidence] = loadSquintVector( eyeFeaturesPath, options )
% Returns the palpebral fissure and pupil diameter with blink events nan'd
%
% Syntax:
%   palpFissureHeight = loadSquintVector( eyeFeaturesPath )
%
% Description:
%   Load the eyelid features from a single trial, extract the palpebral
%   fissue width at the mid-point of the eye, smooth the vector with a
%   moving median window (which integrates blinks and the squint well).
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
%   palpFissureHeight
%
% Examples:
%{
%}


%% argument block
arguments
    eyeFeaturesPath
    options.fps = 180
    options.startTimeSecs = 0
    options.vecDurSecs = 60
    options.smoothWindowSecs = 5
    options.confidenceThresh = 0.5
    options.makePlotFlag = false % Unused
end

% Load the data
load(eyeFeaturesPath,'eyeFeatures');
nDataCells = length(eyeFeatures.data);

% Create the temporal support
t = 0:1/options.fps:(nDataCells-1)/options.fps;

% Identify the start and end frame
[~,startFrame] = min(abs(t-options.startTimeSecs));
[~,endFrame] = min(abs(t-(options.startTimeSecs+options.vecDurSecs)));
nFrames = endFrame-startFrame;

% Force nFrames to not exceed the total number of frames
nFrames = min([nFrames nDataCells-startFrame]);

% Loop over the frames and calculate the palpebral fissure width at the
% midpoint of the upper and lower lid
palpFissureHeight = nan(1,nFrames);
confidence = nan(1,nFrames);
for ff = startFrame:nFrames
    thisFrame = ff+startFrame-1;
    xVals = eyeFeatures.data{thisFrame}.eyelids.eyelid_x;
    lidUpper = eyeFeatures.data{thisFrame}.eyelids.eyelid_up_y;
    lidLower = eyeFeatures.data{thisFrame}.eyelids.eyelid_lo_y;
    [~,xIdx] = min(abs(xVals-mean(xVals)));
    val = lidLower(xIdx) - lidUpper(xIdx);
    if val > 0 && val < 100
        palpFissureHeight(ff) = val;
    end
    confidence(ff) = mean(eyeFeatures.data{thisFrame}.eyelids.dlc_confidence);
end

% Nan any points with confidence below threshold
palpFissureHeight(confidence < options.confidenceThresh) = nan;

% Perform smoothing
palpFissureHeight = movmean(palpFissureHeight,round(options.smoothWindowSecs*options.fps),"omitnan");

end

