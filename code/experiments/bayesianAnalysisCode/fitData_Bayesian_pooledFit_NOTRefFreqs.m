% SETUP
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
subjectID =  {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', ...
'FLIC_0018', 'FLIC_0019','FLIC_0020', 'FLIC_0021', 'FLIC_0022', 'FLIC_0027',...
'FLIC_0028','FLIC_0039', 'FLIC_0042', 'FLIC_0049', 'FLIC_0050', 'FLIC_0051'}; 
modDirection = 'LightFlux';
NDLabel = {'3x0', '0x5'};   % {'3x0', '0x5'}
lightParamLabels = {'low light', 'high light'};
stimParamLabels = {'low', 'hi'}; % {'low', 'hi'}
refFreqHz = logspace(log10(10),log10(30),5);  % logspace(log10(10),log10(30),5)
targetPhotoContrast = {'0x1','0x3'};  % {'0x1','0x3'}

% Define length variables
nFreqs = length(refFreqHz);
nContrasts = length(targetPhotoContrast);
nLightLevels = length(NDLabel);
nSubj = length(subjectID);

%% FITTING CODE %%
% In this code, the data is pooled across sides, contrast, and light levels,
% but NOT across reference freqs or subjs. 

% Initialize struct for pooled data (pooled across subj, contrast, light, side)
pooledData = struct();

for subjIdx = 1:nSubj
    for refFreqIdx = 1:nFreqs
        pooledData(subjIdx, refFreqIdx).stim = [];
        pooledData(subjIdx, refFreqIdx).respondYes = [];
        pooledData(subjIdx, refFreqIdx).uniqueDb = [];
        pooledData(subjIdx, refFreqIdx).pRespondDifferent = [];
        pooledData(subjIdx, refFreqIdx).nTrials = [];
    end
end

% Loading files and pooling dB and response data in structs
for subjIdx = 1:nSubj
    thisSubj = subjectID{subjIdx};

    for lightIdx = 1:nLightLevels
        for refFreqIdx = 1:nFreqs
            currentRefFreq = refFreqHz(refFreqIdx);

            for contrastIdx = 1:nContrasts
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

                        % Flip the sign for the low side values
                        if contains(fileName, 'lo')
                            for trial = 1:numel(thisTrialData)
                                thisTrialData(trial).stim = -thisTrialData(trial).stim;
                            end
                        end

                        pooledData(subjIdx, refFreqIdx).stim = ...
                            [pooledData(subjIdx, refFreqIdx).stim, [thisTrialData.stim]];

                        pooledData(subjIdx, refFreqIdx).respondYes = ...
                            [pooledData(subjIdx, refFreqIdx).respondYes, [thisTrialData.respondYes]];


                    else
                        warning('File not found: %s', fileName);
                    end

                end
            end
        end
    end
end

% Fit one sigma per each of the four (contrast x light) levels
nSameTrials = 0;
nDiffTrials = 0;

% First load in the data
for subjIdx = 1:nSubj
    for refFreqIdx = 1:nFreqs
        % Load in the data for this ref freq and subj combo
        dB = pooledData(subjIdx, refFreqIdx).stim;
        respondYes = pooledData(subjIdx, refFreqIdx).respondYes;

        uniqueDb = unique(dB);
        pRespondDifferent = zeros(size(uniqueDb));
        nTrials  = zeros(size(uniqueDb));

        for ii = 1:length(uniqueDb)
            pRespondDifferent(ii) = mean(respondYes(dB == uniqueDb(ii)));
            nTrials(ii) = sum(dB == uniqueDb(ii)); % nTrials at each dB
        end

        % Save in pooled data struct
        pooledData(subjIdx, refFreqIdx).uniqueDb = uniqueDb;
        pooledData(subjIdx, refFreqIdx).pRespondDifferent = pRespondDifferent;
        pooledData(subjIdx, refFreqIdx).nTrials = nTrials;

        % Summing trials for the prior probability of same
        sameIdx = find(uniqueDb == 0); % Find the index of the zero dB point
        nDiffTrials = nDiffTrials + sum(nTrials(1:(sameIdx-1))) + sum(nTrials((sameIdx+1):end));
        nSameTrials = nSameTrials + nTrials(sameIdx);
    end
end

% Global prior calculation once all trials are summed
priorSame = nSameTrials/(nSameTrials + nDiffTrials);

sigmaPooled = cell(1, nFreqs);
fValPooled  = cell(1, nFreqs);
% Now fit the psychometric function
for subjIdx = 1:nSubj
    for refFreqIdx = 1:nFreqs

        uniqueDb = pooledData(subjIdx, refFreqIdx).uniqueDb;
        pRespondDifferent = pooledData(subjIdx, refFreqIdx).pRespondDifferent;
        nTrials = pooledData(subjIdx, refFreqIdx).nTrials;

        initialSigmas = [1 1];
        lb = [0.001 0.001];
        ub = [5 5];

        options = bads('defaults');
        options.MaxIter = 100;

        [fit, fVal] = bads(@(p) negLogLikelihood(p, uniqueDb, pRespondDifferent, nTrials, priorSame), ...
            initialSigmas, lb, ub, lb, ub, [], options);

        sigmaPooled{subjIdx, refFreqIdx} = fit;
        fValPooled{subjIdx, refFreqIdx} = fVal;

    end
end

