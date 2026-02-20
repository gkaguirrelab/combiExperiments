%% SETUP: Bayesian inference and probability of different calculation
% This code produces plots to explain the framework of our Bayesian same different model

% Sigma values
sigmaTest = 0.5; % sigma test
sigmaRef = 0.5;  % sigma ref (aka sigma zero)
% Sigma ref is lower than sigma test to reflect adaptation to the reference

% Priors
pSame = 0.4;
pDiff = 0.6;

% Stimulus range
possibleStimDiffDb = [-5, 5];

% Possible theta values for different trials
% These are the true stimulus differences, approximates the prior p(theta | D = 1)
thetaMin = min(possibleStimDiffDb);
thetaMax = max(possibleStimDiffDb);
thetaRange = linspace(thetaMin, thetaMax, 1000); % smoother than stimDiffDb
thetaRange = thetaRange(find(thetaRange ~= 0)); % do not include 0 in the range

% Measurement grid for numerical integration
% The variable that the observer actually sees, possible measurement values 
mGrid = linspace(min(possibleStimDiffDb), max(possibleStimDiffDb), 1000)';  % column vector
dm = mGrid(2) - mGrid(1);

% Uniform prior for D = 1
p_theta_given_D1 = ones(size(thetaRange)) / (thetaMax - thetaMin);

% Likelihood = marginal likelihood for same trials (D = 0)
% m represents the difference between the measurements
P_m_given_D0 = normpdf(mGrid, 0, sqrt(2)*sigmaRef); % std dev is sqrt(2)*sigmaZero

% Marginal likelihood for different trials (D = 1) as integral of Gaussians (box shape)
dtheta = thetaRange(2) - thetaRange(1);
% normpdf() produces a matrix, with rows = m values and columns = theta values
% each column is p(m | theta_j)
likelihood = normpdf(mGrid, thetaRange, sqrt(sigmaTest^2 + sigmaRef^2));
% taking the sum(..., 2) is an integral: averages across theta values for each fixed m
P_m_given_D1 = sum(likelihood .* p_theta_given_D1, 2) * dtheta;

% Precompute posterior P(D = 1 | m) (same for all stimDiffDb)
% Provides the decision rule
P_D1_given_m = (P_m_given_D1 * pDiff) ./ (P_m_given_D0 * pSame + P_m_given_D1 * pDiff);
P_D0_given_m = (P_m_given_D0 * pSame) ./ (P_m_given_D0 * pSame + P_m_given_D1 * pDiff);

% Decision rule
% Depends only on internal measurement, not on theta
decisionDifferent = (P_D1_given_m > 0.5);
dm = mGrid(2) - mGrid(1);

% Create figure with three panels
figure('Position',[100 100 2200 500]);
axis tight; 
