% This code is sigma parameter recovery analysis.
% Vary one sigma (0.2–2) while fixing the other at 0.5. 
% Choose the subject and condition in this section of the code.
% Simulate + refit 100 using one subject’s real dB sequence.
% Plot input vs recovered sigma with unity line.
% Repeat for both sigma_ref and sigma_test.

% SETUP - defining and setting variables
% Defining the directory
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
experimentName = 'DCPT_SDT';

% Define subjects + parameters
% Control subject IDs: {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', ...
% 'FLIC_0018', 'FLIC_0019','FLIC_0020', 'FLIC_0021', 'FLIC_0022', 'FLIC_0027',
% 'FLIC_0028','FLIC_0039', 'FLIC_0042', 'FLIC_0049', 'FLIC_0050', 'FLIC_0051'}; 
% Migraine subject IDs: {'FLIC_1016','FLIC_1029','FLIC_1030','FLIC_1031','FLIC_1032', ...
% 'FLIC_1034','FLIC_1035','FLIC_1036','FLIC_1038', 'FLIC_1041', 'FLIC_1043',...
% 'FLIC_1044', 'FLIC_1046', 'FLIC_1047', 'FLIC_1048'};
subjectID = {'FLIC_0020'};
modDirection = 'LightFlux';
NDLabel = {'3x0', '0x5'};   % {'3x0', '0x5'}
stimParamLabels = {'low', 'hi'}; % {'low', 'hi'}
refFreqHz = logspace(log10(10),log10(30),5);  % logspace(log10(10),log10(30),5)
targetPhotoContrast = {'0x1','0x3'};  % {'0x1','0x3'}
contrastLabels = {'LoContrast', 'HiContrast'};
lightLabels = {'LoLight', 'HiLight'};

% Define length variables
nFreqs = length(refFreqHz);
nContrasts = length(targetPhotoContrast);
nLightLevels = length(NDLabel); 
nSubj = length(subjectID);

% Choose the subject and condition
subjIdx      = 1;   % choose subject index
contrastIdx  = 2;   % 1 = low, 2 = high 
lightIdx     = 2;   % 1 = low, 2 = high 
refFreqIdx   = 3;   % list is: 10.0000   13.1607   17.3205   22.7951   30.0000

thisSubj = subjectID{subjIdx};
currentRefFreq = refFreqHz(refFreqIdx);

% Choose whether you want to save the recovery parameter data in a .mat file
saveData = true; 

%% Simulation using simulate function for one subj, one condition. Plot simulated data.
% Repeat simulating and fitting data 100 times

% Load the subject's data file and extract the real stimulus presentation sequence
subjectDir = fullfile(dropBoxBaseDir, dropBoxSubDir, ...
                      projectName, thisSubj);
dataDir = fullfile(subjectDir, ...
    [modDirection '_ND' NDLabel{lightIdx} '_shifted'], ...
    experimentName);

% Load high/low side files and combine
comboTrialData = [];
domainExtracted = false;
for sideIdx = 1:length(stimParamLabels)

    fileName = fullfile(dataDir, ...
        [thisSubj '_' modDirection '_' experimentName ...
        '_cont-' targetPhotoContrast{contrastIdx} ...
        '_refFreq-' num2str(currentRefFreq) 'Hz_' ...
        stimParamLabels{sideIdx} '.mat']);

    if exist(fileName, 'file')

        load(fileName, 'psychObj');
        thisTrialData = psychObj.questData.trialData;

        % Flip sign for low side
        if contains(stimParamLabels{sideIdx}, 'lo')
            for trial = 1:numel(thisTrialData)
                thisTrialData(trial).stim = -thisTrialData(trial).stim;
            end
        end

        comboTrialData = [comboTrialData; thisTrialData];

        if ~domainExtracted
            stimParamsDomainList = ...
                psychObj.questData.stimParamsDomainList;
            stimParamsDomainList = stimParamsDomainList{:}';
            domainExtracted = true;
        end
    end
end

% Extract dB sequence
dBData = [comboTrialData.stim];

