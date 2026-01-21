function pDifferent = bayesianSameDiffModelTwoSigma( stimDiffDb, sigmaParams, priorSame )
% Probability of reporting "different" in a same different judgement
%
% Syntax:
%   pDifferent = bayesianSameDiffModel( stimDiffDb, sigma )
%
% Description:
%   Bayesian same–different discrimination model.
%
%   Computes the observer's probability of reporting "different" for each
%   physical stimulus difference Δ in the vector stimDiffDb.
%
% Inputs:
%   stimDiffDb  - Vector of numeric values. The difference
%                 between the stimuli in units of decibels.
%
%   sigma       - Scalar numeric value. Standard deviation of sensory noise
%                 for internal measurements m1 and m2.
%
% Outputs:
%   pDifferent  - Vector of same length as stimDiffDb that gives
%                 the probability of reporting "different" for
%                 that degree of stimulus difference.
%
% Examples:
%{
    sigma = 0.3
    stimDiffDb = -10:0.5:10;    
    pDifferent = bayesianSameDiffModelTwoSigma(stimDiffDb, sigma );
    plot(stimDiffDb, pDifferent,'*-r');
%}

% Unpack two sigma values
sigma = sigmaParams(1);
sigmaZero = sigmaParams(2);

% Priors
pSame = priorSame;
pDiff = 1 - priorSame;

% Possible theta values for different trials
% These are the true stimulus differences, approximates the prior p(theta | D = 1)
thetaRange = linspace(min(stimDiffDb), max(stimDiffDb), 100); % smoother than stimDiffDb
thetaRange = thetaRange(find(thetaRange ~= 0)); % do not include 0 in the range

% Measurement grid for numerical integration
% The variable that the observer actually sees, possible measurement values 
mGrid = linspace(min(stimDiffDb), max(stimDiffDb), 1000)';  % column vector
dm = mGrid(2) - mGrid(1);

% Likelihood = marginal likelihood for same trials (D = 0)
% m represents the difference between the measurements
P_m_given_D0 = normpdf(mGrid, 0, sqrt(2)*sigmaZero); % std dev is sqrt(2)*sigmaZero

% Marginal likelihood for different trials (D = 1) as integral of Gaussians (box shape)
P_m_given_D1 = mean(normpdf(mGrid, thetaRange, sqrt(sigma^2 + sigmaZero^2)), 2);
% normpdf() produces a matrix, with rows = m values and columns = theta values
% each column is p(m | theta_j)
% taking the mean(..., 2) averages across theta values for each fixed m

% Precompute posterior P(D = 1 | m) (same for all stimDiffDb)
% Provides the decision rule
P_D1_given_m = (P_m_given_D1 * pDiff) ./ (P_m_given_D0 * pSame + P_m_given_D1 * pDiff);

% Decision rule
% Depends only on internal measurement, not on theta
decisionDifferent = (P_D1_given_m > 0.5);

dm = mGrid(2) - mGrid(1);

% Now compute P("different"|stimDiffDb) numerically
pDifferent = zeros(size(stimDiffDb));

for i = 1:length(stimDiffDb)
    delta = stimDiffDb(i);
    % If the true stimulus value were theta, how often would
    % the observer say different?

    % Likelihood of measurement given this stimulus difference
    % This is the sensory encoding stage
    % Observer treats every trial as if it might be a difference trial
    P_m_given_delta = normpdf(mGrid, delta, sqrt(sigmaZero^2 + sigma^2));

    % Normalize
    P_m_given_delta = P_m_given_delta / sum(P_m_given_delta*dm);

    % Probability of decision = integration (average) over measurements
    % Add up the fractions of trials in each measurement bin that lead to a "diff" response
    pDifferent(i) = sum(P_m_given_delta .* decisionDifferent) * dm;
end

end

