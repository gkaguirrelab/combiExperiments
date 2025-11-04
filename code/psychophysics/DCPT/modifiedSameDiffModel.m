function pDifferent = modifiedSameDiffModel( stimDiffDb, p )
% Probability of reporting "different" in a same different judgement
%
% Syntax:
%   pDifferent = modifiedSameDiffModel( stimDiffDb, p )
%
% Description:
%   Describe this here, including the special v state at 0 dB. Define the
%   parameters in this description
%
% Inputs:
%   stimDiffDb            - Vector of numeric values. The difference
%                           between the stimuli in units of decibels.
%   p                     - 1x4 vector of parameter values that controls
%                           the output of the model.
%
% Optional key/value pairs:
%   none
%
% Outputs:
%   pDifferent            - Vector of same length as stimDiffDb that gives
%                           the probability of reporting "different" for
%                           that degree of stimulus difference.
%
% Examples:
%{
    % Define some params
    p = [1.4, 2.5, 0.5, 1]
    stimDiffDb = -5:0.5:5;
    pDifferent = modifiedSameDiffModel( stimDiffDb, p );
    plot(stimDiffDb, pDifferent,'*-r');
%}

% Unpack the parameters
m = p(1);
crit_baseline = p(2);
sigma = p(3);
x_limit = p(4);

% First calculate the "c" value, which is the criterion that the observer
% uses to determine if same or different given the internal measurement.
if abs(stimDiffDb) <= x_limit
    c = crit_baseline - m * (x_limit - abs(stimDiffDb));
else
    c = crit_baseline;
end

% Parameters
mu_R = 0;     % mean of reference
mu_T = stimDiffDb;     % mean of test

% Function for the joint PDF f(mR, mT)
f = @(mR, mT) normpdf(mR, mu_R, sigma) .* normpdf(mT, mu_T, sigma);

% The integral limits are defined by the criterion: mR - c <= mT <= mR + c
mR_min = -inf;
mR_max = inf;

% Lower limit for mT: g(mR) = mR - c
g = @(mR) mR - c;

% Upper limit for mT: h(mR) = mR + c
h = @(mR) mR + c;

try
    P_same_integral2 = integral2(f, mR_min, mR_max, g, h);
catch
    P_same_integral2 = NaN;
end

pDifferent = 1 - P_same_integral2;

end