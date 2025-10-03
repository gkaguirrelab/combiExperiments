%% PLOTTING JOINT PROBABILITY DENSITY
% Parameters
mu_L = 0;     % mean of left stimulus
mu_R = 1;     % mean of right stimulus
sigma = 1;    % standard deviation of both likelihoods
c = 1;        % decision threshold

% Create grid
x = linspace(-5, 5, 300);
y = linspace(-5, 5, 300);
[mL, mR] = meshgrid(x, y);

% Compute the likelihoods
p_mL = normpdf(mL, mu_L, sigma); % Evaluate PDF at each mL
p_mR = normpdf(mR, mu_R, sigma); % Evaluate PDF at each mR

% Compute the joint probability density
jointProb = p_mL .* p_mR;

% Plot the 2D surface
figure(1);
surf(mL, mR, jointProb, 'EdgeColor', 'none');
xlabel('m_L');
ylabel('m_R');
zlabel('p(m_L | f_L) * p(m_R | f_R)');
colorbar;

% Overlay the decision boundary (|mR - mL| < c) for the "same" region
hold on;
% Mask for "same" region
same_region = abs(mR - mL) < c;
% 2D pairs correspond to points on XY plane, the joint probability values
% (the heights) make a 3D surface

% Plot the same region as a transparent surface
h = surf(mL, mR, double(same_region) .* max(jointProb(:)), 'EdgeColor', 'none');
set(h, 'FaceAlpha', 0.3);

%% SIMULATING THE SAME-DIFFERENT TASK
close all; clear all

nTrials = 5000;              
dB_values = [0 linspace(0.1,5,30)]; 
sigma = 1;                  
criterion = 2; % a higher criterion is more conservative in saying different         

pDifferent = zeros(size(dB_values));  

for i = 1:length(dB_values)
    delta = dB_values(i);  % Signal difference (dB)

    % Create noise and signal+noise distributions
    noiseDist = makedist('Normal', 'mu', 0, 'sigma', sigma);
    signalDist = makedist('Normal', 'mu', delta, 'sigma', sigma);

    % Visualize the distributions for the nth dB value
    if i == 1
        x = linspace(-5, 15, 500); % Internal measurement values (Hz)
        figure(3);
        plot(x, pdf(noiseDist, x), 'b-', 'LineWidth', 2); hold on;
        plot(x, pdf(signalDist, x), 'r-', 'LineWidth', 2);
        legend('Noise', 'Signal+Noise');
        xlabel('Internal Measurement Value');
        ylabel('Probability Density');
    end

    % Sample from the distributions
    % Draws a column vector with nTrials rows and 1 column
    mL_same = random(noiseDist, nTrials, 1);  % both sampled from noiseDist
    mR_same = random(noiseDist, nTrials, 1);

    mL_diff = random(noiseDist, nTrials, 1);      % different: left stimulus = noise
    mR_diff = random(signalDist, nTrials, 1);     % different: right = signal+noise

    % Decision rule: if abs(mL - mR) >= criterion, they are "different"
    % Identifying SAME trials where they choose different 
    same_decisions = abs(mL_same - mR_same) >= criterion;
    
    % Identifying DIFF trials where they choose different
    diff_decisions = abs(mL_diff - mR_diff) >= criterion;
    
    % Total trials: half same, half different
    total_decisions = [same_decisions; diff_decisions];
    
    % Proportion of trials judged as "different"
    pDifferent(i) = sum(total_decisions)/length(total_decisions);
end

figure(4);
plot(dB_values, pDifferent, 'o-', 'LineWidth', 2);
xlabel('dB Difference');
ylabel('P(Different Response)');
title('Psychometric Curve for Same/Different Task');
grid on;
