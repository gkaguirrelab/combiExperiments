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
%   Internal noisy measurements are assumed to follow:
%       m1 ~ N(0, sigma)
%       m2 ~ N(Δ, sigma)
%
%   Under the SAME hypothesis (D = 0):
%       Δ = 0   (both stimuli generate the same internal mean)
%
%   Under the DIFFERENT hypothesis (D = 1):
%       Δ = stimDiffDb(ii)
%
%   Importantly, only m2 provides discriminative information, because
%   m1 has the same distribution under SAME and DIFFERENT and therefore
%   cancels out in the likelihood ratio.
%
%   The optimal Bayesian decision rule results in a simple linear
%   criterion:
%       Respond "different" when m2 > Δ/2
%
%   This function computes the probability that a noisy sample m2 exceeds
%   that decision boundary under both hypotheses, and then combines these
%   probabilities using the prior probabilities P(SAME) = P(DIFFERENT) = 0.5.
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

% Priors on the two hypotheses
pSame = 0.5;
pDiff = 0.5;

% Preallocate output vector
pDifferent = zeros(size(stimDiffDb));

% Loop over each stimulus difference
for ii = 1:numel(stimDiffDb)

    Delta = stimDiffDb(ii);

    % Bayesian decision boundary: Respond DIFFERENT if  m2 > Delta/2
    boundary = Delta / 2;

    % Probability of responding "different" 
    % Delta defines the trial type
    pDifferent(ii) = 1 - normcdf(boundary, Delta, sigma);

end

end