% SETUP - defining variables
% Defining the directory
% dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
% dropBoxSubDir = 'FLIC_data';
% projectName = 'combiLED';
% experimentName = 'DCPT_SDT';

dropBoxBaseDir = '/Users';
dropBoxSubDir = '/rubybouh';
projectName = '/Documents';
experimentName = 'DCPT_SDT';

% Define subjects + parameters
% Control subject IDs: {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', ...
% 'FLIC_0018', 'FLIC_0019','FLIC_0020', 'FLIC_0021', 'FLIC_0022', 'FLIC_0027', 
% 'FLIC_0028','FLIC_0039', 'FLIC_0042', 'FLIC_0049','FLIC_0051'}; 
% Migraine subject IDs: {'FLIC_1016','FLIC_1029','FLIC_1030','FLIC_1031','FLIC_1032', ...
%         'FLIC_1034','FLIC_1035','FLIC_1036','FLIC_1038', 'FLIC_1041', 'FLIC_1044', 'FLIC_1046'};
subjectID = {'FLIC_1031'};
modDirection = 'LightFlux';
NDLabel = {'3x0', '0x5'};   % {'3x0', '0x5'}
stimParamLabels = {'low', 'hi'}; % {'low', 'hi'}
refFreqHz = logspace(log10(10),log10(30),5);  % logspace(log10(10),log10(30),5)
targetPhotoContrast = {'0x1','0x3'};  % {'0x1','0x3'}

% Define length variables
nFreqs = length(refFreqHz);
nContrasts = length(targetPhotoContrast);
nLightLevels = length(NDLabel); 
nSubj = length(subjectID);

%% Extract stimDiffDb list per condition from actual participants

% Preallocate cell array
stimDiffDbList = cell(nSubj, nContrasts, nLightLevels, nFreqs);
domainExtracted = false; 

for subjIdx = 1:nSubj
    thisSubj = subjectID{subjIdx};

    for lightIdx = 1:nLightLevels
        for refFreqIdx = 1:nFreqs
            currentRefFreq = refFreqHz(refFreqIdx);

            for contrastIdx = 1:nContrasts

                comboTrialData = [];

                for sideIdx = 1:length(stimParamLabels)

                    subjectDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, thisSubj);
                    dataDir = fullfile(subjectDir, ...
                        [modDirection '_ND' NDLabel{lightIdx} '_shifted'], ...
                        experimentName);

                    fileName = fullfile(dataDir, ...
                        [thisSubj '_' modDirection '_' experimentName ...
                        '_cont-' targetPhotoContrast{contrastIdx} ...
                        '_refFreq-' num2str(currentRefFreq) 'Hz_' ...
                        stimParamLabels{sideIdx} '.mat']);

                    if exist(fileName, 'file')
                        load(fileName, 'psychObj');
                        thisTrialData = psychObj.questData.trialData;

                        % Flip sign for low side
                        if contains(fileName, 'lo')
                            for trial = 1:numel(thisTrialData)
                                thisTrialData(trial).stim = -thisTrialData(trial).stim;
                            end
                        end

                        comboTrialData = [comboTrialData; thisTrialData];

                        if ~domainExtracted
                            stimParamsDomainList = ...
                                psychObj.questData.stimParamsDomainList;
                            stimParamsDomainList = stimParamsDomainList{:}'; % flatten
                            domainExtracted = true;
                        end

                    end
                end

                % Extract stimulus values for this condition
                if ~isempty(comboTrialData)
                    dB_data = [comboTrialData.stim];
                    uniqueStim = unique(dB_data);
                    trialCounts = zeros(size(uniqueStim));

                    for ii = 1:length(uniqueStim)
                        trialCounts(ii) = sum(dB_data == uniqueStim(ii));
                    end
                
                    stimDiffDbList{subjIdx, contrastIdx, lightIdx, refFreqIdx} = uniqueStim;
                    trialCountList{subjIdx, contrastIdx, lightIdx, refFreqIdx} = trialCounts;
                else
                    stimDiffDbList{subjIdx, contrastIdx, lightIdx, refFreqIdx} = [];
                end

            end
        end
    end
end

%% Trial-level simulation using function and plot simulated data 

chosenSigma = 0.5;
chosenSigmaZero = 0.4;
chosenSigmaVals = [chosenSigma chosenSigmaZero];
priorSame = 0.5;
nTrialsPerStim = trialCounts(ii);

% stimParamsDomainList extracted from a psychObj above, only positive vals
% Add negative vals to the list while preserving step size
stimParamsDomainListSym = unique([-stimParamsDomainList, stimParamsDomainList]);
stimParamsDomainListSym = sort(stimParamsDomainListSym); % make ascending

% Preallocate cell array to store simulated data for all subjects
simDataAllSubjects = cell(nSubj, nContrasts, nLightLevels, nFreqs);