% stimParamsDomainList extracted from a psychObj above, only positive vals
% Add negative vals to the list while preserving step size
stimParamsDomainListSym = unique([-stimParamsDomainList, stimParamsDomainList]);
stimParamsDomainListSym = sort(stimParamsDomainListSym); % make ascending

% Choose the model parmaeters
priorSame = 0.5;

chosenSigmaTestFixed = 0.5;
chosenSigmaRefFixed = 0.5;

sigmaRefSweep = linspace(0.2, 2, 8); % define both sweeps
sigmaTestSweep = linspace(0.2, 2, 8);

nRepeats = 100; % set to desired number of repeats

for recoveryMode = 1:2 % varying sigma ref or test

    if recoveryMode == 1
        % CASE 1: Fix sigma test, vary sigma ref
        sweepList = sigmaRefSweep;
        nSweep = length(sweepList);

        % Sweep 1 storage
        recoveredTest_fromRefSweep = zeros(nSweep, nRepeats);
        recoveredRef_fromRefSweep  = zeros(nSweep, nRepeats);

        fprintf('Running recovery: FIX sigmaTest, VARY sigmaRef\n');

    else
        % CASE 2: Fix sigma ref, vary sigma test
        sweepList = sigmaTestSweep;
        nSweep = length(sweepList);

        % Sweep 2 storage
        recoveredTest_fromTestSweep = zeros(nSweep, nRepeats);
        recoveredRef_fromTestSweep  = zeros(nSweep, nRepeats);

        fprintf('Running recovery: FIX sigmaRef, VARY sigmaTest\n');
    end

    for ss = 1:nSweep

        if recoveryMode == 1 % vary sigma ref
            chosenSigmaTest = chosenSigmaTestFixed;
            chosenSigmaRef  = sweepList(ss);
        else   % vary sigma test
            chosenSigmaTest = sweepList(ss);
            chosenSigmaRef  = chosenSigmaRefFixed;
        end

        for rr = 1:nRepeats

            sigmaParams = [chosenSigmaTest chosenSigmaRef];

            % Run trial-level simulation
            simData = simulateSameDiffData( ...
                stimParamsDomainListSym, ...
                dBData, ...
                sigmaParams, ...
                priorSame);

            % Extract and process simulated data
            simStim = [simData.stim];
            simResp = [simData.respondYes];

            uniqueStim = unique(simStim);
            pRespondDifferent = zeros(size(uniqueStim));
            nTrialsPlot = zeros(size(uniqueStim));

            for ii = 1:length(uniqueStim)
                idx = simStim == uniqueStim(ii);
                nTrialsPlot(ii) = sum(idx);
                pRespondDifferent(ii) = mean(simResp(idx));
            end

            % Fit the model to this condition
            initialParams = [0.5, 0.5];
            lb = [0.001, 0.001];
            ub = [5, 5];

            options = bads('defaults');
            options.MaxIter = 50;
            options.MaxFunEvals = 500;

            [fit, fbest] = bads(@(p) negLogLikelihood( ...
                p, stimParamsDomainListSym, ...
                uniqueStim, ...
                pRespondDifferent, ...
                nTrialsPlot), ...
                initialParams, lb, ub, lb, ub, [], options);

            % Store recovered sigma parameters
            if recoveryMode == 1
                recoveredTest_fromRefSweep(ss, rr) = fit(1);
                recoveredRef_fromRefSweep(ss, rr)  = fit(2);

            elseif recoveryMode == 2
                recoveredTest_fromTestSweep(ss, rr) = fit(1);
                recoveredRef_fromTestSweep(ss, rr)  = fit(2);
            end

            % Plot the simulated data + fit for the first repeat + 3rd sigma val only
            if rr == 1 && ss == 3 && recoveryMode == 1
                figure; hold on;

                % Marker size based on trial counts
                markerSizeIdx = discretize(nTrialsPlot, 3);   % 3 size bins
                markerSizeSet = [25, 60, 120];                % small, medium, large

                for cc = 1:length(uniqueStim)

                    % Diamond for zero, circle otherwise
                    if uniqueStim(cc) == 0
                        markerShape = 'd';
                    else
                        markerShape = 'o';
                    end

                    scatter(uniqueStim(cc), ...
                        pRespondDifferent(cc), ...
                        markerSizeSet(markerSizeIdx(cc)), ...
                        'MarkerFaceColor', [pRespondDifferent(cc) 0 1-pRespondDifferent(cc)], ...
                        'MarkerEdgeColor', 'k', ...
                        'MarkerFaceAlpha', nTrialsPlot(cc)/max(nTrialsPlot), ...
                        'Marker', markerShape);
                end

                % Plot model fit
                x = -6:0.1:6;
                plot(x, bayesianSameDiffModelTwoSigma( ...
                    stimParamsDomainListSym, x, fit, priorSame), ...
                    'k-', 'LineWidth', 2);

                xlabel('stimulus difference [dB]');
                ylabel('p("different")');
                title(sprintf('%s | Contrast %d | Light %d | RefFreq %.1f Hz', ...
                    thisSubj, contrastIdx, lightIdx, refFreqHz(refFreqIdx)), 'Interpreter','none');

                ylim([-0.05 1.05]);
                xlim([-6 6]);
            end

        end

    end

