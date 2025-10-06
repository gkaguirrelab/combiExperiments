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

nTrials = 5000;              
dB_values = [linspace(-5,-0.1,30) 0 linspace(0.1,5,30)]; 
sigma = 1;                  
criterion = 2; % a higher criterion is more conservative in saying different         
dipCriterion = true;

pDifferent = zeros(size(dB_values));  

for i = 1:length(dB_values)
    delta = dB_values(i);  % Signal difference (dB)

    if dipCriterion
        % Determining criterion values under the hypothesis that is
        % shrinks for dB values closer to 0
        if abs(delta) <= 1
            m = 0.40;
            b = 2 - m;
            criterion = sign(delta)*m*delta + b;
        end

        if delta > 1
            criterion = 2;
        end
    end

    criterion_List(i) = criterion;
    if i == length(dB_values)
        figure(3)
        plot(dB_values, criterion_List,'o')
        ylim([0,3]);
    end

    % Create noise and signal+noise distributions
    noiseDist = makedist('Normal', 'mu', 0, 'sigma', sigma);
    signalDist = makedist('Normal', 'mu', delta, 'sigma', sigma);

    % Visualize the distributions for the nth dB value
    if i == 1
        x = linspace(-15, 15, 500); % Internal measurement values (Hz)
        figure(4);
        plot(x, pdf(noiseDist, x), 'b-', 'LineWidth', 2); hold on;
        plot(x, pdf(signalDist, x), 'r-', 'LineWidth', 2);
        legend('Reference', 'Test');
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

figure(5);
plot(dB_values, pDifferent, 'o-', 'LineWidth', 2);
xlabel('dB Difference');
ylabel('P(Different Response)');
title('Psychometric Curve for Same/Different Task');
grid on;

%% %% SIMULATING PSYCHOMETRIC CURVE W/ INTEGRATING JOINT PROBABILITY DENSITY

nTrials = 5000;              
dB_values = [linspace(-5,-0.1,30) 0 linspace(0.1,5,30)]; 
sigma = 1;                  
c = 2; % a higher criterion is more conservative in saying different   
dipCriterion = true;


for i = 1:length(dB_values)

    % Parameters
    mu_R = 0;     % mean of reference
    mu_T = dB_values(i);     % mean of test

    if dipCriterion
        if abs(mu_T) <= 1
            m = 0.40;
            b = 2 - m;
            c = sign(mu_T)*m*mu_T + b;
        end

        if mu_T > 1
            c = 2;
        end
    end

    % Function for the joint PDF f(mR, mT)
    f = @(mR, mT) normpdf(mR, mu_R, sigma) .* normpdf(mT, mu_T, sigma);

    % The integral limits are defined by the criterion: mR - c <= mT <= mR + c
    
    mR_min = -inf;
    mR_max = inf;
    
    % Lower limit for mT: g(mR) = mR - c
    g = @(mR) mR - c; 
    
    % Upper limit for mT: h(mR) = mR + c
    h = @(mR) mR + c;
    
    P_same_integral2 = integral2(f, mR_min, mR_max, g, h);
    
    P_same(i) = P_same_integral2;
    P_different(i) = 1 - P_same(i); 

end
figure(6);
hold on
plot(dB_values, P_different, 'go-', 'LineWidth', 2);
xlabel('dB Difference');
ylabel('P(Different Response)');
title('Psychometric Curve for Same/Different Task');
grid on;