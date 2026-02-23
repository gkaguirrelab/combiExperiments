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
xlabel('True stimulus difference \theta');
ylabel('Prior \it{p}(\theta | \it{D})');
title('Stimulus Priors');
% legend('\it{D}\rm = 1 (different trials, uniform prior)', ...
%        '\it{D}\rm = 0 (same trials, delta function prior)', ...
%        'Location', 'Northeast', 'Interpreter', 'tex');
legend(' \it{p}\rm(\theta | \it{D}\rm = 1)', ...
        ' \it{p}\rm(\theta | \it{D}\rm = 0) (delta function)');
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
for ii = 1:length(exampleIdx)
    theta_i = thetaRange(exampleIdx(ii));
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
ylabel('Likelihood \it{p}(\it{m} | \it{D})');
title('Likelihood Functions');
% Have to add spaces in the legend for each conditional likelihood graph
legend({'Conditional likelihoods \it{p}\rm(\it{m}\rm | \theta)', '', '', '', '', '', '', '', '', '',  ...
    'Marginal likelihood \it{p}\rm(\it{m}\rm | \it{D} = 1)', ...
    'Marginal likelihood \it{p}\rm(\it{m}\rm | \it{D}\rm = 0)',});
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
ylabel('Posterior \it{p}(\it{D} | \it{m})');
title('Posteriors and Decision Threshold');
legend({' \it{p}\rm(\it{D}\rm = 1 | \it{m}\rm)', ' \it{p}\rm(\it{D} = 0 | \it{m}\rm)', 'Decision threshold'}, ...
       'Location', 'Northeast');

% Axes limits
xlim([thetaMin thetaMax]);
ylim([-0.05 1.05]);  % small padding above/below 0/1
set(gca, 'FontSize', 14);
box off;

%% Stimulus-specific integration: can be added as a fourth panel

% Integrating under the likelihood of the measurement given this stimulus difference
delta = 1.5; % choose stimulus (dB value)

% Measurement distribution for this stimulus
P_m_given_delta = normpdf(mGrid, delta, sqrt(sigmaRef^2 + sigmaTest^2));
P_m_given_delta = P_m_given_delta / sum(P_m_given_delta*dm); % normalize
% Probability of responding "different" (MAP rule)
pDifferent = sum(P_m_given_delta .* decisionDifferent) * dm;

% subplot(1,4,4); hold on;
figure; hold on; 

% Create masked distribution for shading
P_shade = P_m_given_delta;
P_shade(~decisionDifferent) = 0;  % zero outside decision region

% Shade region where observer responds "different"
area(mGrid, ...
     P_shade, ...
     'FaceColor', [0 0.4470 0.7410], ...
     'FaceAlpha', 0.2, ...
     'EdgeColor', 'none');

% Plot measurement distribution
plot(mGrid, P_m_given_delta, 'k', 'LineWidth', 1.5);

% Plot decision boundary lines
idx = find(diff(decisionDifferent));
mB1 = mGrid(idx(1));
mB2 = mGrid(idx(2));
xline(mB1,'--','Color',[0.3 0.3 0.3]);
xline(mB2,'--','Color',[0.3 0.3 0.3]);

xlabel('Internal measurement difference \it{m}');
ylabel('\it{p}(m | \theta)');
title(['Stimulus-specific integration (\theta = ' num2str(delta) ')']);

legend({' Region → respond "different"', ...
        ' \it{p}(m|\theta)'}, ...
        'Location','Northeast');

xlim([thetaMin thetaMax]);
set(gca, 'FontSize', 14);
box off;

% SHADING ON POSTERIOR
figure; hold on; 

% Plot posteriors
plot(mGrid, P_D1_given_m, 'b-', 'LineWidth', 1.5);
plot(mGrid, P_D0_given_m, 'k-', 'LineWidth', 1.5);
yline(0.5, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1);

% Find boundaries where decision changes
idx = find(diff(decisionDifferent));
mB1 = mGrid(idx(1));
mB2 = mGrid(idx(2));

% Highlight "different" regions with patches
% Left tail
patch([min(mGrid) mB1 mB1 min(mGrid)], [0 0 1 1], [0 0.4470 0.7410], 'FaceAlpha', 0.2, 'EdgeColor', 'none');
% Right tail
patch([mB2 max(mGrid) max(mGrid) mB2], [0 0 1 1], [0 0.4470 0.7410], 'FaceAlpha', 0.2, 'EdgeColor', 'none');

xlabel('Internal measurement difference \it{m}');
ylabel('Posterior \it{p}(\it{D} | \it{m})');
title('Posteriors and Decision Threshold with Decision Regions');
legend({'\it{p}(\it{D}=1|\it{m})', '\it{p}(\it{D}=0|\it{m})', 'Decision threshold', 'Decision "different" region'}, ...
       'Location', 'Northeast');
