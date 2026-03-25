% SETUP

% Choose whether you want to save the sigma data in a .mat file
saveData = true;

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
% This code DOES incorporate a constraint so that sigmaRef <= sigmaTest

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

                        % Find stimParamsDomainList and store one psychObj as template
                        if ~exist('stimParamsDomainList','var')
                            templatePsychObj = psychObj;

                            % Extract domain list (positive values only)
                            stimParamsDomainList = psychObj.questData.stimParamsDomainList;
                            stimParamsDomainList = stimParamsDomainList{:}';

                            % Make symmetric domain
                            stimParamsDomainList = unique([-stimParamsDomainList, stimParamsDomainList]);
                            stimParamsDomainList = sort(stimParamsDomainList);
                        end

                    end
                end
            end
        end
    end
end

% Fit one sigma per each of the contrasts, light levels, groups, and frequencies
sigmaPooled = cell(nGroups, nContrasts, nLightLevels, nFreqs);
fValMatrix = cell(nGroups, nContrasts, nLightLevels, nFreqs);

% First load in the data
for groupIdx = 1:nGroups

    % Calculating prior probability of same for each group
    nSameTrials = 0;
    nDiffTrials = 0;

    for contrastIdx = 1:nContrasts
        for lightIdx = 1:nLightLevels
            for refFreqIdx = 1:nFreqs

                % Load in the data for this condition (combo of groupIdx, contrastIdx,
                % lightIdx, refFreqIdz)
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

            end
        end
    end

    % Prior calculation once all trials are summed
    priorSame(groupIdx) = nSameTrials/(nSameTrials + nDiffTrials);

end

% Now fit the psychometric function
for groupIdx = 1:nGroups
    for contrastIdx = 1:nContrasts
        for lightIdx = 1:nLightLevels
            for refFreqIdx = 1:nFreqs

                uniqueDb = pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).uniqueDb;
                pRespondDifferent = pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).pRespondDifferent;
                nTrials = pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).nTrials;

                % initialSigmas = [0.5 0.5];
                % lb = [0.001 0.001];
                % ub = [5 5];
                % TESTING single sigma value
                initialSigma = 0.5;   % single starting value
                lb = 0.001;            % lower bound
                ub = 5;                % upper bound

                options = bads('defaults');
                options.MaxIter = 100;

                [fit, fbest] = bads(@(p) negLogLikelihood(p, stimParamsDomainList, uniqueDb, pRespondDifferent, nTrials, priorSame(groupIdx)), ...
                    initialSigma, lb, ub, lb, ub, [], options);

                sigmaPooled{groupIdx, contrastIdx, lightIdx, refFreqIdx} = fit;
                fValMatrix{groupIdx, contrastIdx, lightIdx, refFreqIdx} = fbest;

            end
        end
    end
end

