% SETUP
saveData = true;% true to save bootstrapping data as a file. if false, make it load existing
% Defining the directory
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
experimentName = 'DCPT_SDT';
% Defining directory where the sigma data is located
dropBoxAnalysisDir = 'FLIC_analysis';
dropBoxAnalysisSubDir = 'dichopticFlicker';
sigmaDataDir  = 'sigmaData';

if saveData
    saveFileDir = [dropBoxBaseDir, '/FLIC_analysis/dichopticFlicker/sigmaData'];
    saveFileName = [saveFileDir, '/BootrstappedSigmas14Migraine.mat'];
end

% Define subjects + parameters
% Control subject IDs: {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', ...
% 'FLIC_0018', 'FLIC_0019','FLIC_0020', 'FLIC_0021', 'FLIC_0022', 'FLIC_0027',
% 'FLIC_0028','FLIC_0039', 'FLIC_0042', 'FLIC_0049', 'FLIC_0051'}; 
% Migrainer subject IDs: {'FLIC_1016','FLIC_1029','FLIC_1030','FLIC_1031','FLIC_1032', ...
    % 'FLIC_1034','FLIC_1035','FLIC_1036','FLIC_1038', 'FLIC_1041', 'FLIC_1043',...
    % 'FLIC_1044', 'FLIC_1046', 'FLIC_1047'};
subjectID = {'FLIC_1016','FLIC_1029','FLIC_1030','FLIC_1031','FLIC_1032', ...
'FLIC_1034','FLIC_1035','FLIC_1036','FLIC_1038', 'FLIC_1041', 'FLIC_1043',...
'FLIC_1044', 'FLIC_1046', 'FLIC_1047'};
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

%% LOAD ALL SUBJECT DATA 

% Loading files and pooling dB and response data in structs
% Data is pooled across frequencies and sides, NOT subjects yet
% Stratified across subjIdx, contrastIdx, and lightIdx

allData = cell(nSubj, nContrasts, nLightLevels);

for subjIdx = 1:nSubj
    thisSubj = subjectID{subjIdx};

    for contrastIdx = 1:nContrasts
        for lightIdx = 1:nLightLevels

            allData{subjIdx, contrastIdx, lightIdx}.stim = [];
            allData{subjIdx, contrastIdx, lightIdx}.respondYes = [];

            for refFreqIdx = 1:nFreqs
                currentRefFreq = refFreqHz(refFreqIdx);

                for sideIdx = 1:length(stimParamLabels)

                    subjectDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, thisSubj);
                    dataDir = fullfile(subjectDir, ...
                        [modDirection '_ND' NDLabel{lightIdx} '_shifted'], experimentName);

                    fileName = fullfile(dataDir, ...
                        [thisSubj '_' modDirection '_' experimentName ...
                        '_cont-' targetPhotoContrast{contrastIdx} ...
                        '_refFreq-' num2str(currentRefFreq) 'Hz_' ...
                        stimParamLabels{sideIdx} '.mat']);

                    if exist(fileName, 'file')
                        load(fileName,'psychObj')
                        thisTrialData = psychObj.questData.trialData;

                        % Flip sign for low side
                        if contains(fileName, 'lo')
                            for t = 1:numel(thisTrialData)
                                thisTrialData(t).stim = -thisTrialData(t).stim;
                            end
                        end

                        allData{subjIdx, contrastIdx, lightIdx}.stim = ...
                            [allData{subjIdx, contrastIdx, lightIdx}.stim, ...
                             [thisTrialData.stim]];

                        allData{subjIdx, contrastIdx, lightIdx}.respondYes = ...
                            [allData{subjIdx, contrastIdx, lightIdx}.respondYes, ...
                             [thisTrialData.respondYes]];
                    end
                end
            end
        end
    end
end

%% FIT THE PSYCHOMETRIC FUNCTION WITH BOOTSTRAPPING
% Bootstrapped pooled sigma fit (across subjects, reference freqs, and sides)

nBoot = 1000; % number of bootstrap iterations
nConditions = nContrasts * nLightLevels;

% Preallocate separate matrices for sigma and sigma zero
sigmaMatrix = zeros(nBoot, nConditions);
sigmaZeroMatrix = zeros(nBoot, nConditions);

rng(0); % set the seed to 0

