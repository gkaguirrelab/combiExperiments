%% SETUP: Bayesian inference and probability of different calculation
% This code produces plots to explain the framework of our Bayesian same different model

% Defining the directory to save plots
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_analysis';
projectName = 'dichopticFlicker';
plotFolderName = 'bayesianModelPlots';

% Sigma values
sigmaTest = 0.8; % sigma test
sigmaRef = 0.3;  % sigma ref (aka sigma zero)
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

%% Plot of stimulus priors: first panel

% Create figure with three panels
figure('Position',[100 100 2200 500]);
axis tight; 

% Plot
subplot(1,3,1); hold on;

blue = [0.25, 0.4, 0.85];
orange = [0.9, 0.4, 0.1];

% Plot uniform prior (different trials)
plot(thetaRange, p_theta_given_D1, 'Color', orange, 'LineWidth', 1.5);

% Plot delta function for same trials as a dotted vertical line
plot([0 0], ylim, '--', 'LineWidth', 1.5, 'Color',blue);

% Formatting
xlabel('Physical stimulus difference \theta');
% ylabel('Probability');
% legend('\it{D}\rm = 1 (different trials, uniform prior)', ...
%        '\it{D}\rm = 0 (same trials, delta function prior)', ...
%        'Location', 'Northeast', 'Interpreter', 'tex');
legend(' \it{p}\rm(\theta | \it{D}\rm = 1)', ...
        ' \it{p}\rm(\theta | \it{D}\rm = 0) (delta function)');
xlim([thetaMin thetaMax]);
ylim([0 1.05]);
ylabel('Probability'); 
yticks([0 0.2 0.4 0.6 0.8 1]);
set(gca, 'FontSize', 30);

%% Plotting marginal and conditional likelihoods: second panel

% Select a few theta values to plot example shifted Gaussians
exampleIdx = round(linspace(1, length(thetaRange), 10));  % 10 evenly spaced theta
subplot(1,3,2); hold on;

% Plot example shifted Gaussians (light blue)
mainOrange = [0.9, 0.4, 0.1];
lightOrange = mainOrange + (1 - mainOrange)*0.82;
for ii = 1:length(exampleIdx)
    theta_i = thetaRange(exampleIdx(ii));
    plot(mGrid, normpdf(mGrid, theta_i, sqrt(sigmaTest^2 + sigmaRef^2)), ...
         'Color', lightOrange,'LineWidth', 1.5);
end

% Marginal "different" likelihood (blue)
plot(mGrid, P_m_given_D1, 'Color', orange, 'LineWidth', 1.5);

% Same trials Gaussian (black)
plot(mGrid, P_m_given_D0, 'Color',blue, 'LineWidth', 1.5);

% Labels and formatting
ax = gca;
ax.Layer = 'top';   % draws axes behind the data
xlabel('Internal measurement difference \it{m}');
% ylabel('Probability');
% Have to add spaces in the legend for each conditional likelihood graph
legend({'\it{p}\rm(\it{m}\rm | \theta)', '', '', '', '', '', '', '', '', '',  ...
    '\it{p}\rm(\it{m}\rm | \it{D} = 1)', ...
    '\it{p}\rm(\it{m}\rm | \it{D}\rm = 0)',});
set(gca, 'FontSize', 30);
xlim([thetaMin thetaMax]);
ylim([0 1.05]);
ylabel('Probability'); 
yticks([0 0.2 0.4 0.6 0.8 1]);
box off;

%% Plotting posteriors: third panel

subplot(1,3,3); hold on;

% Plot P(D=1 | m) → orange
plot(mGrid, P_D1_given_m, 'Color', orange, 'LineWidth', 1.5);

% Plot P(D=0 | m) → blue
plot(mGrid, P_D0_given_m, 'Color', blue, 'LineWidth', 1.5);

% Optionally, show the decision boundary as a dashed gray line at 0.5
yline(0.5, '-.', 'Color', [0.3 0.3 0.3], 'LineWidth', 1);