% PLOTTING: plot pooled fit on pooled data
for groupIdx = 1:nGroups
    for contrastIdx = 1:nContrasts

        % Create figure per contrast
        fig = figure;
        tLayout = tiledlayout(fig, nLightLevels, nFreqs, 'TileSpacing','compact','Padding','compact');
        title(tLayout, sprintf('%s | %s contrast', groupNames{groupIdx}, stimParamLabels{contrastIdx}), 'FontWeight','bold');

        for lightIdx = 1:nLightLevels
            for refFreqIdx = 1:nFreqs

                nexttile(tLayout);
                hold on;

                % Extract pooled data
                uniqueDb = pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).uniqueDb;
                pRespondDifferent = pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).pRespondDifferent;
                nTrials = pooledData(groupIdx, contrastIdx, lightIdx, refFreqIdx).nTrials;

                % Scatter plot with variable marker sizes
                % Marker size logic
                sameIdx = find(uniqueDb == 0);

                markerSizeIdx = zeros(size(nTrials));
                markerSizeIdx((1:end) ~= sameIdx) = ...
                    discretize(nTrials((1:end) ~= sameIdx), 3);
                markerSizeIdx(sameIdx) = 4;

                markerSizeSet = [25, 50, 75, 100];

                % Scatter plot
                for ii = 1:length(uniqueDb)
                    alphaVal = nTrials(ii)/max(nTrials);

                    % Determine shape
                    markerShape = 'o';
                    if uniqueDb(ii) == 0, markerShape = 'diamond'; end   % make the 0 dB case a different shape

                    % Plot with scaled size
                    scatter(uniqueDb(ii), pRespondDifferent(ii), ...
                        markerSizeSet(markerSizeIdx(ii)), ...
                        [pRespondDifferent(ii) 0 1-pRespondDifferent(ii)], 'filled', ...
                        'MarkerEdgeColor','k', 'MarkerFaceAlpha', alphaVal, 'Marker', markerShape);
                end

                % Plot model fit
                fit = sigmaPooled{groupIdx, contrastIdx, lightIdx, refFreqIdx};
                x = -6:0.1:6;
                plot(x, bayesianSameDiffModelTwoSigma(stimParamsDomainList,x,fit,priorSame(groupIdx)), 'k-', 'LineWidth',2);

                ylim([-0.05 1.05]);
                xlim([-6 6]);
                xlabel('stimulus difference [dB]');
                if lightIdx == 1 && refFreqIdx == 1
                    ylabel({'LOW LIGHT', 'proportion respond different'});
                end
                if lightIdx == 2 && refFreqIdx == 1
                    ylabel({'HIGH LIGHT', 'proportion respond different'});
                end
                title(sprintf('%s light | ref %.1f Hz', stimParamLabels{lightIdx}, refFreqHz(refFreqIdx)));
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

    % Build filename
    totalSubjects = length(controlIDs) + length(migraineIDs);
    filename = fullfile(saveDir, [num2str(totalSubjects) '_superSubjSigmaFitsConstrained.mat']);

    save(filename, 'refFreqHz','controlIDs','migraineIDs','fValMatrix','sigmaPooled');

end


%% TESTING fitting with sigmaRef = sigmaTest (one parameter fit)
% Constructing histogram of fVals

% Using the entire sets of nSubj x 4 F values, from migrainers and controls

% Extract by group (keep other dims, then flatten)
fValsControl = fValMatrix(1,:,:,:);
fValsMigraine = fValMatrix(2,:,:,:);

% Convert from cell → numeric and flatten
fValsControl = cell2mat(fValsControl(:));
fValsMigraine = cell2mat(fValsMigraine(:));

% Define shared bin edges
% Use combined data to ensure both histograms share the same scale
allData = [fValsMigraine; fValsControl];
edges = linspace(min(allData), max(allData), 20);

% Overlaid histogram so fancy so pretty
figure; hold on;
h1 = histogram(fValsMigraine, edges, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
h2 = histogram(fValsControl,  edges, 'FaceAlpha', 0.5, 'EdgeColor', 'none');

xlabel('Negative log-likelihood (fVal)');
ylabel('Count');
legend({'Migrainers', 'Controls'});
title('Model fit quality across conditions when sigmaTest = sigmaRef');
box off;

%% Objective function %%
function nll = negLogLikelihood(sigma, stimParamsDomainList, uniqueDbValues, probData, nTrials, priorSame)

% sigmaTest = sigma(1);
% sigmaRef  = sigma(2);
% Sigma is now a single parameter
sigmaTest = sigma(1);
sigmaRef  = sigmaTest;  % always equal

% Predict probability of "different" at each unique dB level
% P_diff = bayesianSameDiffModel(uniqueDbValues, sigma);
P_diff = bayesianSameDiffModelTwoSigma(stimParamsDomainList, uniqueDbValues, [sigmaTest sigmaRef], priorSame);
P_diff = max(min(P_diff, 1 - 1e-9), 1e-9); % To make sure 0 < P_diff < 1

% Finding the count of different responses (aka the number of
% "successes")
k = probData .* nTrials; % prop observed diff multiplied by total number of trials at that dB

% Finding the binomial negative log-likelihood
nll = -sum(k .* log(P_diff) + (nTrials - k) .* log(1 - P_diff));

% Penalty constraint so that sigmaRef <= sigmaTest
% if sigmaRef > sigmaTest
%     penalty = (sigmaRef - sigmaTest) * 1e3;  
%     nll = nll + penalty;
% end

end

