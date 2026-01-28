% SETUP
% Defining the directory
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
experimentName = 'DCPT_SDT';

% Define subjects + parameters
% Control subject IDs: {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', ...
% 'FLIC_0018', 'FLIC_0019','FLIC_0020', 'FLIC_0021', 'FLIC_0022', 'FLIC_0027',
% 'FLIC_0028','FLIC_0039', 'FLIC_0042'}; eventually add 'FLIC_0051'
% Migraine subject IDs: {'FLIC_1016','FLIC_1029','FLIC_1030','FLIC_1031','FLIC_1032', ...
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

%% FITTING CODE %%
% Bootstrapped pooled sigma fit (across subjects, reference freqs, and sides)

nBoot = 2; % number of bootstrap iterations
nConditions = nContrasts * nLightLevels;

% Preallocate separate matrices for sigma and sigma zero
sigmaMatrix = zeros(nBoot, nConditions);
sigmaZeroMatrix = zeros(nBoot, nConditions);

rng(0); % set the seed to 0

for bootIdx = 1:nBoot
    % Sample subject indices with replacement
    bootSubjIdx = randsample(nSubj, nSubj, true);

    % Initialize struct for pooled data
    pooledData = struct();

    for contrastIdx = 1:nContrasts
        for lightIdx = 1:nLightLevels
            pooledData(contrastIdx, lightIdx).stim = [];
            pooledData(contrastIdx, lightIdx).respondYes = [];
            pooledData(contrastIdx, lightIdx).uniqueDb = [];
            pooledData(contrastIdx, lightIdx).pRespondDifferent = [];
            pooledData(contrastIdx, lightIdx).nTrials = [];
        end
    end

    % Loading files and pooling dB and response data in structs
    % Data is pooled across subjects, frequencies, and sides
    % It is stratified only across contrastIdx and lightIdx
    % Bootstrap subjects
    for subjIdx = 1:nSubj
        bootSubj = bootSubjIdx(subjIdx);
        thisSubj = subjectID{bootSubj};

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

                            pooledData(contrastIdx, lightIdx).stim = ...
                                [pooledData(contrastIdx, lightIdx).stim, [thisTrialData.stim]];

                            pooledData(contrastIdx, lightIdx).respondYes = ...
                                [pooledData(contrastIdx, lightIdx).respondYes, [thisTrialData.respondYes]];

                        else
                            warning('File not found: %s', fileName);
                        end

                    end
                end
            end
        end
    end

    % Fit one sigma per each of the four (contrast x light) levels
    sigmaPooled = cell(nContrasts, nLightLevels);
    nSameTrials = 0;
    nDiffTrials = 0;

    % First load in the data
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

    % Now fit the psychometric function
    colIdx = 1; % column counter for the 4 conditions
    for contrastIdx = 1:nContrasts
        for lightIdx = 1:nLightLevels

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

%%
% PLOTTING: plot pooled fit on pooled data

figure;
t = tiledlayout(nContrasts, nLightLevels, ...
    'TileSpacing','compact','Padding','compact');

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
        fit = sigmaPooled{contrastIdx, lightIdx};
        x = -6:0.1:6;

        plot(x, bayesianSameDiffModelTwoSigma(x, fit, priorSame), ...
            'k-', 'LineWidth', 2);

        % Labels
        ylim([-0.05 1.05]);
        xlim([-6 6]);
        xlabel('stimulus difference [dB]');
        ylabel('proportion respond different');

        title(sprintf('%s contrast | ND %s', ...
            stimParamLabels{contrastIdx}, NDLabel{lightIdx}));

    end
end

%% Plotting bootstrapped sigmas



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

