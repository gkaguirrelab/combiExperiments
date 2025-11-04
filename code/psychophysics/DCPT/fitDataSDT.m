% Defining the directory
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
experimentName = 'DCPT_SDT';

% Define subjects + parameters
subjectID = {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', 'FLIC_0018', 'FLIC_0020', ...
    'FLIC_0021', 'FLIC_0022'};
modDirection = 'LightFlux';
NDLabel = {'3x0', '0x5'};   % Options are {'3x0', '0x5'}
stimParamLabels = {'low', 'hi'}; % {'low', 'hi'}
refFreqHz = 17.3205;  % logspace(log10(10),log10(30),5)
targetPhotoContrast = '0x3';  % {'0x1','0x3'}

% Initialize combined trial data
comboTrialData = [];

for subjIdx = 1:length(subjectID)
    subj = subjectID{subjIdx};

    for sideIdx = 1:length(stimParamLabels)

    % Build path to the data file
    subjectDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, subj);
    dataDir = fullfile(subjectDir, [modDirection '_ND' NDLabel{1} '_shifted'], experimentName);

    fileName = fullfile(dataDir, ...
        [subj '_' modDirection '_' experimentName ...
        '_cont-' targetPhotoContrast '_refFreq-' num2str(refFreqHz) 'Hz_' stimParamLabels{sideIdx} '.mat']);

    if exist(fileName, 'file')
        load(fileName, 'psychObj');

        thisTrialData = psychObj.questData.trialData;

        if contains(fileName, 'lo')
            for trial = 1:numel(thisTrialData)
                thisTrialData(trial).stim = -thisTrialData(trial).stim;
            end
        end

        % Append to combined trial data
        comboTrialData = [comboTrialData; thisTrialData];

        % Optional: store one psychObj as template if needed
        if subjIdx == 1
            templatePsychObj = psychObj;
        end
    else
        warning('File not found: %s', fileName);
    end

    end

end

% Assign template object to be the combinedPsychObj
combinedPsychObj = templatePsychObj;

% Grab variables
stimParamsDomainList = combinedPsychObj.stimParamsDomainList;
nTrials = length(comboTrialData);

% Set up a figure
figHandle = figure('visible',true);
figuresize(750,250,'units','pt');

% PLOTTING GROUP LEVEL DATA POINTS
% Get the proportion respond "different" for each stimulus
stimCounts = qpCounts(qpData(comboTrialData),combinedPsychObj.questData.nOutcomes);
stim = zeros(length(stimCounts),combinedPsychObj.questData.nStimParams);
for cc = 1:length(stimCounts)
    stim(cc) = stimCounts(cc).stim;
    nTrials(cc) = sum(stimCounts(cc).outcomeCounts);
    pRespondDifferent(cc) = stimCounts(cc).outcomeCounts(2)/nTrials(cc);
end

% Plot these. Use a different marker for the 0 dB case
markerSizeIdx = discretize(nTrials(2:end),3);
markerSizeIdx = [3 markerSizeIdx];
markerSizeSet = [25,50,100];
for cc = 1:length(stimCounts)
    if cc == 1
        scatter(stim(cc),pRespondDifferent(cc),markerSizeSet(markerSizeIdx(cc)),'diamond', ...
            'MarkerFaceColor',[pRespondDifferent(cc) 0 1-pRespondDifferent(cc)], ...
            'MarkerEdgeColor','k', ...
            'MarkerFaceAlpha',nTrials(cc)/max(nTrials));
    else
        scatter(stim(cc),pRespondDifferent(cc),markerSizeSet(markerSizeIdx(cc)),'o', ...
            'MarkerFaceColor',[pRespondDifferent(cc) 0 1-pRespondDifferent(cc)], ...
            'MarkerEdgeColor','k', ...
            'MarkerFaceAlpha',nTrials(cc)/max(nTrials));
    end
    hold on
end

% Labels and range
ylim([-0.1 1.1]);
xlabel('stimulus difference [dB]')
ylabel('proportion respond different')
title('Psychometric function');

% Load real data
dB_data = [comboTrialData.stim];          % vector of dB differences
response_data = [comboTrialData.respondYes]; % 0 = "Same", 1 = "Different"

% Set initial sigma and criterion baseline (the flat part of the criterion
% function)
% Best initial params for MLE are: sigma = .5, crit_baseline = 2.5, m =
% 1.4, and x_limit = 1
m = 1.4;
crit_baseline = 2.5;
sigma = .5;
x_limit = 1; % db value where the v starts dipping down

initial_params = [m, crit_baseline, sigma, x_limit]; % Initial params
dB_range = [sort(-linspace(0.1,5,30)) 0 linspace(0.1,5,30)];

lb = [0, 0, 0.3, 0]; % lower bounds for m, crit_baseline, x_limit, sigma
ub = [100, 100, 10, 2]; % upper bounds

% Options for fmincon
opts = optimoptions('fmincon','Display','iter','Algorithm','sqp', 'MaxIterations', 100);

% Options for bads
% Start with defaults
options = bads('defaults');
addpath(genpath('/Users/rubybouh/Documents/MATLAB/projects/bads'));
% Set max iterations and function evaluations
options.MaxIter = 50;     
options.MaxFunEvals = 500;  

% Run the fitting 100 times to see if it converges to the same solution
nRuns = 100; 
param_store = zeros(nRuns, 4);  % 4 parameters: [m, critBaseline, sigma, x_limit]

for runIdx = 1:nRuns
    % Fit
    best_BADS_params = bads(@(p) neg_log_likelihood(p, dB_data, response_data, x_limit), ...
        initial_params, lb, ub, lb, ub, [], options);

    % Store results
    param_store(runIdx, :) = best_BADS_params;