% Labels
xlabel('Internal measurement difference \it{m}');
% ylabel('Posterior probability');
% title('Posteriors and Decision Threshold');
lgd = legend({' \it{p}\rm(\it{D}\rm = 1 | \it{m}\rm)', ' \it{p}\rm(\it{D} = 0 | \it{m}\rm)', 'Decision rule'}, ...
       'Location', 'Northeast');
lgd.Position(2) = lgd.Position(2) - 0.1;  % move DOWN 

% Axes limits
xlim([thetaMin thetaMax]);
ylim([0 1.05]);
yticks([0 0.2 0.4 0.6 0.8 1]);
set(gca, 'FontSize', 30);
box off;
set(gcf, 'Units', 'inches');
pos = get(gcf, 'Position');

set(gcf, 'PaperUnits', 'inches');
set(gcf, 'PaperSize', [pos(3) pos(4)]);
set(gcf, 'PaperPosition', [0 0 pos(3) pos(4)]);

% print(gcf, 'myfigure.pdf', '-dpdf', '-painters');
%% Stimulus-specific integration: can be added as a fourth panel

% Integrating under the likelihood of the measurement given this stimulus difference
delta = 1; % choose stimulus (dB value)

% Measurement distribution for this stimulus
P_m_given_delta = normpdf(mGrid, delta, sqrt(sigmaRef^2 + sigmaTest^2));
P_m_given_delta = P_m_given_delta / sum(P_m_given_delta*dm); % normalize
% Probability of responding "different" (MAP rule)
pDifferent = sum(P_m_given_delta .* decisionDifferent) * dm;

% subplot(1,4,4); hold on;
figure; hold on; 

% Mask for "different" region
P_diff = P_m_given_delta;
P_diff(~decisionDifferent) = 0;

% Mask for "same" region
P_same = P_m_given_delta;
P_same(decisionDifferent) = 0;

lightOrange = orange + (1 - orange)*0.3;
lightBlue = blue + (1 - blue)*0.3;

% Shade "different" (light orange)
area(mGrid, ...
     P_diff, ...
     'FaceColor', lightOrange, ...
     'FaceAlpha', 0.2, ...
     'EdgeColor', 'none');

hold on;

% Shade "same" (light blue)
area(mGrid, ...
     P_same, ...
     'FaceColor', lightBlue, ...
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
ylabel('Probability');
% title(['Stimulus-specific integration (\theta = ' num2str(delta) ')']);

legend({' Respond "different"', ...
        ' Respond "same"', ...
        ''}, ...
        'Location','Northeast');

xlim([thetaMin thetaMax]);
set(gca, 'FontSize', 18);
ylim([0 1.05]);
yticks([0 0.2 0.4 0.6 0.8 1]);
box off;

% SHADING ON POSTERIOR
figure; hold on; 

% Plot posteriors
plot(mGrid, P_D1_given_m, 'Color', orange, 'LineWidth', 1.5);
plot(mGrid, P_D0_given_m, 'Color', blue, 'LineWidth', 1.5);
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
set(gca, 'FontSize', 30);
box off;

%% Posteriors for different sigma test and ref values

% Change this variable to change sigmaTest values instead of sigmaRef
changeSigmaRef = true;

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
changeSigmaRef = false;

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
    dataDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, plotFolderName);
    filename = fullfile(dataDir, '/posterior_animation_sigmaRef.gif');
else
    dataDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, plotFolderName);
    filename = fullfile(dataDir, '/posterior_animation_SigmaTest.gif');
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

% Conceptual illustration: reference vs test likelihoods and their difference
sigmaRef = 0.5;       % standard deviation of measurement
sigmaTest = 0.75;
delta = 3;       % test stimulus difference

m = linspace(-5, 8, 1000);

% Reference likelihood (centered at 0)
P_ref = normpdf(m, 0, sigmaRef);

% Test likelihood (centered at delta)
P_test = normpdf(m, delta, sigmaTest);

% Difference distribution: test - ref
% Variance adds
P_diff = normpdf(m, delta, sqrt(sigmaTest^2 + sigmaRef^2));  % centered at 0 if diff = ref - test

% Plot
figure; hold on;

% Define colors
colRef  = orange;   
colTest = orange; 
colDiff = 'k'; % black

