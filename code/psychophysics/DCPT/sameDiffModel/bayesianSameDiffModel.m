function pDifferent = bayesianSameDiffModel( stimDiffDb, sigma )
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
    pDifferent = bayesianSameDiffModel(stimDiffDb, sigma );
    plot(stimDiffDb, pDifferent,'*-r');
%}

% Priors
pSame = 0.5;
pDiff = 0.5;

% Possible theta values for different trials
thetaRange = linspace(min(stimDiffDb), max(stimDiffDb), 100); % smoother than stimDiffDb

% Measurement grid for numerical integration
mGrid = linspace(min(stimDiffDb), max(stimDiffDb), 1000)';  % column vector
dm = mGrid(2) - mGrid(1);

% Likelihood for same trials (D = 0)
P_m_given_D0 = normpdf(mGrid, 0, sqrt(2)*sigma); % std dev is sqrt(2)*sigma

% Likelihood for different trials (D = 1) as mixture/average of Gaussians (box shape)
P_m_given_D1 = mean(normpdf(mGrid, thetaRange, sqrt(2)*sigma), 2);

% Precompute posterior P(D = 1 | m) (same for all stimDiffDb)
P_D1_given_m = (P_m_given_D1 * pDiff) ./ (P_m_given_D0 * pSame + P_m_given_D1 * pDiff);

% Likelihood of m given each stimulus difference (Delta)
% Make mGrid a column vector, stimDiffDb a row vector
mMat = repmat(mGrid, 1, numel(stimDiffDb));
DeltaMat = repmat(stimDiffDb, length(mGrid), 1);

P_m_given_trial = normpdf(mMat, DeltaMat, sqrt(2)*sigma);

% Compute probability of responding "different" for each Delta
pDifferent = sum(P_D1_given_m .* P_m_given_trial, 1) * dm;

