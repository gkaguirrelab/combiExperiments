% Defining the directory
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
experimentName = 'DCPT_SDT';

% Define subjects + parameters
subjectID = {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', 'FLIC_0018', 'FLIC_0020', ...
    'FLIC_0021', 'FLIC_0022'};
modDirection = 'LightFlux';
NDLabel = '0x5';   % Options are {'3x0', '0x5'}
stimParamLabels = 'hi'; % {'low', 'hi'}
refFreqHz = 17.3205;  % logspace(log10(10),log10(30),5)
targetPhotoContrast = '0x3';  % {'0x1','0x3'}

% Initialize combined trial data
comboTrialData = [];

for subjIdx = 1:length(subjectID)
    subj = subjectID{subjIdx};

    % Build path to the data file
    subjectDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, subj);
    dataDir = fullfile(subjectDir, [modDirection '_ND' NDLabel '_shifted'], experimentName);

    fileName = fullfile(dataDir, ...
        [subj '_' modDirection '_' experimentName ...
        '_cont-' targetPhotoContrast '_refFreq-' num2str(refFreqHz) 'Hz_' stimParamLabels '.mat']);

    if exist(fileName, 'file')
        load(fileName, 'psychObj');
        thisTrialData = psychObj.questData.trialData;

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

% "FINAL WORKING CODE STRUCTURE"
% Load real data
dB_data = [comboTrialData.stim];          % vector of dB differences
response_data = [comboTrialData.respondYes]; % 0 = "Same", 1 = "Different"

% Group data by stimulus level for least squares regression
stimLevels = unique(dB_data); % unique stimulus levels
obsPropDiff = zeros(size(stimLevels)); % to store observed proportion "different"
nTrialsPerLevel = zeros(size(stimLevels)); % to store number of trials per stim level
for i = 1:length(stimLevels)
    idx = dB_data == stimLevels(i); % indices of trials at this stimulus level
    nTrialsPerLevel(i) = sum(idx);  % number of trials at this stim level
    obsPropDiff(i) = mean(response_data(idx)); % observed proportion "different"
end

% Set initial sigma and criterion baseline (the flat part of the criterion
% function)
% Best initial params for MLE
% sigma = .5;                  
% crit_baseline = 2.5; 
% m = 1.4; 
% x_limit = 1; 
sigma = .5;
crit_baseline = 2.5;
m = 1.4;
x_limit = 1; % db value where the v starts dipping down

initial_params = [m, crit_baseline, sigma, x_limit]; % Initial params
dB_range = [0 linspace(0.1,5,30)];

lb = [0, 0, 0.3]; % lower bounds for m, crit_baseline, x_limit, sigma
ub = [Inf, Inf, 10]; % upper bounds

opts = optimoptions('fmincon','Display','iter','Algorithm','sqp');

% Run MLE to minimize negative log likelihood
best_MLE_params = fmincon(@(p) neg_log_likelihood(p, dB_data, response_data, x_limit), ...
    initial_params, [], [], [], [], lb, ub, [], opts);

% Alternatively, use least squares fit
% best_lsq_params = fmincon(@(p) lsq_objective(p, stimLevels, obsPropDiff, x_limit), ...
%    initial_params, [], [], [], [], lb, ub, [], opts);

% Choose the fitting method
fit = best_MLE_params;

% disp(['Best fit: m = ', num2str(best_MLE_params(1)), ', critBaseline = ', num2str(best_MLE_params(2))]);
disp(['Best fit: m = ', num2str(fit(1)), ', critBaseline = ', num2str(fit(2))]);

% Compute predicted probabilities using fitted parameters
for i = 1:length(dB_range)
    dB_val = dB_range(i);
    %c_val(i) = criterion(dB_val, best_params(1), best_params(2), x_limit);
    c_val(i) = criterion(dB_val, fit(1), fit(2), x_limit);
    predicted_P_diff(i) = compute_P_different(dB_val, fit(3), c_val(i));
    %predicted_P_diff(i) = compute_P_different(dB_val, best_params(3), c_val(i));
end

% Plot the fitted curve
plot(dB_range, predicted_P_diff, 'k-', 'LineWidth', 2);
legend({'Observed data', 'Fitted psychometric function'}, 'Location', 'Best');

figure;
plot(dB_range, c_val, 'ko', 'LineWidth', 2);

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
x_limit = params(3);
sigma = params(3);

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

function sse = lsq_objective(params, stimLevels, obsPropDiff, x_limit)
    m = params(1);
    crit_baseline = params(2);
    sigma = params(3);
    
    predicted = zeros(size(stimLevels));
    for i = 1:length(stimLevels)
        c = criterion(stimLevels(i), m, crit_baseline, x_limit);
        predicted(i) = compute_P_different(stimLevels(i), sigma, c);
    end
    
    sse = sum((obsPropDiff - predicted).^2);
end