set(gca, 'FontSize', 14);
box off;

%% Posteriors for different sigma test and ref values

% Change this variable to change sigmaTest values instead of sigmaRef
changeSigmaRef = false;

if changeSigmaRef
    sigmaTest = 0.5;                   % keep sigmaTest constant
    sigmaRefs = linspace(0.2,0.8,5);  % sweep sigmaRef
else
    sigmaRef = 0.5;                     % keep sigmaRef constant
    sigmaTests = linspace(0.1,0.9,5);  % sweep sigmaTest
end  
pSame = 0.5; pDiff = 0.5;
mGrid = linspace(-5,5,1000)';  

figure; hold on;
if changeSigmaRef
    nSigmas = length(sigmaRefs);
else
    nSigmas = length(sigmaTests);
end

% Create color ramps: light to dark
blueRamp = [linspace(0.6,0, nSigmas)', linspace(0.8,0.4470, nSigmas)', linspace(1,0.7410, nSigmas)']; % lighter to darker blue
blackRamp = repmat(linspace(0.6,0,nSigmas)',1,3); % lighter to darker gray/black

for ii = 1:nSigmas
    hold on;
    if changeSigmaRef
        sigmaRef = sigmaRefs(ii);
    else
        sigmaTest = sigmaTests(ii);
    end

    % Likelihoods
    P_m_given_D0 = normpdf(mGrid, 0, sqrt(2)*sigmaRef);
    thetaRange = linspace(-5,5,1000); thetaRange(thetaRange==0) = []; 
    p_theta_given_D1 = ones(size(thetaRange)) / (max(thetaRange)-min(thetaRange));
    dtheta = thetaRange(2)-thetaRange(1);
    likelihood = normpdf(mGrid, thetaRange, sqrt(sigmaTest^2 + sigmaRef^2));
    P_m_given_D1 = sum(likelihood .* p_theta_given_D1,2) * dtheta;

    % Posteriors
    P_D1_given_m = (P_m_given_D1*pDiff) ./ (P_m_given_D0*pSame + P_m_given_D1*pDiff);
    P_D0_given_m = 1 - P_D1_given_m;

    % Plot with fading color
    plot(mGrid, P_D1_given_m, 'Color', blueRamp(ii,:), 'LineWidth', 1.5);   % D=1
    plot(mGrid, P_D0_given_m, 'Color', blackRamp(ii,:), 'LineWidth', 1.5);  % D=0
end

xlabel('Internal measurement difference m');
ylabel('Posterior \it{p}\rm(\it{D}\rm | \it{m}\rm)');
if changeSigmaRef
    title('Posterior for increasing sigmaRef (sigmaTest = 0.5)');
else
    title('Posterior for varying sigmaTest (sigmaRef = 0.5)');
end
set(gca,'FontSize',14); box off;

% Optional legend (simpler: just indicate fading)
legend({' \it{p}\rm(\it{D}\rm = 1 | \it{m}\rm)', ' \it{p}\rm(\it{D}\rm = 0 | \it{m}\rm)'}, 'Location','NorthWest');

%% ANIMATION of changing posterior with different sigmaRef and sigmaTest vals

% Change this variable to change sigmaTest values instead of sigmaRef
changeSigmaRef = true;

if changeSigmaRef
    sigmaTest = 0.5;                   % keep sigmaTest constant
    sigmaVals = linspace(0.2,0.8,50);  % sweep sigmaRef
else
    sigmaRef = 0.5;                     % keep sigmaRef constant
    sigmaVals = linspace(0.2,0.8,50);  % sweep sigmaTest
end

pSame = 0.5; pDiff = 0.5;
mGrid = linspace(-5,5,1000)';  
nFrames = length(sigmaVals);

% Prepare figure
figure('Position',[100 100 700 500]); 
h1 = plot(mGrid, zeros(size(mGrid)), 'b-', 'LineWidth', 2); hold on; % D=1
h2 = plot(mGrid, zeros(size(mGrid)), 'k-', 'LineWidth', 2);           % D=0
yline(0.5,'--','LineWidth',1, 'Color', [0.4 0.4 0.4]);                          % threshold
xlabel('Internal measurement difference m'); ylabel('Posterior P(D|m)');
title('Posterior animation');
set(gca,'FontSize',14); xlim([-5 5]); ylim([0 1]); box off;

% Prepare GIF
% the gif is saved in this directory
if changeSigmaRef
    filename = ['/Users/rubybouh/Aguirre-Brainard Lab Dropbox/Ruby Bouhassira/' ...
        'FLIC_analysis/dichopticFlicker/bayesianModelPlots/posterior_animation_sigmaRef.gif'];
else
    filename = ['/Users/rubybouh/Aguirre-Brainard Lab Dropbox/Ruby Bouhassira/' ...
        'FLIC_analysis/dichopticFlicker/bayesianModelPlots/posterior_animation_SigmaTest.gif'];
end
totalTime = 4;            % target total duration (seconds)
delayPerFrame = totalTime / nFrames;

% Create dummy lines for legend before the loop
hD1 = plot(NaN,NaN,'-','Color',[0 0.4470 0.7410],'LineWidth',1.5); % D=1
hD0 = plot(NaN,NaN,'-','Color',[0 0 0],'LineWidth',1.5);           % D=0
legend([hD1, hD0], {' \it{p}\rm(\it{D}\rm = 1 | \it{m}\rm)', ' \it{p}\rm(\it{D}\rm = 0 | \it{m}\rm)'}, 'Location', 'Northeast');

for loop = 1:3  % repeat 3 times
    for ii = 1:nFrames
        % Select current sigma
        if changeSigmaRef
            sigmaRef = sigmaVals(ii);
        else
            sigmaTest = sigmaVals(ii);
        end

        % Compute posteriors
        P_m_given_D0 = normpdf(mGrid, 0, sqrt(2)*sigmaRef);
        thetaRange = linspace(-5,5,1000); thetaRange(thetaRange==0) = []; 
        p_theta_given_D1 = ones(size(thetaRange)) / (max(thetaRange)-min(thetaRange));
        dtheta = thetaRange(2)-thetaRange(1);
        likelihood = normpdf(mGrid, thetaRange, sqrt(sigmaTest^2 + sigmaRef^2));
        P_m_given_D1 = sum(likelihood .* p_theta_given_D1,2) * dtheta;
        P_D1_given_m = (P_m_given_D1*pDiff) ./ (P_m_given_D0*pSame + P_m_given_D1*pDiff);
        P_D0_given_m = 1 - P_D1_given_m;

        % Update plot
        set(h1, 'YData', P_D1_given_m);
        set(h2, 'YData', P_D0_given_m);

        % Fade colors: light → dark
        % Blue line (D=1)
        baseBlue = [0 0.4470 0.7410];

        % Fade from light → dark
        lightestBlue = [0.7 0.85 1];  % light blue
        darkestBlue  = baseBlue;      % full MATLAB blue

        % Interpolate between lightest and darkest
        colorBlue = lightestBlue + (darkestBlue - lightestBlue)*(ii/nFrames);

        set(h1, 'Color', colorBlue);

        % Black line (D=0), fade from light gray → black
        lightestGray = 0.7;
        darkestGray  = 0.2;
        lightFactorGray = lightestGray - (lightestGray - darkestGray)*(ii/nFrames);
        colorBlack = [1 1 1]*lightFactorGray;
        set(h2, 'Color', colorBlack);

        % Title with current sigma
        if changeSigmaRef
            title(sprintf('Posterior: sigmaRef = %.2f, sigmaTest = %.2f', sigmaRef, sigmaTest));
        else
            title(sprintf('Posterior: sigmaRef = %.2f, sigmaTest = %.2f', sigmaRef, sigmaTest));
        end

        drawnow;

        % Capture GIF frame
        frame = getframe(gcf);
        [im,map] = rgb2ind(frame2im(frame),256);
        if loop == 1 && ii == 1
            imwrite(im,map,filename,'gif','LoopCount',Inf,'DelayTime',delayPerFrame);
        else
            imwrite(im,map,filename,'gif','WriteMode','append','DelayTime',delayPerFrame);
        end

    end

    % Add a pause before the next loop
    pause(1);

end

%% Elementary plot of the likelihood as a difference of Gaussians

% WORK ON THE LABELING HERE

% Conceptual illustration: reference vs test likelihoods and their difference
sigma = 1;       % standard deviation of measurement
delta = 3;       % test stimulus difference

m = linspace(-5, 8, 1000);

% Reference likelihood (centered at 0)
P_ref = normpdf(m, 0, sigma);

% Test likelihood (centered at delta)
P_test = normpdf(m, delta, sigma);

% Difference distribution: ref - test
% Variance adds: sigma_diff = sqrt(sigma^2 + sigma^2) = sqrt(2)*sigma
P_diff = normpdf(m, 0, sqrt(2)*sigma);  % centered at 0 if diff = ref - test

% Plot
figure; hold on;
plot(m, P_ref, 'k-', 'LineWidth', 2);
plot(m, P_test, 'b-', 'LineWidth', 2);
plot(m, P_diff, 'r-.', 'LineWidth', 2);

xlabel('Internal measurement m');
ylabel('Likelihood / Difference');
title('Reference vs Test Distributions and their Difference');
legend({'Reference (0 dB)', 'Test (3 dB)', 'Likelihood'}, 'Location','NorthEast');
xlim([-5 8]);
ylim([0 max([P_ref P_test P_diff])*1.2]);
set(gca,'FontSize',14); box off;