end

param_mean = mean(param_store, 1); % Takes the mean of each column
param_se = std(param_store) / sqrt(nRuns);  % standard error

param_names = {'m', 'critBaseline', 'sigma', 'x\_limit'};
figure;
hold on;

% Horizontal positions
x = 1:4;
errorbar(x, param_mean, param_se, 'o', 'LineWidth', 2, 'MarkerSize', 8);
set(gca, 'XTick', x, 'XTickLabel', param_names);
ylabel('Parameter value');
title('Mean ± SEM of fitted parameters over 100 runs');
grid on;
hold off;

% TEMPORARILY TAKING THIS OUT TO DO 100 RUNS

% Run MLE to minimize negative log likelihood
% best_MLE_params = fmincon(@(p) neg_log_likelihood(p, dB_data, response_data, x_limit), ...
%   initial_params, [], [], [], [], lb, ub, [], opts);

% Run BADS 
% addpath(genpath('/Users/rubybouh/Documents/MATLAB/projects/bads'));
% best_BADS_params = bads(@(p) neg_log_likelihood(p, dB_data, response_data, x_limit), ...
%     initial_params, lb, ub, lb, ub, options);
% 
% % Choose the fitting method
% fit = best_BADS_params;
% 
% disp(['Best fit: m = ', num2str(fit(1)), ', critBaseline = ', num2str(fit(2)), ...
%         ', sigma  = ', num2str(fit(3)), ', x limit = ', num2str(fit(4))]);
% 
% % Compute predicted probabilities using fitted parameters
% for i = 1:length(dB_range)
%     dB_val = dB_range(i);
%     c_val(i) = criterion(dB_val, fit(1), fit(2), fit(4));
%     predicted_P_diff(i) = compute_P_different(dB_val, fit(3), c_val(i));
% end
% 
% % Plot the fitted curve
% plot(dB_range, predicted_P_diff, 'k-', 'LineWidth', 2);
% legend({'Observed data', 'Fitted psychometric function'}, 'Location', 'Best');
% 
% % figure;
% plot(dB_range, c_val, 'ko', 'LineWidth', 2);

%--------------------------------------------------------------------------
% Local Functions
%--------------------------------------------------------------------------

function c = criterion(dB_value, m, crit_baseline, x_limit)
% Determining criterion values under the hypothesis that is
% shrinks for dB values closer to 0
if abs(dB_value) <= x_limit
    c = crit_baseline - m * (x_limit - abs(dB_value));
else
    c = crit_baseline;
end
end

function P_diff = compute_P_different(dB_value, sigma, c)

% Parameters
mu_R = 0;     % mean of reference
mu_T = dB_value;     % mean of test

% Function for the joint PDF f(mR, mT)
f = @(mR, mT) normpdf(mR, mu_R, sigma) .* normpdf(mT, mu_T, sigma);

% The integral limits are defined by the criterion: mR - c <= mT <= mR + c
mR_min = -inf;
mR_max = inf;

% Lower limit for mT: g(mR) = mR - c
g = @(mR) mR - c;

% Upper limit for mT: h(mR) = mR + c
h = @(mR) mR + c;

try
    P_same_integral2 = integral2(f, mR_min, mR_max, g, h);
catch
    P_same_integral2 = NaN;
end

P_diff = 1 - P_same_integral2;

end

function nll = neg_log_likelihood(params, dB_data, response_data, x_limit)
m = params(1);
crit_baseline = params(2);
sigma = params(3);
x_limit = params(4);

nll = 0;

if sigma <= 0
    nll = Inf;
    return;
end

for i = 1:length(dB_data)
    dB_value = dB_data(i);
    response = response_data(i);  % 1 = "Different", 0 = "Same"

    c = criterion(dB_value, m, crit_baseline, x_limit);
    P_diff = compute_P_different(dB_value, sigma, c);
    % Computes probability given parameter values

    % Clamp probabilities to avoid log(0)
    P_diff = max(min(P_diff, 1 - 1e-9), 1e-9);
    P_same = 1 - P_diff;

    % Add log likelihood for this trial
    if response == 1
        nll = nll - log(P_diff);
    else
        nll = nll - log(P_same);
    end
end
end



% LEAST SQUARES - decided not to do this
% best_lsq_params = fmincon(@(p) lsq_objective(p, stimLevels, obsPropDiff, x_limit), ...
%    initial_params, [], [], [], [], lb, ub, [], opts);

% function sse = lsq_objective(params, stimLevels, obsPropDiff, x_limit)
%     m = params(1);
%     crit_baseline = params(2);
%     sigma = params(3);
% 
%     predicted = zeros(size(stimLevels));
%     for i = 1:length(stimLevels)
%         c = criterion(stimLevels(i), m, crit_baseline, x_limit);
%         predicted(i) = compute_P_different(stimLevels(i), sigma, c);
%     end
% 
%     sse = sum((obsPropDiff - predicted).^2);
% end

% Group data by stimulus level for least squares regression
% stimLevels = unique(dB_data); % unique stimulus levels
% obsPropDiff = zeros(size(stimLevels)); % to store observed proportion "different"
% nTrialsPerLevel = zeros(size(stimLevels)); % to store number of trials per stim level
% for i = 1:length(stimLevels)
%     idx = dB_data == stimLevels(i); % indices of trials at this stimulus level
%     nTrialsPerLevel(i) = sum(idx);  % number of trials at this stim level
%     obsPropDiff(i) = mean(response_data(idx)); % observed proportion "different"
% end