% PLOTTING: plot pooled fit on pooled data
% One figure per reference frequency
for subjIdx = 1:nSubj

    figure;
    tiledlayout(1, nFreqs, 'TileSpacing','compact', 'Padding','compact');

    sgtitle(sprintf('Pooled data | Subject %s', subjectID{subjIdx}),'Interpreter','none');

    for refFreqIdx = 1:nFreqs

        nexttile; hold on;
        title(sprintf('Ref freq = %d Hz', refFreqHz(refFreqIdx)));

        uniqueDb = pooledData(subjIdx, refFreqIdx).uniqueDb;
        pRespondDifferent = pooledData(subjIdx, refFreqIdx).pRespondDifferent;
        nTrials = pooledData(subjIdx, refFreqIdx).nTrials;

        % Marker size logic
        sameIdx = find(uniqueDb == 0);

        markerSizeIdx = zeros(size(nTrials));
        markerSizeIdx((1:end) ~= sameIdx) = ...
            discretize(nTrials((1:end) ~= sameIdx), 3);
        markerSizeIdx(sameIdx) = 4;

        markerSizeSet = [25, 50, 75, 100];

        % Scatter points
        for ii = 1:length(uniqueDb)

            if uniqueDb(ii) == 0
                markerShape = 'diamond';
            else
                markerShape = 'o';
            end

            alphaVal = nTrials(ii) / max(nTrials);

            scatter(uniqueDb(ii), pRespondDifferent(ii), ...
                markerSizeSet(markerSizeIdx(ii)), ...
                'MarkerFaceColor', ...
                [pRespondDifferent(ii) 0 1-pRespondDifferent(ii)], ...
                'MarkerEdgeColor','k', ...
                'MarkerFaceAlpha', alphaVal, ...
                'Marker', markerShape);
        end

        % Plot pooled fit
        fit = sigmaPooled{subjIdx, refFreqIdx};
        x = -6:0.1:6;

        plot(x, bayesianSameDiffModelTwoSigma(x, fit, priorSame), ...
            'k-', 'LineWidth', 2);

        % Axes formatting
        ylim([-0.05 1.05]);
        xlim([-6 6]);
        xlabel('stimulus difference [dB]');
        ylabel('proportion respond different');
        box off;

    end
end

%% Plotting sigma parameters for each reference frequency 

nFreqs = numel(refFreqHz);

[nSubj, nFreqs] = size(sigmaPooledControl);

sigmaTest_ctrl = nan(nSubj, nFreqs);
sigmaRef_ctrl  = nan(nSubj, nFreqs);

sigmaTest_mig = nan(nSubj, nFreqs);
sigmaRef_mig  = nan(nSubj, nFreqs);

for subjIdx = 1:nSubj
    for refFreqIdx = 1:nFreqs
        sigmaTest_ctrl(subjIdx, refFreqIdx) = sigmaPooledControl{subjIdx, refFreqIdx}(1);
        sigmaRef_ctrl(subjIdx, refFreqIdx)  = sigmaPooledControl{subjIdx, refFreqIdx}(2);

        sigmaTest_mig(subjIdx, refFreqIdx) = sigmaPooledMigraine{subjIdx, refFreqIdx}(1);
        sigmaRef_mig(subjIdx, refFreqIdx)  = sigmaPooledMigraine{subjIdx, refFreqIdx}(2);
    end
end

sigmaTest_ctrl_mean = mean(sigmaTest_ctrl, 1);
sigmaTest_ctrl_sem  = std(sigmaTest_ctrl, 0, 1) / sqrt(size(sigmaTest_ctrl,1));

sigmaRef_ctrl_mean  = mean(sigmaRef_ctrl, 1);
sigmaRef_ctrl_sem   = std(sigmaRef_ctrl, 0, 1) / sqrt(size(sigmaRef_ctrl,1));

sigmaTest_mig_mean = mean(sigmaTest_mig, 1);
sigmaTest_mig_sem  = std(sigmaTest_mig, 0, 1) / sqrt(size(sigmaTest_mig,1));

sigmaRef_mig_mean  = mean(sigmaRef_mig, 1);
sigmaRef_mig_sem   = std(sigmaRef_mig, 0, 1) / sqrt(size(sigmaRef_mig,1));

% Sigma test plotting
figure; hold on;
errorbar(refFreqHz, sigmaTest_ctrl_mean, sigmaTest_ctrl_sem, '-o', ...
    'LineWidth',2, ...
    'Color',[0.3 0.3 0.8], ...
    'MarkerFaceColor',[0.3 0.3 0.8], ...
    'CapSize',10);

errorbar(refFreqHz, sigmaTest_mig_mean, sigmaTest_mig_sem, '-o', ...
    'LineWidth',2, ...
    'Color',[0.8 0.3 0.3], ...
    'MarkerFaceColor',[0.8 0.3 0.3], ...
    'CapSize',10);

set(gca,'XScale','log');
xticks(refFreqHz);
xlabel('Reference frequency (Hz)');
ylabel('sigma test');
axis padded
ylim([0 2.5]);
title('Sigma test across reference frequency');
legend({'Control','Migraine'}, 'Location','Northwest');

% Sigma ref plotting
figure; hold on;
errorbar(refFreqHz, sigmaRef_ctrl_mean, sigmaRef_ctrl_sem, '-o', ...
    'LineWidth',2, ...
    'Color',[0.3 0.3 0.8], ...
    'MarkerFaceColor',[0.3 0.3 0.8], ...
    'CapSize',10);

errorbar(refFreqHz, sigmaRef_mig_mean, sigmaRef_mig_sem, '-o', ...
    'LineWidth',2, ...
    'Color',[0.8 0.3 0.3], ...
    'MarkerFaceColor',[0.8 0.3 0.3], ...
    'CapSize',10);

set(gca,'XScale','log');
xticks(refFreqHz);
xlabel('Reference frequency (Hz)');
ylabel('sigma ref');
axis padded
ylim([0 2.5]);
title('Sigma ref across reference frequency');
legend({'Control','Migraine'}, 'Location','Northwest');



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

