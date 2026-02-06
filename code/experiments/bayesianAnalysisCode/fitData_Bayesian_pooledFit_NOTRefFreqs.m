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
% In this code, the data is pooled across sides, contrast, light levels, and subjects,
% but NOT across reference freqs. 

% Initialize struct for pooled data (pooled across subj, contrast, light, side)
pooledData = struct();

for refFreqIdx = 1:nFreqs
    pooledData(refFreqIdx).stim = [];
    pooledData(refFreqIdx).respondYes = [];
    pooledData(refFreqIdx).uniqueDb = [];
    pooledData(refFreqIdx).pRespondDifferent = [];
    pooledData(refFreqIdx).nTrials = [];
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

                        pooledData(refFreqIdx).stim = ...
                            [pooledData(refFreqIdx).stim, [thisTrialData.stim]];

                        pooledData(refFreqIdx).respondYes = ...
                            [pooledData(refFreqIdx).respondYes, [thisTrialData.respondYes]];


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
for refFreqIdx = 1:nFreqs
            % Load in the data for this contrast and light idx combo
            dB = pooledData(refFreqIdx).stim;
            respondYes = pooledData(refFreqIdx).respondYes;

            uniqueDb = unique(dB);
            pRespondDifferent = zeros(size(uniqueDb));
            nTrials  = zeros(size(uniqueDb));

            for ii = 1:length(uniqueDb)
                pRespondDifferent(ii) = mean(respondYes(dB == uniqueDb(ii)));
                nTrials(ii) = sum(dB == uniqueDb(ii)); % nTrials at each dB
            end

            % Save in pooled data struct
            pooledData(refFreqIdx).uniqueDb = uniqueDb;
            pooledData(refFreqIdx).pRespondDifferent = pRespondDifferent;
            pooledData(refFreqIdx).nTrials = nTrials;

            % Summing trials for the prior probability of same
            sameIdx = find(uniqueDb == 0); % Find the index of the zero dB point
            nDiffTrials = nDiffTrials + sum(nTrials(1:(sameIdx-1))) + sum(nTrials((sameIdx+1):end));
            nSameTrials = nSameTrials + nTrials(sameIdx);

end

% Global prior calculation once all trials are summed
priorSame = nSameTrials/(nSameTrials + nDiffTrials);

sigmaPooled = cell(1, nFreqs);
fValPooled  = cell(1, nFreqs);
% Now fit the psychometric function
for refFreqIdx = 1:nFreqs

    uniqueDb = pooledData(refFreqIdx).uniqueDb;
    pRespondDifferent = pooledData(refFreqIdx).pRespondDifferent;
    nTrials = pooledData(refFreqIdx).nTrials;

    initialSigmas = [1 1];
    lb = [0.001 0.001];
    ub = [5 5];

    options = bads('defaults');
    options.MaxIter = 100;

    [fit, fVal] = bads(@(p) negLogLikelihood(p, uniqueDb, pRespondDifferent, nTrials, priorSame), ...
        initialSigmas, lb, ub, lb, ub, [], options);

    sigmaPooled{refFreqIdx} = fit;
    fValPooled{refFreqIdx} = fVal;

end

% PLOTTING: plot pooled fit on pooled data
% One figure per reference frequency
for refFreqIdx = 1:nFreqs

    figure; hold on;
    title(sprintf('Pooled data | Ref freq = %d Hz', refFreqHz(refFreqIdx)));

    uniqueDb = pooledData(refFreqIdx).uniqueDb;
    pRespondDifferent = pooledData(refFreqIdx).pRespondDifferent;
    nTrials = pooledData(refFreqIdx).nTrials;

    % Marker size logic
    sameIdx = find(uniqueDb == 0); % Find the index of the zero dB point

    markerSizeIdx = zeros(size(nTrials));
    markerSizeIdx((1:end) ~= sameIdx) = ...
        discretize(nTrials((1:end) ~= sameIdx), 3);
    markerSizeIdx(sameIdx) = 4;  % Force zero dB point to largest bin

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
    fit = sigmaPooled{refFreqIdx};
    x = -6:0.1:6;

    plot(x, bayesianSameDiffModelTwoSigma(x, fit, priorSame), ...
        'k-', 'LineWidth', 2);

    % Axes labels
    ylim([-0.05 1.05]);
    xlim([-6 6]);
    xlabel('stimulus difference [dB]');
    ylabel('proportion respond different');
    box off;

end


%% Plotting sigma parameters for each reference frequency 

nFreqs = numel(refFreqHz);

sigmaTest_ctrl = nan(1, nFreqs);
sigmaRef_ctrl  = nan(1, nFreqs);
sigmaTest_mig  = nan(1, nFreqs);
sigmaRef_mig   = nan(1, nFreqs);

for refFreqIdx = 1:nFreqs
    fitCtrl = sigmaPooledControl{refFreqIdx};
    fitMig  = sigmaPooledMigraine{refFreqIdx};

    sigmaTest_ctrl(refFreqIdx) = fitCtrl(1);
    sigmaRef_ctrl(refFreqIdx)  = fitCtrl(2);

    sigmaTest_mig(refFreqIdx)  = fitMig(1);
    sigmaRef_mig(refFreqIdx)   = fitMig(2);
end

figure; hold on;

plot(refFreqHz, sigmaTest_ctrl, '-o', ...
    'LineWidth', 2, ...
    'Color', [0.3 0.3 0.8], ...
    'MarkerFaceColor', [0.3 0.3 0.8]);

plot(refFreqHz, sigmaTest_mig, '-o', ...
    'LineWidth', 2, ...
    'Color', [0.8 0.3 0.3], ...
    'MarkerFaceColor', [0.8 0.3 0.3]);

set(gca, 'XScale', 'log');
ax = gca;
ax.XLim = [min(refFreqHz)*0.9, max(refFreqHz)*1.1];
ax.YLim = [min(ylim)*0.9, max(ylim)*1.1];
xticks(refFreqHz); 
xlabel('Reference frequency (Hz)');
ylabel('sigma test');
ylim([0 2]);
title('sigma test vs reference frequency');

legend({'Control','Migraine'}, 'Location','Northwest');
box off;

figure; hold on;

plot(refFreqHz, sigmaRef_ctrl, '-o', ...
    'LineWidth', 2, ...
    'Color', [0.3 0.3 0.8], ...
    'MarkerFaceColor', [0.3 0.3 0.8]);

plot(refFreqHz, sigmaRef_mig, '-o', ...
    'LineWidth', 2, ...
    'Color', [0.8 0.3 0.3], ...
    'MarkerFaceColor', [0.8 0.3 0.3]);

set(gca, 'XScale', 'log');
ax = gca;
ax.XLim = [min(refFreqHz)*0.9, max(refFreqHz)*1.1];
ax.YLim = [min(ylim)*0.9, max(ylim)];
xticks(refFreqHz);
xlabel('Reference frequency (Hz)');
ylabel('sigma ref');
ylim([0 2]);
title('sigma ref vs reference frequency');

legend({'Control','Migraine'}, 'Location','Northwest');
box off;



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

