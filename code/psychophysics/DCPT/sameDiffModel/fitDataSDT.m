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
uniqueDbValues = unique(dB_data);
% Calculate observed proportion “different” per stim level
for ii = 1:length(uniqueDbValues)
    probData(ii) = mean(response_data(dB_data==uniqueDbValues(ii)));
    nTrials(ii) = sum(dB_data == uniqueDbValues(ii)); % nTrials at each dB
end

% Set initial sigma and criterion baseline (the flat part of the criterion
% function)
% Best initial params for MLE are: sigma = .5, crit_baseline = 2.5, m =
% 1.4, and x_limit = 1
% Best initial params for Euclidean error are: sigma = .3, crit_baseline = 2, m =
% 1.45, and x_limit = 1
m = 1.45;
crit_baseline = 2;
sigma = .3;
x_limit = 1; % db value whehre the v starts dipping down

% Params for flat-bottom solution
% m = 2.5;
% crit_baseline = 2.5;
% sigma = .5;
% x_limit = 1;

initial_params = [m, crit_baseline, sigma, x_limit]; % Initial params

% Options for bads
% Start with defaults
options = bads('defaults');
addpath(genpath('/Users/rubybouh/Documents/MATLAB/projects/bads'));
% Set max iterations and function evaluations
options.MaxIter = 50;
options.MaxFunEvals = 500;
% Bounds
lb = [0, 0, 0.3, 0]; % lower bounds for m, crit_baseline, x_limit, sigma
ub = [100, 100, 10, 3]; % upper bounds

% Fit
best_BADS_params = bads(@(p) euclideanError(p, uniqueDbValues, probData, nTrials), ...
   initial_params, lb, ub, lb, ub, [], options);
fit = best_BADS_params;
% fit = initial_params; 

disp(['Best fit: m = ', num2str(fit(1)), ', critBaseline = ', num2str(fit(2)), ...
    ', sigma  = ', num2str(fit(3)), ', x limit = ', num2str(fit(4))]);

% Compute predicted probabilities using fitted parameters
pDifferent = modifiedSameDiffModel( uniqueDbValues, fit );

% Plot the fitted curve (on top of group level data points)
plot(uniqueDbValues, pDifferent, 'k-', 'LineWidth', 2);
legend({'Observed data', 'Fitted psychometric function'}, 'Location', 'Best');

%%% Objective functions %%%

function error = euclideanError(params, uniqueDbValues, probData, nTrials)
    
    % Predict probability of "different" at each unique dB level
    P_diff = modifiedSameDiffModel(uniqueDbValues, params);
    P_diff = max(min(P_diff, 1 - 1e-9), 1e-9); % To make sure 0 < P_diff < 1

    % Create weights and artifically boost weights close to 0 dB
    boostIdx = abs(uniqueDbValues) > 0 & abs(uniqueDbValues) < 1;
    nTrials(boostIdx) = 1 * nTrials(boostIdx);
    w = nTrials / sum(nTrials); % Normalization

    % Compute error as the norm of the vector of the differences between the observed and
    % modeled proportion "different" responses
    diffVec = probData - P_diff;  
    weightedDiffVec = w .* diffVec;  % Weighted diffs

    error = norm(weightedDiffVec); 

end

function nll = negLogLikelihood(params, uniqueDbValues, probData)

    % Predict probability of "different" at each unique dB level
    P_diff = modifiedSameDiffModel(uniqueDbValues, params);
    P_diff = max(min(P_diff, 1 - 1e-9), 1e-9); % To make sure 0 < P_diff < 1
    P_same = 1 - P_diff;
    
    nll = 0;
    for ii = 1:length(uniqueDbValues)
        probData(ii) = mean(response_data(dB_data==uniqueDbValues(ii))); 
        nll = -sum(probData .* log(P_diff) + (1 - probData) .* log(P_same));
    end

end