for subjIdx = 1:nSubj
    thisSubj = subjectID{subjIdx};

    % Create figure layouts for low and high contrast
    figLow = figure;
    tLowContrast = tiledlayout(figLow, nLightLevels, nFreqs, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tLowContrast, ['Low contrast simulated psychometric functions for ' thisSubj], 'FontWeight', 'bold', ...
        'Interpreter', 'none');
    figuresize(1000, 300, 'units', 'pt');

    figHigh = figure;
    tHighContrast = tiledlayout(figHigh, nLightLevels, nFreqs, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tHighContrast, ['High contrast simulated psychometric functions for ' thisSubj], 'FontWeight', 'bold', ...
        'Interpreter', 'none');
    figuresize(1000, 300, 'units', 'pt');

    for contrastIdx = 1:nContrasts
        for lightIdx = 1:nLightLevels
            for refFreqIdx = 1:nFreqs

                stimDiffDb = stimDiffDbList{subjIdx, contrastIdx, lightIdx, refFreqIdx};

                if isempty(stimDiffDb)
                    continue; % skip this combination
                end

                % Simulate trials for this subject + condition
                simData = simulateSameDiffData( ...
                    stimParamsDomainListSym, ...
                    stimDiffDb, ...
                    chosenSigmaVals, ...
                    priorSame, ...
                    nTrialsPerStim);

                % Store simulated data
                simDataAllSubjects{subjIdx, contrastIdx, lightIdx, refFreqIdx} = simData;

                % Extract data for fitting and plotting
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

                % Fit model parameters to simulated data
                % Initial guess and bounds for fitting
                initialParams = [0.5, 0.5]; % sigma values
                lb = [0.001, 0.001];
                ub = [3, 3];

                options = bads('defaults');
                options.MaxIter = 50;
                options.MaxFunEvals = 500;

                % Run the fit
                [fit, fbest] = bads(@(p) negLogLikelihood(p,stimParamsDomainListSym,uniqueStim,pRespondDifferent,nTrialsPlot), ...
                    initialParams, lb, ub, lb, ub, [], options);

                fitSigma(subjIdx, contrastIdx, lightIdx, refFreqIdx) = fit(1);
                fitSigmaZero(subjIdx, contrastIdx, lightIdx, refFreqIdx) = fit(2);
                fValMatrix(subjIdx, contrastIdx, lightIdx, refFreqIdx) = fbest;

                % Plot simulated data
                % Marker sizes
                markerSizeIdx = discretize(nTrialsPlot, 3); % 3 bins
                markerSizeSet = [25, 50, 100];

                if ~isempty(stimDiffDb)
                    % Pick the right layout
                    if contrastIdx == 1
                        ax = nexttile(tLowContrast);
                    else
                        ax = nexttile(tHighContrast);
                    end
                    hold(ax, 'on');

                    % Plot
                    for cc = 1:length(uniqueStim)
                        if uniqueStim(cc) == 0
                            markerShape = 'diamond';
                        else
                            markerShape = 'o';
                        end

                        scatter(ax, uniqueStim(cc), pRespondDifferent(cc), ...
                            markerSizeSet(markerSizeIdx(cc)), ...
                            'MarkerFaceColor', [pRespondDifferent(cc) 0 1-pRespondDifferent(cc)], ...
                            'MarkerEdgeColor', 'k', ...
                            'MarkerFaceAlpha', nTrialsPlot(cc)/max(nTrialsPlot), ...
                            'Marker', markerShape);
                    end

                    xlabel(ax, 'stimulus difference [dB]');
                    ylabel(ax, 'simulated p("different")');
                    title(ax, sprintf('Contrast %d | Light %d | RefFreq %.1f Hz', ...
                        contrastIdx, lightIdx, refFreqHz(refFreqIdx)));
                    ylim(ax, [-0.1 1.1]);
                    xlim(ax, [-6.0 6.0]);
                end

                % Plot the fit to simulated data for this ref frequency
                x = -5:0.1:5;  % evaluate the model at more dB values
                plot(ax, x, bayesianSameDiffModelTwoSigma(stimParamsDomainListSym,x,fit,0.5), 'k-', 'LineWidth',2);

            end
        end
    end
end


%% Function for trial-level simulation %%

function simTrialData = simulateSameDiffData( ...
        stimParamsDomainList, stimDiffDb, ...
        sigmaParams, priorSame, nTrialsPerStim)

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
trialIndex = 1;

for ii = 1:length(stimDiffDb)

    delta = stimDiffDb(ii);

    for tt = 1:nTrialsPerStim

        % Sample internal measurement
        % From likelihood of measurement fn given this stim diff
        m = normrnd(delta, sqrt(sigma^2 + sigmaZero^2));

        % Apply decision rule 
        % find the nearest value in mGrid to the sampled m 
        [~, idx] = min(abs(mGrid - m));
        % Get decisionDifferent at that point
        decision = decisionDifferent(idx);

        % Store trial
        simTrialData(trialIndex).stim = delta;
        simTrialData(trialIndex).respondYes = decision;

        trialIndex = trialIndex + 1;

    end
end

end

%% Objective function %%%

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

