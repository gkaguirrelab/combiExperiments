function pDifferent = bayesianSameDiffModelTwoSigma( stimParamsDomainList, stimDiffDb, sigmaParams, priorSame )
% Probability of reporting "different" in a same-different judgement
%
% Syntax:
%   pDifferent = bayesianSameDiffModel( stimParamsDomainList, stimDiffDb, sigmaParams, priorSame )
%
% Description:
%   Bayesian same–different discrimination model.
%
%   Computes the observer's probability of reporting "different" for each
%   physical stimulus difference Δ in the vector stimDiffDb.
%
% Inputs:
%   stimParamsDomainList - Range of possible differences between the 
%                stimuli in dB. 
%
%   stimDiffDb   - Vector of numeric values. The actual differences
%                 between the stimuli in dB, presented to the participant
%                 during the experiment.
%
%   sigmaParams   - Scalar numeric values. Standard deviation of sensory noise
%                 for ref and test measurements.  
%                 sigmaParams = [sigmaTest sigmaRef]  
%   
%   priorSame     - Prior probability of same based on the true proportion
%                 of same trials in the experiment.  
% Outputs:
%   pDifferent  - Vector of same length as stimDiffDb that gives
%                 the probability of reporting "different" for
%                 that degree of stimulus difference.
%
% Examples:
%{
    stimParamsDomainList = [0 logspace(log10(0.1),log10(5),30)];
    stimDiffDb = -10:0.5:10;  
    sigmaParams = [0.8 0.3]; 
    priorSame = 0.4; 
    pDifferent = bayesianSameDiffModelTwoSigma(stimParamsDomainList, stimDiffDb, sigmaParams, priorSame);
%}

% For the testing case where sigmaRef = sigmaTest
if numel(sigmaParams) == 1
    sigmaParams = [sigmaParams sigmaParams];
end

% Unpack two sigma values
sigmaTest = sigmaParams(1); % sigma test
sigmaRef = sigmaParams(2);  % sigma ref

% Priors
pSame = priorSame;
pDiff = 1 - priorSame;

% Possible theta values for different trials
% These are the true stimulus differences, approximates the prior p(theta | D = 1)
thetaRange = linspace(min(stimParamsDomainList), max(stimParamsDomainList), 1000); % smoother than stimDiffDb
thetaRange = thetaRange(find(thetaRange ~= 0)); % do not include 0 in the range

% Uniform prior (for "different" trials) over theta
priorTheta = ones(size(thetaRange)) / ...
             (thetaRange(end) - thetaRange(1));

% Measurement grid for numerical integration
% Internal sensory measurement available to the observer 
mGrid = linspace(min(stimParamsDomainList), max(stimParamsDomainList), 1000)';  % column vector
dm = mGrid(2) - mGrid(1);

% Likelihood = marginal likelihood for same trials (D = 0)
% m represents the difference between the measurements
P_m_given_D0 = normpdf(mGrid, 0, sqrt(2)*sigmaRef); % std dev is sqrt(2)*sigmaZero

% Marginal likelihood for different trials (D = 1) as integral of Gaussians (box shape)
dtheta = thetaRange(2) - thetaRange(1);
% normpdf() produces a matrix, with rows = m values and columns = theta values
% each column is p(m | theta_j)
likelihood = normpdf(mGrid, thetaRange, sqrt(sigmaTest^2 + sigmaRef^2));
% taking the sum(..., 2) is an integral: averages across theta values for each fixed m
P_m_given_D1 = sum(likelihood .* priorTheta, 2) * dtheta;

% Precompute posterior P(D = 1 | m) (same for all stimDiffDb)
% Provides the decision rule
P_D1_given_m = (P_m_given_D1 * pDiff) ./ (P_m_given_D0 * pSame + P_m_given_D1 * pDiff);
P_D0_given_m = (P_m_given_D0 * pSame) ./ (P_m_given_D0 * pSame + P_m_given_D1 * pDiff);

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
    % Observer treats every trial as if it might be a different trial
    P_m_given_delta = normpdf(mGrid, delta, sqrt(sigmaRef^2 + sigmaTest^2));

    % Normalize numerical density to integrate to 1 over mGrid
    % This compensates for discretization error
    P_m_given_delta = P_m_given_delta / sum(P_m_given_delta*dm);

    % Probability of decision = integration (average) over measurements
    % Add up the fractions of trials in each measurement bin that lead to a "diff" response
    pDifferent(i) = sum(P_m_given_delta .* decisionDifferent) * dm;
end

end

