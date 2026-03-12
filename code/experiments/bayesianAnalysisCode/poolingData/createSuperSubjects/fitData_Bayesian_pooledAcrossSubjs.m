% SETUP
% Defining the directory
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
experimentName = 'DCPT_SDT';

% Define subjects + parameters
controlIDs = {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', ...
        'FLIC_0018', 'FLIC_0019','FLIC_0020', 'FLIC_0021', 'FLIC_0022', 'FLIC_0027', ...
        'FLIC_0028','FLIC_0039', 'FLIC_0042', 'FLIC_0049', 'FLIC_0050', 'FLIC_0051'};
migraineIDs = {'FLIC_1016','FLIC_1029','FLIC_1030','FLIC_1031','FLIC_1032', ...
        'FLIC_1034','FLIC_1035','FLIC_1036','FLIC_1038', 'FLIC_1041', 'FLIC_1043',...
        'FLIC_1044', 'FLIC_1046', 'FLIC_1047', 'FLIC_1048'};
subjectGroups = {controlIDs, migraineIDs};
groupNames = {'Control','Migraine'};
modDirection = 'LightFlux';
NDLabel = {'3x0', '0x5'};   % {'3x0', '0x5'}
stimParamLabels = {'low', 'hi'}; % {'low', 'hi'}
refFreqHz = logspace(log10(10),log10(30),5);  % logspace(log10(10),log10(30),5)
targetPhotoContrast = {'0x1','0x3'};  % {'0x1','0x3'}

% Define length variables
nFreqs = length(refFreqHz);
nContrasts = length(targetPhotoContrast);
nLightLevels = length(NDLabel);
nGroups = length(subjectGroups);

%% FITTING CODE %%
% Pooled sigma fit 
% Data pooled across subjs to make one control and one migrainer super subj

% Initialize pooled data struct for this group
pooledData = struct();

% Loading files and pooling dB and response data in structs
% Data is pooled across sides and subjects within group only
for groupIdx = 1:nGroups

    subjectID = subjectGroups{groupIdx};
    nSubj = length(subjectID);

    for contrastIdx = 1:nContrasts
        for lightIdx = 1:nLightLevels
            for refFreqIdx = 1:nFreqs
                pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).stim = [];
                pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).respondYes = [];
                pooledData(groupIdx, contrastIdx, lightIdx ,refFreqIdx).uniqueDb = [];
                pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).pRespondDifferent = [];
                pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).nTrials = [];
            end
        end
    end

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

                            pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).stim = ...
                                [pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).stim, [thisTrialData.stim]];

                            pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).respondYes = ...
                                [pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).respondYes, [thisTrialData.respondYes]];

                        else
                            warning('File not found: %s', fileName);
                        end

                    end
                end
            end
        end
    end
end

% Fit one sigma per each of the contrasts, light levels, groups, and frequencies
sigmaPooled = cell(nGroups, nContrasts, nLightLevels, nFreqs);
nSameTrials = 0;
nDiffTrials = 0;

% First load in the data
for groupIdx = 1:nGroups
    for contrastIdx = 1:nContrasts
        for lightIdx = 1:nLightLevels
            for refFreqIdx = 1:nFreqs

                % Load in the data for this contrast and light idx combo
                dB = pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).stim;
                respondYes = pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).respondYes;

                uniqueDb = unique(dB);
                pRespondDifferent = zeros(size(uniqueDb));
                nTrials  = zeros(size(uniqueDb));

                for ii = 1:length(uniqueDb)
                    pRespondDifferent(ii) = mean(respondYes(dB == uniqueDb(ii)));
                    nTrials(ii) = sum(dB == uniqueDb(ii)); % nTrials at each dB
                end

                % Save in pooled data struct
                pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).uniqueDb = uniqueDb;
                pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).pRespondDifferent = pRespondDifferent;
                pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).nTrials = nTrials;

                % Calculation of the prior probability of same
                sameIdx = find(uniqueDb == 0); % Find the index of the zero dB point
                nDiffTrials = nDiffTrials + sum(nTrials(1:(sameIdx-1))) + sum(nTrials((sameIdx+1):end));
                nSameTrials = nSameTrials + nTrials(sameIdx);

                % Prior calculation once all trials are summed
                if contrastIdx == 2 && lightIdx == 2 && refFreqIdx == 5 && groupIdx == 2
                    priorSame = nSameTrials/(nSameTrials + nDiffTrials);
                end

            end
        end
    end
end

