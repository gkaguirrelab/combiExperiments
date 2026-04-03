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
tmp = load(eyeFeaturesPath);

% Check if the variable is named 'eyeFeatures' or 'eye_features'
if isfield(tmp, 'eyeFeatures')
    eyeFeatures = tmp.eyeFeatures;
elseif isfield(tmp, 'eye_features')
    eyeFeatures = tmp.eye_features;
else
    error('Could not find eyeFeatures or eye_features in the file');
end

% Handle the "Zach style" nesting: eye_features.eye_features
if isfield(eyeFeatures, 'eye_features')
    eyeFeatures = eyeFeatures.eye_features;
end

% Check if we are dealing with a struct that has a .data field 
% or a direct cell array
if isstruct(eyeFeatures) && isfield(eyeFeatures, 'data')
    dataExtract = eyeFeatures.data;
else
    dataExtract = eyeFeatures; % It is already the cell array
end

nDataCells = length(dataExtract);
t = 0:1/options.fps:(nDataCells-1)/options.fps;

[~,startFrame] = min(abs(t-options.startTimeSecs));
[~,endFrame] = min(abs(t-(options.startTimeSecs+options.vecDurSecs)));
nFrames = min([endFrame-startFrame, nDataCells-startFrame]);

palpFissureHeight = nan(1,nFrames);
confidence = nan(1,nFrames);

for ff = 1:nFrames
    thisFrame = ff + startFrame - 1;
    
    % Access the frame (using {} for cell array)
    xVals = dataExtract{thisFrame}.eyelids.eyelid_x;
    lidUpper = dataExtract{thisFrame}.eyelids.eyelid_up_y;
    lidLower = dataExtract{thisFrame}.eyelids.eyelid_lo_y;
    
    [~,xIdx] = min(abs(xVals-mean(xVals)));
    val = lidLower(xIdx) - lidUpper(xIdx);
    
    if val > 0 && val < 100
        palpFissureHeight(ff) = val;
    end
    confidence(ff) = mean(dataExtract{thisFrame}.eyelids.dlc_confidence);
end

% Nan any points with confidence below threshold
palpFissureHeight(confidence < options.confidenceThresh) = nan;
% Perform smoothing
if options.smoothWindowSecs > 0
    palpFissureHeight = movmean(palpFissureHeight,round(options.smoothWindowSecs*options.fps),"omitnan");
end

end

