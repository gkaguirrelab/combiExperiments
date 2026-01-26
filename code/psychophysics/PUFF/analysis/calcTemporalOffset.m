function [lagFrames, output] = calcTemporalOffset( eyeFeaturesPathA, eyeFeaturesPathB, options )
% Circ shift (in secs) of B to maximize correlation with A
%
% Syntax:
%   lagFrames = calcTemporalOffset( eyeFeaturesPathA, eyeFeaturesPathB, options )
%
% Description:
%   There is a temporal offset between the left and the right eye cameras.
%   This routine uses a cross-correlation approach to estimate this offset
%   between two recordings.
%
% Inputs:
%   eyeFeaturesPathA      - Char vector or string. Full path to an
%                           eyeFeatures results file.
%   eyeFeaturesPathB      - Char vector or string. Full path to an
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
    eyeFeaturesPathA
    eyeFeaturesPathB
    options.fps = 180
    options.startTimeSecs = 0
    options.vecDurSecs = 60
    options.makePlotFlag = false
end

% Set up options for the call to loadSquintVector
options.medianWindow = 1;
cellOptions = namedargs2cell(options);

% Load the data
palpFissureHeightA = loadSquintVector(eyeFeaturesPathA,cellOptions{:});
palpFissureHeightB = loadSquintVector(eyeFeaturesPathB,cellOptions{:});

% Use the circular cross-correlation to find the lag that maximizes the
% correlation between these two unsmoothed vectors
[corrVals, lags] =cxcorr(palpFissureHeightA, palpFissureHeightB);
[~,idx]=max(corrVals);
lagFrames = lags(idx);

% Report the initial and corrected correlation
output.rInitial = corrVals(lags==0);
output.rFinal = corrVals(idx);

% Plot the original and shifted vectors
if options.makePlotFlag
    t = 0:1/options.fps:(length(palpFissureHeightA)-1)/options.fps;
    figure
    tiledlayout("vertical");
    nexttile
    plot(t,palpFissureHeightA,'-k','LineWidth',2);
    hold on
    plot(t,palpFissureHeightB,'-r','LineWidth',1);
    title(sprintf('Before correction, r = %2.2f',output.rInitial));
    xlabel('time [secs]');
    nexttile
    plot(t,palpFissureHeightA,'-k','LineWidth',2);
    hold on
    plot(t,circshift(palpFissureHeightB,lagFrames),'-r','LineWidth',1);
    title(sprintf('Lag %d frames, r = %2.2f',lagFrames,output.rFinal));
    xlabel('time [secs]');
end

end