plot(m, P_ref, 'Color', colRef, 'LineWidth', 2, 'LineStyle', '-');
plot(m, P_test, 'Color', colTest, 'LineWidth', 2, 'LineStyle', '--');
plot(m, P_diff, 'Color', colDiff, 'LineWidth', 2,'LineStyle', '-.');

xlabel('Internal measurement value');
ylabel('Probability');
% title('Sensory Encoding: Individual Stimuli to Difference Signal');
% legend({'Reference Signal: p(m_{ref} | s_{1} = 0)', ...
%     'Test Signal: p(m_{test} | s_{2} = 3)', ...
%     'Difference Likelihood: p(m_{diff} | \theta = 3)' ...
%     }, 'Location', 'NorthEast');   % OLD legend with detail 
legend({'\it{m_{ref}}', ...
    '\it{m_{test}}', ...
    '\it{m}' ...
    }, 'Location', 'NorthEast'); 
xlim([-5 8]);
ylim([0 1]); % max([P_ref P_test P_diff])*1.2]);
set(gca,'FontSize',14); box off;

%% FOR POSTER: 
% Elementary plot of the likelihood as a difference of Gaussians

sigmaRef = 0.5;
sigmaTest = 0.75;
delta = 2;

m = linspace(-5, 8, 1000)';
dm = m(2) - m(1);

% Likelihoods for illustration
P_ref  = normpdf(m, 0, sigmaRef);
P_test = normpdf(m, delta, sigmaTest);
P_diff = normpdf(m, delta, sqrt(sigmaTest^2 + sigmaRef^2));

% Recompute Bayesian decision rule on THIS grid 
% Priors (reuse or redefine explicitly for clarity)
pSame = 0.4;
pDiff = 0.6;

% p(m | D = 0)
P_m_given_D0 = normpdf(m, 0, sqrt(2)*sigmaRef);

% theta prior (uniform, excluding 0)
thetaRange = linspace(-5,5,1000);
thetaRange(thetaRange==0) = [];
p_theta_given_D1 = ones(size(thetaRange)) / (max(thetaRange)-min(thetaRange));
dtheta = thetaRange(2) - thetaRange(1);

% p(m | D = 1)
likelihood = normpdf(m, thetaRange, sqrt(sigmaTest^2 + sigmaRef^2));
P_m_given_D1 = sum(likelihood .* p_theta_given_D1, 2) * dtheta;

% Posterior
P_D1_given_m = (P_m_given_D1 * pDiff) ./ ...
    (P_m_given_D0 * pSame + P_m_given_D1 * pDiff);

decisionDifferent = (P_D1_given_m > 0.5);

% Boundaries
idx = find(diff(decisionDifferent));
mB1 = m(idx(1));
mB2 = m(idx(2));

% Height of the "m" curve (difference likelihood)
yB1 = P_diff(idx(1));
yB2 = P_diff(idx(2));

% Stimulus-conditioned probability
P_m_given_delta = normpdf(m, delta, sqrt(sigmaRef^2 + sigmaTest^2));
P_m_given_delta = P_m_given_delta / sum(P_m_given_delta * dm);
pDifferent = sum(P_m_given_delta .* decisionDifferent) * dm;

% Plot
figure; hold on;

colRef  = [0.6 0.6 0.6];    
colTest = [0.6 0.6 0.6]; 
colDiff = 'k';

% Likelihoods
hRef = plot(m, P_ref,  'Color', colRef,  'LineWidth', 1.5, 'LineStyle', '-');
hTest = plot(m, P_test, 'Color', colTest, 'LineWidth', 1.5, 'LineStyle', '--');
hDiff = plot(m, P_diff, 'Color', colDiff, 'LineWidth', 2.5, 'LineStyle', '-.');

% Decision boundaries
hB = plot([mB1 mB1], [0 yB1], '--', 'Color', 'k', 'LineWidth', 1.5);
% plot([mB2 mB2], [0 yB2], '--', 'Color', 'k', 'LineWidth', 1.5);

% Mask for "different" region
P_diff = P_m_given_delta;
P_diff(~decisionDifferent) = 0;

% Mask for "same" region
P_same = P_m_given_delta;
P_same(decisionDifferent) = 0;

