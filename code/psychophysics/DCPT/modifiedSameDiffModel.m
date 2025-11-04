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
    p = [1.4, 2.5, 0.5, 1];
    stimDiffDb = -5:0.5:5;    
    pDifferent = modifiedSameDiffModel(stimDiffDb, p );
    plot(stimDiffDb, pDifferent,'*-r');
%}

% Unpack the parameters
m = p(1);
crit_baseline = p(2);
sigma = p(3);
x_limit = p(4);

% First calculate the "c" value, which is the criterion that the observer
% uses to determine if same or different given the internal measurement.
c = crit_baseline - m * max(0, (x_limit - abs(stimDiffDb)));
% If abs(stimDiffDb) <= x_limit, we will have c = crit_baseline;

% Integral limits
mR_min = -inf;
mR_max = inf;

% Loop for integral evaluation
for ii = 1:numel(stimDiffDb)
    mu_R = 0;
    mu_T = stimDiffDb(ii);

    % Define joint PDF
    f = @(mR, mT) normpdf(mR, mu_R, sigma) .* normpdf(mT, mu_T, sigma);

    % Integration bounds for mT given mR
    g = @(mR) mR - c(ii);
    h = @(mR) mR + c(ii);

    % Compute probability of "same"
    P_same = integral2(f, mR_min, mR_max, g, h);

    % Probability of "different"
    pDifferent(ii) = 1 - P_same;
end

end