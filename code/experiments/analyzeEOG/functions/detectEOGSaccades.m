function [events, debug] = detectEOGSaccades(timebase, EOGSignal, params)
% detectEOGSaccades
%
% General EOG saccade detector.
%
% This function does NOT use command times, expected directions, or trial labels.
% It detects candidate saccades directly from the EOG signal using velocity.
%
% INPUTS
%   timebase  : time vector, in seconds
%   EOGSignal : EOG signal vector
%   params    : optional struct of detection parameters
%
% OUTPUTS
%   events : struct array with one row per detected saccade
%   debug  : struct containing smoothed signal, velocity, and thresholds

    if nargin < 3
        params = struct;
    end

    % -----------------------------
    % Default parameters
    % -----------------------------
    params = setDefault(params, 'smoothWindowSec', 0.02);       % X ms smoothing
    params = setDefault(params, 'velocityThresholdFactor', 8);  % main detection threshold
    params = setDefault(params, 'onsetThresholdFactor', 3);     % lower threshold for onset/offset
    params = setDefault(params, 'quietWindowSec', 0.020);       % velocity must be quiet for X ms
    params = setDefault(params, 'minSaccadeSeparationSec', 0.25);
    params = setDefault(params, 'preBaselineSec', 0.050);
    params = setDefault(params, 'postBaselineSec', 0.080);
    params = setDefault(params, 'postDelaySec', 0.050);
    params = setDefault(params, 'minAmplitude', 0.8);
    params = setDefault(params, 'maxDurationSec', 0.20);
    params = setDefault(params, 'minDurationSec', 0.010);

    % -----------------------------
    % Force column vectors
    % -----------------------------
    t = timebase(:);
    x = EOGSignal(:);

    fsEstimate = 1 / median(diff(t));

    % -----------------------------
    % Smooth signal
    % -----------------------------
    smoothSamples = max(3, round(params.smoothWindowSec * fsEstimate));

    EOGSmooth = movmedian(x, smoothSamples, 'omitnan');
    EOGSmooth = movmean(EOGSmooth, smoothSamples, 'omitnan');

    % -----------------------------
    % Compute velocity / slope
    % -----------------------------
    velocity = gradient(EOGSmooth, t);

    % Robust estimate of baseline velocity noise
    velocityNoise = median(abs(velocity - median(velocity, 'omitnan')), 'omitnan') / 0.6745;

    peakThreshold = params.velocityThresholdFactor * velocityNoise;
    onsetThreshold = params.onsetThresholdFactor * velocityNoise;

    % -----------------------------
    % Find large velocity peaks
    % -----------------------------
    minPeakDistanceSamples = round(params.minSaccadeSeparationSec * fsEstimate);

    [~, peakIdx] = findpeaks(abs(velocity), ...
        'MinPeakHeight', peakThreshold, ...
        'MinPeakDistance', minPeakDistanceSamples);

    % -----------------------------
    % Initialize event struct
    % -----------------------------
    events = struct( ...
        'onsetTime', {}, ...
        'peakTime', {}, ...
        'offsetTime', {}, ...
        'duration', {}, ...
        'amplitude', {}, ...
        'direction', {}, ...
        'peakVelocity', {}, ...
        'strength', {}, ...
        'onsetIndex', {}, ...
        'peakIndex', {}, ...
        'offsetIndex', {} );

    quietSamples = max(2, round(params.quietWindowSec * fsEstimate));

    % -----------------------------
    % Analyze each candidate saccade
    % -----------------------------
    for i = 1:length(peakIdx)

        thisPeakIdx = peakIdx(i);

        % Direction is based on signed velocity at the peak
        thisPeakVelocity = velocity(thisPeakIdx);
        thisDirection = sign(thisPeakVelocity);

        % -----------------------------
        % onset = last point before the peak where velocity was below onset threshold
        % -----------------------------
        beforePeak = find(abs(velocity(1:thisPeakIdx)) < onsetThreshold, 1, 'last');
        
        if isempty(beforePeak)
            onsetIdx = thisPeakIdx;
        else
            onsetIdx = beforePeak + 1;
        end
        
        % -----------------------------
        % offset = first point after peak where velocity drops below onset threshold
        % -----------------------------
        afterPeak = find(abs(velocity(thisPeakIdx:end)) < onsetThreshold, 1, 'first');
        
        if isempty(afterPeak)
            offsetIdx = thisPeakIdx;
        else
            offsetIdx = thisPeakIdx + afterPeak - 2;
        end

        duration = t(offsetIdx) - t(onsetIdx);

        if duration < params.minDurationSec || duration > params.maxDurationSec
            continue
        end

        % -----------------------------
        % Estimate amplitude from pre/post levels
        % -----------------------------
        preIdx = t >= t(onsetIdx) - params.preBaselineSec & ...
                 t <  t(onsetIdx);

        postIdx = t >= t(offsetIdx) + params.postDelaySec & ...
                  t <  t(offsetIdx) + params.postDelaySec + params.postBaselineSec;

        if sum(preIdx) < 5 || sum(postIdx) < 5
            continue
        end

        preLevel = median(EOGSmooth(preIdx), 'omitnan');
        postLevel = median(EOGSmooth(postIdx), 'omitnan');

        amplitude = postLevel - preLevel;

        % Reject tiny events
        if abs(amplitude) < params.minAmplitude
            continue
        end

        % % OPTIONAL: make sure amplitude direction agrees with velocity direction
        % if sign(amplitude) ~= thisDirection
        %     continue
        % end

        % -----------------------------
        % Store event
        % -----------------------------
        n = length(events) + 1;

        events(n).onsetTime = t(onsetIdx);
        events(n).peakTime = t(thisPeakIdx);
        events(n).offsetTime = t(offsetIdx);
        events(n).duration = t(offsetIdx) - t(onsetIdx);
        events(n).amplitude = amplitude;
        events(n).direction = thisDirection;
        events(n).peakVelocity = thisPeakVelocity;
        events(n).strength = abs(amplitude) * abs(thisPeakVelocity);
        events(n).onsetIndex = onsetIdx;
        events(n).peakIndex = thisPeakIdx;
        events(n).offsetIndex = offsetIdx;
    end

    % -----------------------------
    % Debug output for plotting/checking
    % -----------------------------
    debug.timebase = t;
    debug.EOGSmooth = EOGSmooth;
    debug.velocity = velocity;
    debug.velocityNoise = velocityNoise;
    debug.peakThreshold = peakThreshold;
    debug.onsetThreshold = onsetThreshold;
    debug.peakIdx = peakIdx;
end


function params = setDefault(params, fieldName, defaultValue)
    if ~isfield(params, fieldName)
        params.(fieldName) = defaultValue;
    end
end