end

if saveData

    % Build save directory
    saveSubDir = 'FLIC_analysis/dichopticFlicker/';
    saveDir = fullfile(dropBoxBaseDir, saveSubDir,'sigmaData');

    if ~exist(saveDir, 'dir') % Create directory if it doesn't exist
        mkdir(saveDir);
    end

    % Construct filename
    filename = fullfile(saveDir, ...
        sprintf('%s_%dHz_%s_%s_sigmaRecovery.mat', ...
            thisSubj, ...
            round(currentRefFreq), ...
            contrastLabels{contrastIdx}, ...
            lightLabels{lightIdx}));

    save(filename, 'recoveredRef_fromRefSweep','recoveredTest_fromRefSweep',...
        'recoveredTest_fromTestSweep','recoveredRef_fromTestSweep',...
        'sigmaRefSweep','sigmaTestSweep','chosenSigmaTestFixed','chosenSigmaRefFixed');

end

%% Parameter recovery plots

% Plot the input sigma REF value vs recovered sigma
% Average across simulating + fitting repetitions
meanRecoveredRef = mean(recoveredRef_fromRefSweep, 2);             % mean across repeats
stdRecoveredRef  = std(recoveredRef_fromRefSweep, 0, 2);           % std across repeats
meanRecoveredTest_fromRefSweep = mean(recoveredTest_fromRefSweep, 2); % mean across repeats for TEST
% semRecoveredRef  = stdRecoveredRef ./ sqrt(nRepeats);      % SEM

% Sigma ref parameter recovery plot
figure; hold on;

errorbar(sigmaRefSweep, ...
         meanRecoveredRef, ...
         stdRecoveredRef, ...
         'o-', ...
         'LineWidth', 2, ...
         'MarkerSize', 8, ...
         'MarkerFaceColor', 'w');

% Adding the recovered test values
plot(sigmaRefSweep, ...
     meanRecoveredTest_fromRefSweep, ...
     'o-', ...
     'Color',[0.5 0.5 0.5], ...
     'LineWidth', 2);

% Unity line
plot([0 2.5], [0 2.5], 'k--', 'LineWidth', 2);

xlabel('Input \sigma_{ref}');
ylabel('Recovered \sigma_{ref}');
title('Sigma Ref Recovery (mean ± SD)');

legend({'Recovered \sigma_{ref} (± SD)', ...
        'Recovered \sigma_{test} (mean)', ...
        'Unity line'}, ...
       'Location', 'northwest');

xlim([0 2.5]);
ylim([0 2.5]);

% Plot the input sigma TEST value vs recovered sigma
% Average across simulating + fitting repetitions
meanRecoveredTest = mean(recoveredTest_fromTestSweep, 2);             % mean across repeats
stdRecoveredTest  = std(recoveredTest_fromTestSweep, 0, 2);           % std across repeats
meanRecoveredRef_fromTestSweep = mean(recoveredRef_fromTestSweep, 2); % mean across repeats for REF
% semRecoveredTest = stdRecoveredTest ./ sqrt(nRepeats);      % SEM