for bootIdx = 1:nBoot
    % Sample subject indices with replacement
    bootSubjIdx = randsample(nSubj, nSubj, true);

     % Pool + summarize for this bootstrap sample
    [pooledData, priorSame] = poolSubjsAndSummarize(allData, bootSubjIdx, nContrasts, nLightLevels);
  
    % Now fit the psychometric function
    % Fit one sigma per each of the four (contrast x light) levels
    sigmaPooled = cell(nContrasts, nLightLevels);
    colIdx = 1; % column counter for the 4 conditions
    for contrastIdx = 1:nContrasts
        for lightIdx = 1:nLightLevels

            uniqueDb = pooledData(contrastIdx, lightIdx).uniqueDb;
            pRespondDifferent = pooledData(contrastIdx, lightIdx).pRespondDifferent;
            nTrials = pooledData(contrastIdx, lightIdx).nTrials;

            initialSigmas = [0.5 0.5];
            lb = [0.001 0.001];
            ub = [5 5];

            options = bads('defaults');
            options.MaxIter = 100;

            [fit, ~] = bads(@(p) negLogLikelihood(p, uniqueDb, pRespondDifferent, nTrials, priorSame), ...
                initialSigmas, lb, ub, lb, ub, [], options);

            sigmaPooled{contrastIdx, lightIdx} = fit;

            sigmaMatrix(bootIdx, colIdx) = fit(1);
            sigmaZeroMatrix(bootIdx, colIdx) = fit(2);

            colIdx = colIdx + 1; % move to next condition

        end
    end
end

if saveData
    save(saveFileName, "sigmaMatrix", "sigmaZeroMatrix");
end

%% PLOTTING: plot pooled fit (with bootstrapping) on pooled data (not bootstrapped)

% Load bootstrapped sigma matrices - choose control or migraine
dataDir = fullfile(dropBoxBaseDir,dropBoxAnalysisDir, dropBoxAnalysisSubDir, sigmaDataDir); 
sigmaMatrix = load(fullfile(dataDir, 'BootstrappedSigmas14Control'), 'sigmaMatrix').sigmaMatrix;
sigmaZeroMatrix = load(fullfile(dataDir, 'BootstrappedSigmas14Control'), 'sigmaZeroMatrix').sigmaZeroMatrix;

% Compute mean and CI of bootstrapped sigma fits (averaging sigmas)
colIdx = 1; % column counter for the 4 conditions
for contrastIdx = 1:nContrasts
    for lightIdx = 1:nLightLevels

        % Compute mean for this condition
        sigmaMean = mean(sigmaMatrix(:,colIdx));
        sigmaZeroMean = mean(sigmaZeroMatrix(:,colIdx));
        paramMeans{contrastIdx, lightIdx} = [sigmaMean sigmaZeroMean];

        % Compute 95% CI
        sigmaCI = prctile(sigmaMatrix(:,colIdx), [2.5 97.5]);
        sigmaZeroCI = prctile(sigmaZeroMatrix(:,colIdx), [2.5 97.5]);
        paramCI{contrastIdx, lightIdx} = [sigmaCI; sigmaZeroCI];

        colIdx = colIdx + 1;
    end
end

% Pool data across original list of subjects for plotting
subjIdxVec = 1:nSubj;
[pooledData, priorSame] = poolSubjsAndSummarize(allData, subjIdxVec, nContrasts, nLightLevels);

% Plot pooled fit
figure;
t = tiledlayout(nContrasts, nLightLevels, ...
    'TileSpacing','compact','Padding','compact');
title(t, 'Control Subjects'); 

