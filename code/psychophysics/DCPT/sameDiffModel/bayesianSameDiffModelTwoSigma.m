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
pSame = 0.5;
pDiff = 0.5;
% pSame = priorSame; 
% pDiff = 1 - priorSame; 

% Possible theta values for different trials
thetaRange = linspace(min(stimDiffDb), max(stimDiffDb), 100); % smoother than stimDiffDb
thetaRange = thetaRange(find(thetaRange ~= 0));

% Measurement grid for numerical integration
mGrid = linspace(min(stimDiffDb), max(stimDiffDb), 1000)';  % column vector
dm = mGrid(2) - mGrid(1);

% Likelihood for same trials (D = 0)
P_m_given_D0 = normpdf(mGrid, 0, sqrt(2)*sigmaZero); % std dev is sqrt(2)*sigmaZero

% Likelihood for different trials (D = 1) as integral of Gaussians (box shape)
P_m_given_D1 = mean(normpdf(mGrid, thetaRange, sqrt(sigma^2 + sigmaZero^2)), 2);

% Precompute posterior P(D = 1 | m) (same for all stimDiffDb)
% Provides the decision rule
P_D1_given_m = (P_m_given_D1 * pDiff) ./ (P_m_given_D0 * pSame + P_m_given_D1 * pDiff);

% Decision rule
decisionDifferent = (P_D1_given_m > 0.5);

dm = mGrid(2) - mGrid(1);

% Now compute P("different"|stimDiffDb) numerically
pDifferent = zeros(size(stimDiffDb));

for i = 1:length(stimDiffDb)
    delta = stimDiffDb(i);

    % likelihood of measurement given this stimulus difference
    % sigma represents sensory encoding noise here
    P_m_given_delta = normpdf(mGrid, delta, sqrt(sigma^2 + sigmaZero^2));

    % Normalize
    P_m_given_delta = P_m_given_delta / sum(P_m_given_delta*dm);

    % Probability of decision = integration over measurements
    pDifferent(i) = sum(P_m_given_delta .* decisionDifferent * dm);
end

end