% Sigma ref parameter recovery plot
figure; hold on;

errorbar(sigmaTestSweep, ...
         meanRecoveredTest, ...
         stdRecoveredTest, ...
         'o-', ...
         'LineWidth', 2, ...
         'MarkerSize', 8, ...
         'MarkerFaceColor', 'w');

% Adding the recovered ref values
plot(sigmaTestSweep, ...
     meanRecoveredRef_fromTestSweep, ...
     'o-', ...
     'Color',[0.5 0.5 0.5], ...
     'LineWidth', 2);

% Unity line
plot([0 2.5], [0 2.5], 'k--', 'LineWidth', 2);

xlabel('Input \sigma_{test}');
ylabel('Recovered \sigma_{test}');
title('Sigma Test Recovery (mean ± SD)');

legend({'Recovered \sigma_{test} (± SD)', ...
        'Recovered \sigma_{ref} (mean)', ...
        'Unity line'}, ...
       'Location', 'northwest');

xlim([0 2.5]);
ylim([0 2.5]);

%% Function for trial-level simulation %%

function simTrialData = simulateSameDiffData( ...
        stimParamsDomainList, dBData, ...
        sigmaParams, priorSame)

sigma = sigmaParams(1);
sigmaZero = sigmaParams(2);

% Priors
pSame = priorSame;
pDiff = 1 - priorSame;

% Theta grid
thetaRange = linspace(min(stimParamsDomainList), ...
                      max(stimParamsDomainList), 1000);
thetaRange(thetaRange==0) = [];

priorTheta = ones(size(thetaRange)) / ...
             (thetaRange(end) - thetaRange(1));

% Measurement grid for numerical integration
mGrid = linspace(min(stimParamsDomainList), ...
                 max(stimParamsDomainList), 1000)';
dm = mGrid(2)-mGrid(1);

% Likelihoods
P_m_given_D0 = normpdf(mGrid,0,sqrt(2)*sigmaZero);

dtheta = thetaRange(2)-thetaRange(1);
likelihood = normpdf(mGrid, thetaRange, ...
                     sqrt(sigma^2 + sigmaZero^2));
P_m_given_D1 = sum(likelihood .* priorTheta,2)*dtheta;

% Posterior
P_D1_given_m = (P_m_given_D1 * pDiff) ./ ...
    (P_m_given_D0 * pSame + P_m_given_D1 * pDiff);

decisionDifferent = (P_D1_given_m > 0.5);

% TRIAL SIMULATION
for ii = 1:length(dBData)

    delta = dBData(ii);

    % Sample internal measurement
    % From likelihood of measurement fn given this stim diff
    m = normrnd(delta, sqrt(sigma^2 + sigmaZero^2));

    % Apply decision rule
    % find the nearest value in mGrid to the sampled m
    [~, idx] = min(abs(mGrid - m));
    % Get decisionDifferent at that point
    decision = decisionDifferent(idx);

    % Store trial
    simTrialData(ii).stim = delta;
    simTrialData(ii).respondYes = decision;
end

end

%% Objective function for fitting %%%

function nll = negLogLikelihood(p, stimParamsDomainList, uniqueDbValues, probData, nTrials)
    sigma = p; % unpack fitted parameters

    % Predict probability of "different" at each unique dB level
    priorSame = 0.5; 
    P_diff = bayesianSameDiffModelTwoSigma(stimParamsDomainList, uniqueDbValues, sigma, priorSame);
    P_diff = max(min(P_diff, 1 - 1e-9), 1e-9); % To make sure 0 < P_diff < 1

    % Finding the count of different responses (aka the number of
    % "successes")
    k = probData .* nTrials; % prop observed diff multiplied by total number of trials at that dB
    
    % Finding the binomial negative log-likelihood
    nll = -sum(k .* log(P_diff) + (nTrials - k) .* log(1 - P_diff));

end

