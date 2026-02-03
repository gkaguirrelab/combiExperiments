function [amplitude, phase, yFit] = fitFourier(y, options)
% Perform a fourier regression for a passed time series
%
% Syntax:
%  [amplitude, phase] = fitFourier(y, options)
%
% Description:
%   Fit a time series with a Fourier regression.
%
% Inputs:
%   y                     - Vector.
%
% Outputs:
%   none
%

%% argument block
arguments
    y
    options.fps = 180
    options.fitFreqHz = 1/60;
end

% Prepare the return arguments
amplitude = nan;
phase = nan;

% Set up the regression matrix
t = 0:1/options.fps:(length(y)-1)/options.fps;
X = [];
X(:,1) = sin(  t.*options.fitFreqHz.*2*pi );
X(:,2) = cos(  t.*options.fitFreqHz.*2*pi );

if all(isnan(y))
    return
end

% Remove any nans
goodIdx = ~isnan(y);
y = y(goodIdx);
X = X(goodIdx,:);

% Regress
b = X\y';
amplitude = norm(b);
phase = -atan2(b(2),b(1));

% Create the yFit
yFit = (X*b)';

end