for contrastIdx = 1:nContrasts
    for lightIdx = 1:nLightLevels

        nexttile; hold on;

        uniqueDb = pooledData(contrastIdx, lightIdx).uniqueDb;
        pRespondDifferent = pooledData(contrastIdx, lightIdx).pRespondDifferent;
        nTrials = pooledData(contrastIdx, lightIdx).nTrials;

        % Determine marker size
        sameIdx = find(uniqueDb == 0); % Find the index of the zero dB point
        % Discretize all points except the zero-dB point
        markerSizeIdx = zeros(size(nTrials));   
        markerSizeIdx((1:end) ~= sameIdx) = discretize(nTrials((1:end) ~= sameIdx), 3);
        markerSizeIdx(sameIdx) = 4;  % Force zero dB point to largest bin
        markerSizeSet = [25, 50, 75, 100];

        for ii = 1:length(uniqueDb)

            if uniqueDb(ii) == 0
                markerShape = 'diamond';
            else
                markerShape = 'o';
            end

            minAlpha = 0.1;
            % alphaVal = max(minAlpha, nTrials(ii)/max(nTrials));
            alphaVal = nTrials(ii)/max(nTrials); 

            scatter(uniqueDb(ii), pRespondDifferent(ii), ...
                markerSizeSet(markerSizeIdx(ii)), ...
                'MarkerFaceColor', ...
                [pRespondDifferent(ii) 0 1-pRespondDifferent(ii)], ...
                'MarkerEdgeColor','k', ...
                'MarkerFaceAlpha', alphaVal, ...
                'Marker', markerShape);
        end

        % Plot pooled fit
        fit = paramMeans{contrastIdx, lightIdx};
        x = -6:0.1:6;

        % Main fit line
        plot(x, bayesianSameDiffModelTwoSigma(x, fit, priorSame), ...
            'k-', 'LineWidth', 2);

        % Add 95% CI lines
        ciLower = paramCI{contrastIdx, lightIdx}(:, 1);  % 2.5 percentile of sigma and sigmaZero vals
        ciUpper = paramCI{contrastIdx, lightIdx}(:, 2);  % 97.5 percentile of sigma and sigmaZero vals

        plot(x, bayesianSameDiffModelTwoSigma(x, ciLower, priorSame), '--', 'Color', [0.6 0.75 0.9], 'LineWidth', 1.5);
        plot(x, bayesianSameDiffModelTwoSigma(x, ciUpper, priorSame), '--', 'Color', [0.2 0.4 0.8], 'LineWidth', 1.5);

        % Labels
        ylim([-0.05 1.05]);
        xlim([-6 6]);
        xlabel('stimulus difference [dB]');
        ylabel('proportion respond different');

        title(sprintf('%s contrast | ND %s', ...
            stimParamLabels{contrastIdx}, NDLabel{lightIdx}));

    end
end


%% Plot bootstrapped sigmas across conditions

dataDir = fullfile(dropBoxBaseDir,dropBoxAnalysisDir, dropBoxAnalysisSubDir, sigmaDataDir); 

sigmaMatrixControl = load(fullfile(dataDir, 'BootstrappedSigmas14Control'), 'sigmaMatrix').sigmaMatrix;
sigmaZeroMatrixControl = load(fullfile(dataDir, 'BootstrappedSigmas14Control'), 'sigmaZeroMatrix').sigmaZeroMatrix;
sigmaMatrixMigraine = load(fullfile(dataDir, 'BootstrappedSigmas14Migraine'), 'sigmaMatrix').sigmaMatrix;
sigmaZeroMatrixMigraine = load(fullfile(dataDir, 'BootstrappedSigmas14Migraine'), 'sigmaZeroMatrix').sigmaZeroMatrix;

paramMatrices.Control = {sigmaMatrixControl, sigmaZeroMatrixControl};
paramMatrices.Migraine = {sigmaMatrixMigraine, sigmaZeroMatrixMigraine};

condIdx = [ ...
    1 2;   % low contrast:  low light, high light
    3 4    % high contrast: low light, high light
];

xContrast = [1 2];
dxLight   = [-0.1 0.1];

colors = [
    0 0 0;   % low light 
    0 0 1    % high light
    ];

groups = {'Control','Migraine'};
markers = {'o','s'};
lw = 2;
ms = 125;

paramLabels = {'sigma test','sigma ref'};
figTitles   = {'Bootstrapped sigma test','Bootstrapped sigma ref'};

for paramIdx = 1:2    % sigma, sigma0

    figure; hold on;

    for groupIdx = 1:length(groups)   % control, migraine

        groupName = groups{groupIdx};
        thisMat   = paramMatrices.(groupName){paramIdx};

        colIdx = 1;  % column counter for the 4 conditions

        for contrastIdx = 1:nContrasts
            for lightIdx = 1:nLightLevels

                mu = mean(thisMat(:,colIdx));
                ci = prctile(thisMat(:,colIdx), [2.5 97.5]);

                % small horizontal gap so groups don’t overlap
                groupOffset = (groupIdx-1.5)*0.08;

                % X position
                x = xContrast(contrastIdx) + dxLight(lightIdx) + groupOffset;

                % Plot error bar
                errorbar(x, mu, mu-ci(1), ci(2)-mu, ...
                    'Color', colors(lightIdx,:), ...
                    'LineWidth', lw, ...
                    'LineStyle', 'none');

                % Plot marker
                scatter(x, mu, ms, colors(lightIdx,:), markers{groupIdx}, 'filled');

                colIdx = colIdx + 1; % move to next condition

            end
        end
    end

    % axes & labels
    set(gca,'XTick',xContrast, ...
        'XTickLabel',{'Low contrast','High contrast'});
    ylabel(paramLabels{paramIdx});
    xlim([0.5 2.5]);
    ylim([0 2]);
    box off;

    % Define legend handles (dummy plots)
    h(1) = plot(nan, nan, 'o', 'Color', [0 0 0], 'MarkerFaceColor', [0 0 0]);   % Low light - Control
    h(2) = plot(nan, nan, 'o', 'Color', [0 0 1], 'MarkerFaceColor', [0 0 1]);   % High light – Control
    h(3) = plot(nan, nan, 's', 'Color', [0 0 0], 'MarkerFaceColor', [0 0 0]);   % Low light – Migraine
    h(4) = plot(nan, nan, 's', 'Color', [0 0 1], 'MarkerFaceColor', [0 0 1]);

    legend(h, {'Low light – Control','High light – Control', ...
        'Low light – Migraine','High light – Migraine'}, 'Location','best');

    title(figTitles{paramIdx});