% Now fit the psychometric function
for groupIdx = 1:nGroups
    for contrastIdx = 1:nContrasts
        for lightIdx = 1:nLightLevels
            for refFreqIdx = 1:nFreqs

                uniqueDb = pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).uniqueDb;
                pRespondDifferent = pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).pRespondDifferent;
                nTrials = pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).nTrials;

                initialSigmas = [0.5 0.5];
                lb = [0.001 0.001];
                ub = [5 5];

                options = bads('defaults');
                options.MaxIter = 100;

                [fit, ~] = bads(@(p) negLogLikelihood(p, uniqueDb, pRespondDifferent, nTrials, priorSame), ...
                    initialSigmas, lb, ub, lb, ub, [], options);

                sigmaPooled{groupIdx, contrastIdx, lightIdx, refFreqIdx} = fit;

            end
        end
    end
end

% PLOTTING: plot pooled fit on pooled data

for groupIdx = 1:nGroups

    for contrastIdx = 1:nContrasts
        for lightIdx = 1:nLightLevels

            figure; hold on;

            for refFreqIdx = 1:nFreqs

                uniqueDb = pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).uniqueDb;
                pRespondDifferent = pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).pRespondDifferent;
                nTrials = pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).nTrials;

                % scatter data
                for ii = 1:length(uniqueDb)

                    alphaVal = nTrials(ii)/max(nTrials);

                    scatter(uniqueDb(ii), pRespondDifferent(ii), ...
                        40, ...
                        'MarkerFaceColor',[pRespondDifferent(ii) 0 1-pRespondDifferent(ii)], ...
                        'MarkerEdgeColor','k', ...
                        'MarkerFaceAlpha',alphaVal);

                end

                % model fit
                fit = sigmaPooled{groupIdx, contrastIdx, lightIdx, refFreqIdx};

                x = -6:0.1:6;

                plot(x, bayesianSameDiffModelTwoSigma(x, fit, priorSame), ...
                    'LineWidth',2);

            end

            ylim([-0.05 1.05]);
            xlim([-6 6]);

            xlabel('stimulus difference [dB]');
            ylabel('proportion respond different');

            title(sprintf('%s | %s contrast | ND %s', ...
                groupNames{groupIdx}, ...
                stimParamLabels{contrastIdx}, ...
                NDLabel{lightIdx}));

            legend(string(refFreqHz) + " Hz");

        end
    end
end

% OLD CODE FROM DIFFERENT POOLING
% figure;
% t = tiledlayout(nContrasts, nLightLevels, ...
%     'TileSpacing','compact','Padding','compact');
% 
% for contrastIdx = 1:nContrasts
%     for lightIdx = 1:nLightLevels
% 
%         nexttile; hold on;
% 
%         uniqueDb = pooledData(contrastIdx, lightIdx).uniqueDb;
%         pRespondDifferent = pooledData(contrastIdx, lightIdx).pRespondDifferent;
%         nTrials = pooledData(contrastIdx, lightIdx).nTrials;
% 
%         % Determine marker size
%         sameIdx = find(uniqueDb == 0); % Find the index of the zero dB point
%         % Discretize all points except the zero-dB point
%         markerSizeIdx = zeros(size(nTrials));   
%         markerSizeIdx((1:end) ~= sameIdx) = discretize(nTrials((1:end) ~= sameIdx), 3);
%         markerSizeIdx(sameIdx) = 4;  % Force zero dB point to largest bin
%         markerSizeSet = [25, 50, 75, 100];
% 
%         for ii = 1:length(uniqueDb)
% 
%             if uniqueDb(ii) == 0
%                 markerShape = 'diamond';
%             else
%                 markerShape = 'o';
%             end
% 
%             minAlpha = 0.1;
%             % alphaVal = max(minAlpha, nTrials(ii)/max(nTrials));
%             alphaVal = nTrials(ii)/max(nTrials); 
% 
%             scatter(uniqueDb(ii), pRespondDifferent(ii), ...
%                 markerSizeSet(markerSizeIdx(ii)), ...
%                 'MarkerFaceColor', ...
%                 [pRespondDifferent(ii) 0 1-pRespondDifferent(ii)], ...
%                 'MarkerEdgeColor','k', ...
%                 'MarkerFaceAlpha', alphaVal, ...
%                 'Marker', markerShape);
%         end
% 
%         % Plot pooled fit
%         fit = sigmaPooled{contrastIdx, lightIdx};
%         x = -6:0.1:6;
% 
%         plot(x, bayesianSameDiffModelTwoSigma(x, fit, priorSame), ...
%             'k-', 'LineWidth', 2);
% 
%         % Labels
%         ylim([-0.05 1.05]);
%         xlim([-6 6]);
%         xlabel('stimulus difference [dB]');
%         ylabel('proportion respond different');
% 
%         title(sprintf('%s contrast | ND %s', ...
%             stimParamLabels{contrastIdx}, NDLabel{lightIdx}));
% 
%     end
% end

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

