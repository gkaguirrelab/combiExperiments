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
    options.returnBoots = false;
    options.nBoots = 1000;
end

% Prepare the return arguments
amplitude = nan;
phase = nan;

% Get the dimension of the y variable
m = size(y,2);
n = size(y,1);

% Set up the regression matrix
t = 0:1/options.fps:(m-1)/options.fps;

if all(isnan(y))
    return
end

% Prepare a boot strap resampling set
if options.returnBoots && n>1
    nBoots = options.nBoots;
    for ii = 1:nBoots
        bootSet(:,ii) = datasample(1:n, n, 'Replace', true);
    end
else
    nBoots = 1;
    bootSet(:,1) = 1:n;
end

% Loop over the bootset
for ii = 1:nBoots

    % Get this bootstrap resample
    subY = mean(y(bootSet(:,ii),:),1,'omitmissing');

    % Generate the regression matrix
    X = [];
    X(:,1) = sin(  t.*options.fitFreqHz.*2*pi );
    X(:,2) = cos(  t.*options.fitFreqHz.*2*pi );

    % Remove any nans
    goodIdx = ~isnan(subY);
    subY = subY(goodIdx);
    X = X(goodIdx,:);

    % Regress
    b = X\subY';
    amplitude(ii) = norm(b);
    phase(ii) = -atan2(b(2),b(1));
end

% Create the yFit if we are not performing bootstrapping
if ~options.returnBoots
    yFit = (X*b)';
else
    yFit = nan;
end

end