end

%% Function to pool data across subjects and summarize

function [pooledData, priorSame] = poolSubjsAndSummarize(allData, subjIdxVec, nContrasts, nLightLevels)
    
    pooledData = struct();
    for contrastIdx = 1:nContrasts
        for lightIdx = 1:nLightLevels
            pooledData(contrastIdx, lightIdx).stim = [];
            pooledData(contrastIdx, lightIdx).respondYes = [];
        end
    end
    
    % Pool data across this list of subjs
    for subjIdx = 1:length(subjIdxVec)
        thisSubj = subjIdxVec(subjIdx);
    
        for contrastIdx = 1:nContrasts
            for lightIdx = 1:nLightLevels
    
                pooledData(contrastIdx, lightIdx).stim = ...
                    [pooledData(contrastIdx, lightIdx).stim, ...
                    allData{thisSubj, contrastIdx, lightIdx}.stim];
    
                pooledData(contrastIdx, lightIdx).respondYes = ...
                    [pooledData(contrastIdx, lightIdx).respondYes, ...
                    allData{thisSubj, contrastIdx, lightIdx}.respondYes];
            end
        end
    end
    
    % Calculate proportion respond different, unique dB values, nTrials, and
    % priorSame for this set of subjects
    nSameTrials = 0;
    nDiffTrials = 0;
    
    for contrastIdx = 1:nContrasts
        for lightIdx = 1:nLightLevels
    
            % Load in the data for this contrast and light idx combo
            dB = pooledData(contrastIdx, lightIdx).stim;
            respondYes = pooledData(contrastIdx, lightIdx).respondYes;
    
            uniqueDb = unique(dB);
            pRespondDifferent = zeros(size(uniqueDb));
            nTrials  = zeros(size(uniqueDb));
    
            for ii = 1:length(uniqueDb)
                pRespondDifferent(ii) = mean(respondYes(dB == uniqueDb(ii)));
                nTrials(ii) = sum(dB == uniqueDb(ii)); % nTrials at each dB
            end
    
            % Save in pooled data struct
            pooledData(contrastIdx, lightIdx).uniqueDb = uniqueDb;
            pooledData(contrastIdx, lightIdx).pRespondDifferent = pRespondDifferent;
            pooledData(contrastIdx, lightIdx).nTrials = nTrials;
    
            % Calculation of the prior probability of same
            sameIdx = find(uniqueDb == 0); % Find the index of the zero dB point
            nDiffTrials = nDiffTrials + sum(nTrials(1:(sameIdx-1))) + sum(nTrials((sameIdx+1):end));
            nSameTrials = nSameTrials + nTrials(sameIdx);
    
            % Prior calculation once all trials are summed
            if contrastIdx == 2 && lightIdx == 2
                priorSame = nSameTrials/(nSameTrials + nDiffTrials);
            end
    
        end
    end

end


%% Objective function %%
function nll = negLogLikelihood(sigma, uniqueDbValues, probData, nTrials, priorSame)

% Predict probability of "different" at each unique dB level
% P_diff = bayesianSameDiffModel(uniqueDbValues, sigma);
P_diff = bayesianSameDiffModelTwoSigma(uniqueDbValues, sigma, priorSame);
P_diff = max(min(P_diff, 1 - 1e-9), 1e-9); % To make sure 0 < P_diff < 1

% Finding the count of different responses (aka the number of
% "successes")
k = probData .* nTrials; % prop observed diff multiplied by total number of trials at that dB

% Finding the binomial negative log-likelihood
nll = -sum(k .* log(P_diff) + (nTrials - k) .* log(1 - P_diff));

end

