%% SETUP: Bayesian inference and probability of different calculation
% This code produces plots to explain the framework of our Bayesian same different model

% Sigma values
sigmaTest = 0.5; % sigma test
sigmaRef = 0.3;  % sigma ref (aka sigma zero)
% Sigma ref is lower than sigma test to reflect adaptation to the reference

% Priors
pSame = 0.5;
pDiff = 0.5;

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
P_m_given_D1 = mean(normpdf(mGrid, thetaRange, sqrt(sigmaTest^2 + sigmaRef^2)), 2);
% normpdf() produces a matrix, with rows = m values and columns = theta values
% each column is p(m | theta_j)
% taking the mean(..., 2) averages across theta values for each fixed m

% Precompute posterior P(D = 1 | m) (same for all stimDiffDb)
% Provides the decision rule
P_D1_given_m = (P_m_given_D1 * pDiff) ./ (P_m_given_D0 * pSame + P_m_given_D1 * pDiff);
P_D0_given_m = (P_m_given_D0 * pSame) ./ (P_m_given_D0 * pSame + P_m_given_D1 * pDiff);

% Decision rule
% Depends only on internal measurement, not on theta
decisionDifferent = (P_D1_given_m > 0.5);
dm = mGrid(2) - mGrid(1);

% Create figure with three panels
figure('Position',[100 100 1700 500]);

%% Plot of stimulus priors: first panel

% Plot
subplot(1,3,1); hold on;

% Plot uniform prior (different trials)
plot(thetaRange, p_theta_given_D1, 'Color', [0 0.4470 0.7410], 'LineWidth', 1.5);

% Plot delta function for same trials as a dotted vertical line
% Could add an arrow for clarity
maxHeight = max(p_theta_given_D1) * 1.5;
plot([0 0], [0 maxHeight], '--', 'LineWidth', 1.5, 'Color','k');

% Formatting
xlabel('\theta (true stimulus difference)');
ylabel('p(\theta | \it{D})');
legend('\it{D}\rm = 1 (different trials, uniform prior)', ...
       '\it{D}\rm = 0 (same trials, delta function prior)', ...
       'Location', 'Southeast', 'Interpreter', 'tex');
xlim([thetaMin thetaMax]);
ylim([0 maxHeight]);
set(gca, 'FontSize', 14);

%% Plotting marginal and conditional likelihoods: second panel

% Select a few theta values to plot example shifted Gaussians
exampleIdx = round(linspace(1, length(thetaRange), 10));  % 10 evenly spaced theta
subplot(1,3,2); hold on;

% Plot example shifted Gaussians (light blue)
mainBlue = [0 0.4470 0.7410];
lightBlue = mainBlue + (1 - mainBlue)*0.88;
for i = 1:length(exampleIdx)
    theta_i = thetaRange(exampleIdx(i));
    plot(mGrid, normpdf(mGrid, theta_i, sqrt(sigmaTest^2 + sigmaRef^2)), ...
         'Color', lightBlue,'LineWidth', 1.5);
end

% Marginal "different" likelihood (blue)
plot(mGrid, P_m_given_D1, 'Color', [0 0.4470 0.7410], 'LineWidth', 1.5);

% Same trials Gaussian (black)
plot(mGrid, P_m_given_D0, 'k', 'LineWidth', 1.5);

% Labels and formatting
ax = gca;
ax.Layer = 'top';   % draws axes behind the data
xlabel('Internal measurement difference \it{m}');
ylabel('p(\it{m} | \it{D})');
% Have to add spaces in the legend for each conditional likelihood graph
legend({'Conditional likelihoods p(\it{m} | \theta)', '', '', '', '', '', '', '', '', '',  ...
    'Marginal likelihood p(\it{m} | D = 1)', ...
    'Likelihood p(\it{m} | \it{D} = 0)',});
set(gca, 'FontSize', 14);
xlim([thetaMin thetaMax]);
ylim([0 max([P_m_given_D1; P_m_given_D0])*1.2]);
box off;

%% Plotting posteriors: third panel

subplot(1,3,3); hold on;

% Colors
mainBlue  = [0 0.4470 0.7410];  % D=1
black     = [0 0 0];            % D=0