lightOrange = orange + (1 - orange)*0.3;
lightBlue = blue + (1 - blue)*0.3;

% Shade "different" (light orange)
hDiffArea = area(m, ...
     P_diff, ...
     'FaceColor', lightOrange, ...
     'FaceAlpha', 0.2, ...
     'EdgeColor', 'none');

hold on;

% Shade "same" (light blue)
hSameArea = area(m, ...
     P_same, ...
     'FaceColor', lightBlue, ...
     'FaceAlpha', 0.2, ...
     'EdgeColor', 'none');

xlabel('Internal measurement value');
ylabel('Probability');

legend([hRef, hTest, hDiff, hSameArea, hDiffArea], ...
    {'\it{m_{ref}}', ...
     '\it{m_{test}}', ...
     '\it{m}', ...
     'Respond "same"', ...
     'Respond "different"'}, ...
    'Location', 'NorthEast');

xlim([-5 8]);
ylim([0 1]);
set(gca,'FontSize',14); box off;

%% Elementary bar plot of the prior over trial types

% Data
priors = [0.4, 0.6];

figure;
b = bar(priors, 0.6);

% Colors
b.FaceColor = 'flat';
b.CData = [
    blue;
    orange
];
b.EdgeColor = 'none';

hold on;

% Dotted horizontal lines at prior values
for i = 1:length(priors)
    plot([0 i], [priors(i) priors(i)], '--', ...
        'Color', [0.1 0.1 0.1], ...
        'LineWidth', 1.5);
end

% Axis formatting
xticks([1 2]);
xticklabels({'Same (\itD\rm = 0)', 'Different (\itD\rm = 1)'});
ylabel('Probability');

ylim([0 1]);
xlim([0.3 2.7]);

% Emphasize 0.4 and 0.6 on y-axis
yticks([0 0.4 0.6 1]);

hold off;
set(gca,'FontSize',14); box off;

%% Psychometric curve + stimulus-specific integration highlight (delta = 1 dB)

% Stimulus range (psychometric function axis)
deltaRange = -5:0.05:5;

% Preallocate psychometric function
pDifferentCurve = zeros(size(deltaRange));

% Loop over stimulus differences
for ii = 1:length(deltaRange)

    delta = deltaRange(ii);

    % Measurement distribution for this stimulus
    P_m_given_delta = normpdf(mGrid, delta, sqrt(sigmaRef^2 + sigmaTest^2));
    P_m_given_delta = P_m_given_delta / sum(P_m_given_delta * dm);

    % Psychometric function: probability of responding "different"
    pDifferentCurve(ii) = sum(P_m_given_delta .* decisionDifferent) * dm;

end

% Find value at delta = 1 dB
deltaTarget = 1;
idxTarget = find(deltaRange == deltaTarget);
pAtTarget = pDifferentCurve(idxTarget);

% Plot psychometric curve
figure; hold on;

plot(deltaRange, pDifferentCurve, 'k-', 'LineWidth', 2);
% define color to match stim specific integration panel
orange = [0.9, 0.4, 0.1];
lightOrange = orange + (1 - orange)*0.3; 

% Highlight point at delta = 1
scatter(deltaRange(idxTarget), pAtTarget, 120, 'filled', ...
    'MarkerFaceColor', lightOrange, ...
    'MarkerFaceAlpha', 0.5, ...
    'MarkerEdgeColor', lightOrange);

% vertical fill at the chosen stimulus 
patch([deltaRange(idxTarget)-0.01 deltaRange(idxTarget)+0.01 deltaRange(idxTarget)+0.01 deltaRange(idxTarget)-0.01], ...
      [0 0 pAtTarget pAtTarget], ...
      lightOrange, ...
      'FaceAlpha', 0.5, ...
      'EdgeColor', 'none');

% reference line
yline(pAtTarget, '--', 'Color', [0.3 0.3 0.3]);

xlabel('stimulus difference [dB]');
ylabel('P(respond different)');
set(gca,'FontSize',14);
xlim([-5 5]);
ylim([0 1]);
yticks([0 0.2 0.4 0.6 0.8 1]);
set(gca, 'FontSize', 18);
box off;