% Plot P(D=1 | m) → blue
plot(mGrid, P_D1_given_m, 'Color', mainBlue, 'LineWidth', 1.5);

% Plot P(D=0 | m) → black
plot(mGrid, P_D0_given_m, 'Color', black, 'LineWidth', 1.5);

% Optionally, show the decision boundary as a dashed gray line at 0.5
yline(0.5, '-.', 'Color', [0.4 0.4 0.4], 'LineWidth', 1);

% Labels
xlabel('Internal measurement difference \it{m}');
ylabel('Posterior P(\it{D} | \it{m})');
legend({'p(\it{D} = 1 | \it{m})', 'p(\it{D} = 0 | \it{m})', 'Decision threshold'}, ...
       'Location', 'SouthEast');

% Axes limits
xlim([thetaMin thetaMax]);
ylim([-0.05 1.05]);  % small padding above/below 0/1
set(gca, 'FontSize', 14);
box off;

%% Example demonstration: P("different") from posterior

% Pick a stimulus difference to demonstrate
deltaExample = 1; % in dB
% Find closest index in mGrid
[~, idxExample] = min(abs(mGrid - deltaExample));

% Likelihood of measurements given this stimulus
P_m_given_delta = normpdf(mGrid, deltaExample, sqrt(sigmaRef^2 + sigmaTest^2));
P_m_given_delta = P_m_given_delta / sum(P_m_given_delta*dm); % normalize

% Posterior for this example
P_D1_given_m_demo = (P_m_given_D1 * pDiff) ./ (P_m_given_D0 * pSame + P_m_given_D1 * pDiff);

% Decision rule
decisionDifferent_demo = P_D1_given_m_demo > 0.5;

% Probability of responding "different" for this stimulus
pDifferent_demo = sum(P_m_given_delta .* decisionDifferent_demo) * dm;

figure; hold on;

% Plot likelihood
plot(mGrid_row, P_m_given_delta_row, 'Color', [0 0.4470 0.7410], 'LineWidth', 1.5);

% But only shade the likelihood for this δ
fill([mGrid_row fliplr(mGrid_row)], ...
     [zeros(size(mGrid_row)) P_m_given_delta_row .* decisionDifferent_mask], ...
     [0.6 0.8 1], 'FaceAlpha',0.4,'EdgeColor','none');

% Vertical line for example stimulus
xline(deltaExample, '--k', sprintf('\\delta = %.1f dB', deltaExample));

% Annotate probability
text(deltaExample + 0.2, max(P_m_given_delta_row)*0.6, ...
    sprintf('P("different") = %.2f', pDifferent_demo), ...
    'FontSize',12, 'Color', [0 0.4470 0.7410]);

xlabel('Internal measurement m');
ylabel('Likelihood p(m|\delta)');
xlim([thetaMin thetaMax]);
ylim([0 max(P_m_given_delta_row)*1.2]);
set(gca,'FontSize',14);
box off;


%%
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
sigma = sigmaParams(1); % sigma test
sigmaZero = sigmaParams(2);  % sigma ref

% Priors
pSame = priorSame;
pDiff = 1 - priorSame;

% Theoretical stimulus range
% CHANGE TO STIM PARAMS DOMAIN LIST
possibleStimDiffDb = [-5, 5];

% Possible theta values for different trials
% These are the true stimulus differences, approximates the prior p(theta | D = 1)
thetaRange = linspace(min(possibleStimDiffDb), max(possibleStimDiffDb), 1000); % smoother than stimDiffDb
thetaRange = thetaRange(find(thetaRange ~= 0)); % do not include 0 in the range

% Measurement grid for numerical integration
% The variable that the observer actually sees, possible measurement values 
mGrid = linspace(min(possibleStimDiffDb), max(possibleStimDiffDb), 1000)';  % column vector
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
    P_m_given_delta = normpdf(mGrid, delta, sqrt(sigmaZero^2 + sigma^2));

    % Normalize
    P_m_given_delta = P_m_given_delta / sum(P_m_given_delta*dm);

    % Probability of decision = integration (average) over measurements
    % Add up the fractions of trials in each measurement bin that lead to a "diff" response
    pDifferent(i) = sum(P_m_given_delta .* decisionDifferent) * dm;
end

end

