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
subjectID =  {'FLIC_1016','FLIC_1029','FLIC_1030','FLIC_1031','FLIC_1032', ...
'FLIC_1034','FLIC_1035','FLIC_1036','FLIC_1038', 'FLIC_1041', 'FLIC_1043',...
'FLIC_1044', 'FLIC_1046', 'FLIC_1047', 'FLIC_1048'};
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
% In this code, the data is pooled across reference frequencies and sides,
% but not across subjects, contrasts, or light levels. 

% Initialize struct for pooled data
pooledData = struct();

for subjIdx = 1:nSubj
    for contrastIdx = 1:nContrasts
        for lightIdx = 1:nLightLevels
            pooledData(subjIdx, contrastIdx, lightIdx).stim = [];
            pooledData(subjIdx, contrastIdx, lightIdx).respondYes = [];
            pooledData(subjIdx, contrastIdx, lightIdx).uniqueDb = [];
            pooledData(subjIdx, contrastIdx, lightIdx).pRespondDifferent = [];
            pooledData(subjIdx, contrastIdx, lightIdx).nTrials = [];
        end
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

                        pooledData(subjIdx, contrastIdx, lightIdx).stim = ...
                            [pooledData(subjIdx, contrastIdx, lightIdx).stim, [thisTrialData.stim]];

                        pooledData(subjIdx, contrastIdx, lightIdx).respondYes = ...
                            [pooledData(subjIdx, contrastIdx, lightIdx).respondYes, [thisTrialData.respondYes]];

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
    for contrastIdx = 1:nContrasts
        for lightIdx = 1:nLightLevels

            % Load in the data for this contrast and light idx combo
            dB = pooledData(subjIdx, contrastIdx, lightIdx).stim;
            respondYes = pooledData(subjIdx, contrastIdx, lightIdx).respondYes;

            uniqueDb = unique(dB);
            pRespondDifferent = zeros(size(uniqueDb));
            nTrials  = zeros(size(uniqueDb));

            for ii = 1:length(uniqueDb)
                pRespondDifferent(ii) = mean(respondYes(dB == uniqueDb(ii)));
                nTrials(ii) = sum(dB == uniqueDb(ii)); % nTrials at each dB
            end

            % Save in pooled data struct
            pooledData(subjIdx, contrastIdx, lightIdx).uniqueDb = uniqueDb;
            pooledData(subjIdx, contrastIdx, lightIdx).pRespondDifferent = pRespondDifferent;
            pooledData(subjIdx, contrastIdx, lightIdx).nTrials = nTrials;

            % Summing trials for the prior probability of same
            sameIdx = find(uniqueDb == 0); % Find the index of the zero dB point
            nDiffTrials = nDiffTrials + sum(nTrials(1:(sameIdx-1))) + sum(nTrials((sameIdx+1):end));
            nSameTrials = nSameTrials + nTrials(sameIdx);

        end
    end
end

% Global prior calculation once all trials are summed
priorSame = nSameTrials/(nSameTrials + nDiffTrials);

sigmaPooled = cell(nSubj, nContrasts, nLightLevels);
fValPooled = cell(nSubj, nContrasts, nLightLevels);
% Now fit the psychometric function
for subjIdx = 1:nSubj
    for contrastIdx = 1:nContrasts
        for lightIdx = 1:nLightLevels

            uniqueDb = pooledData(subjIdx, contrastIdx, lightIdx).uniqueDb;
            pRespondDifferent = pooledData(subjIdx, contrastIdx, lightIdx).pRespondDifferent;
            nTrials = pooledData(subjIdx, contrastIdx, lightIdx).nTrials;

            initialSigmas = [1 1];
            lb = [0.001 0.001];
            ub = [5 5];

            options = bads('defaults');
            options.MaxIter = 100;

            [fit, fVal] = bads(@(p) negLogLikelihood(p, uniqueDb, pRespondDifferent, nTrials, priorSame), ...
                initialSigmas, lb, ub, lb, ub, [], options);

            sigmaPooled{subjIdx, contrastIdx, lightIdx} = fit;
            fValPooled{subjIdx, contrastIdx, lightIdx} = fVal;

        end
    end
end

% PLOTTING: plot pooled fit on pooled data
% One figure per subject
for subjIdx = 1:nSubj

    figure;
    t = tiledlayout(nContrasts, nLightLevels, ...
        'TileSpacing','compact','Padding','compact');
    title(t, [subjectID{subjIdx} ' Data']); 

    for contrastIdx = 1:nContrasts
        for lightIdx = 1:nLightLevels

            nexttile; hold on;

            uniqueDb = pooledData(subjIdx, contrastIdx, lightIdx).uniqueDb;
            pRespondDifferent = pooledData(subjIdx, contrastIdx, lightIdx).pRespondDifferent;
            nTrials = pooledData(subjIdx, contrastIdx, lightIdx).nTrials;

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
            fit = sigmaPooled{subjIdx, contrastIdx, lightIdx};
            x = -6:0.1:6;

            plot(x, bayesianSameDiffModelTwoSigma(x, fit, priorSame), ...
                'k-', 'LineWidth', 2);

            % Labels
            ylim([-0.05 1.05]);
            xlim([-6 6]);
            xlabel('stimulus difference [dB]');
            ylabel('proportion respond different');

            title(sprintf('%s contrast | %s', ...
                stimParamLabels{contrastIdx}, lightParamLabels{lightIdx}));

        end
    end
end

%% Plotting sigma parameters for each contrast x light level condition
% Bar plot

% Creating sigma matrices
% Dimensions: subj × contrast × light
sigmaControl = nan(nSubj, nContrasts, nLightLevels);
sigmaZeroControl = nan(nSubj, nContrasts, nLightLevels);
sigmaMigraine = nan(nSubj, nContrasts, nLightLevels);
sigmaZeroMigraine = nan(nSubj, nContrasts, nLightLevels);

for subjIdx = 1:nSubj
    for contrastIdx = 1:nContrasts
        for lightIdx = 1:nLightLevels
            fitControl = sigmaPooledControl{subjIdx, contrastIdx, lightIdx};
            sigmaControl(subjIdx, contrastIdx, lightIdx)  = fitControl(1);
            sigmaZeroControl(subjIdx, contrastIdx, lightIdx) = fitControl(2);
            fitMigraine = sigmaPooledMigraine{subjIdx, contrastIdx, lightIdx};
            sigmaMigraine(subjIdx, contrastIdx, lightIdx)  = fitMigraine(1);
            sigmaZeroMigraine(subjIdx, contrastIdx, lightIdx) = fitMigraine(2);
        end
    end
end

nCond = nContrasts * nLightLevels;

% subj × condition
sigmaControlMat      = reshape(sigmaControl,      nSubj, nCond);
sigmaZeroControlMat  = reshape(sigmaZeroControl,  nSubj, nCond);
sigmaMigraineMat     = reshape(sigmaMigraine,     nSubj, nCond);
sigmaZeroMigraineMat = reshape(sigmaZeroMigraine, nSubj, nCond);

% calculate mean and SEM 
mu_sigma_ctrl  = mean(sigmaControlMat,  1);
mu_sigma_mig   = mean(sigmaMigraineMat, 1);
sem_sigma_ctrl = std(sigmaControlMat,  [], 1) ./ sqrt(nSubj);
sem_sigma_mig  = std(sigmaMigraineMat, [], 1) ./ sqrt(nSubj);

mu_sigma0_ctrl  = mean(sigmaZeroControlMat,  1);
mu_sigma0_mig   = mean(sigmaZeroMigraineMat, 1);
sem_sigma0_ctrl = std(sigmaZeroControlMat,  [], 1) ./ sqrt(nSubj);
sem_sigma0_mig  = std(sigmaZeroMigraineMat, [], 1) ./ sqrt(nSubj);

% Condition labels
condLabels = cell(1, nCond);
c = 1;
for contrastIdx = 1:nContrasts
    for lightIdx = 1:nLightLevels
        condLabels{c} = sprintf('%s | ND %s', ...
            stimParamLabels{contrastIdx}, NDLabel{lightIdx});
        c = c + 1;
    end
end

% Plot sigma (control v migraine)
figure; hold on;

barData = [mu_sigma_ctrl; mu_sigma_mig]';
b = bar(barData, 'grouped');

% Colors (optional)
b(1).FaceColor = [0.3 0.3 0.8];  % Control
b(2).FaceColor = [0.8 0.3 0.3];  % Migraine

% Error bars
ngroups = nCond;
nbars   = 2;
groupwidth = min(0.8, nbars/(nbars+1.5));

for ii = 1:nbars
    x = (1:ngroups) - groupwidth/2 + (2*ii-1)*groupwidth/(2*nbars);
    if ii == 1
        errorbar(x, mu_sigma_ctrl, sem_sigma_ctrl, 'k', 'linestyle','none');
    else
        errorbar(x, mu_sigma_mig, sem_sigma_mig, 'k', 'linestyle','none');
    end
end

% X tick labels = light level (top row)
lightLabels = repmat(lightParamLabels, 1, nContrasts);
set(gca,'XTick',1:nCond,'XTickLabel',lightLabels);
ylabel('sigma test');
ylim([0 2.5]);
legend({'Control','Migraine'}, 'Location','Northwest');
title('sigma test by contrast × light');
box off;
% Add contrast labels underneath
ax = gca;

% Normalized x positions of contrast centers
xLow  = (mean(1:nLightLevels) - 0.5) / nCond;
xHigh = (mean((nLightLevels+1):nCond) - 0.5) / nCond;

% Y position BELOW the axis (negative = below)
yText = -0.07;

text(ax, xLow,  yText, 'low contrast', ...
    'Units','normalized', ...
    'HorizontalAlignment','center', ...
    'VerticalAlignment','top', ...
    'FontWeight','bold', ...
    'FontSize', 12);

text(ax, xHigh, yText, 'high contrast', ...
    'Units','normalized', ...
    'HorizontalAlignment','center', ...
    'VerticalAlignment','top', ...
    'FontWeight','bold', ...
    'FontSize', 12);

ax.Clipping = 'off';
ax.Position(2) = ax.Position(2) + 0.01;   % move axes up
ax.Position(4) = ax.Position(4) - 0.01;   % shrink height

% Plot sigma zero (control v migraine)
figure; hold on;

barData = [mu_sigma0_ctrl; mu_sigma0_mig]';
b = bar(barData, 'grouped');

b(1).FaceColor = [0.3 0.3 0.8];
b(2).FaceColor = [0.8 0.3 0.3];

for ii = 1:nbars
    x = (1:nCond) - groupwidth/2 + (2*ii-1)*groupwidth/(2*nbars);
    if ii == 1
        errorbar(x, mu_sigma0_ctrl, sem_sigma0_ctrl, 'k', 'linestyle','none');
    else
        errorbar(x, mu_sigma0_mig, sem_sigma0_mig, 'k', 'linestyle','none');
    end
end

% X tick labels = light level (top row)
lightLabels = repmat(lightParamLabels, 1, nContrasts);
set(gca,'XTick',1:nCond,'XTickLabel',lightLabels);
ylabel('sigma ref');
ylim([0 2.5]);
legend({'Control', 'Migraine'}, 'Location','Northwest');
title('sigma ref by contrast × light');
box off;
% Add contrast labels underneath
ax = gca;

% Normalized x positions of contrast centers
xLow  = (mean(1:nLightLevels) - 0.5) / nCond;
xHigh = (mean((nLightLevels+1):nCond) - 0.5) / nCond;

% Y position BELOW the axis (negative = below)
yText = -0.07;

text(ax, xLow,  yText, 'low contrast', ...
    'Units','normalized', ...
    'HorizontalAlignment','center', ...
    'VerticalAlignment','top', ...
    'FontWeight','bold', ...
    'FontSize', 12);

text(ax, xHigh, yText, 'high contrast', ...
    'Units','normalized', ...
    'HorizontalAlignment','center', ...
    'VerticalAlignment','top', ...
    'FontWeight','bold', ...
    'FontSize', 12);

ax.Clipping = 'off';
ax.Position(2) = ax.Position(2) + 0.01;   % move axes up
ax.Position(4) = ax.Position(4) - 0.01;   % shrink height

%% Plotting the F values from fitting the migraine and control subjects
% Using the entire sets of nSubj x 4 F values, from migrainers and controls

% Migrainers
fValsMigraine = cell2mat(fValPooledMigraine(:));
% Control
fValsControl = cell2mat(fValPooledControl(:));

% Define shared bin edges
edges = linspace(min([fValsMigraine; fValsControl]), ...
                 max([fValsMigraine; fValsControl]), 20);

% Overlaid histogram
figure; hold on

histogram(fValsMigraine, edges, ...
    'FaceAlpha',0.5, ...
    'EdgeColor','none');

histogram(fValsControl, edges, ...
    'FaceAlpha',0.5, ...
    'EdgeColor','none');

xlabel('Negative log-likelihood (fVal)')
ylabel('Count')
legend({'Migrainers','Controls'})
title('Model fit quality across groups')

box off

%% Omnibus ANOVA 
% Group × Contrast × Light mixed ANOVA, with subjects nested in group

sigmaPooledMigraine = load([getpref("lightLoggerAnalysis", 'dropboxBaseDir'), '/FLIC_analysis/dichopticFlicker/sigmaData/15MigraineSigmasNOTSubjPooled.mat'], 'sigmaPooled').sigmaPooled;
sigmaPooledControl = load([getpref("lightLoggerAnalysis", 'dropboxBaseDir'), '/FLIC_analysis/dichopticFlicker/sigmaData/15ControlSigmasNOTSubjPooled.mat'], 'sigmaPooled').sigmaPooled;

sigmaTestPooledMigraine = cellfun(@(x) x(1), sigmaPooledMigraine);
sigmaZeroPooledMigraine = cellfun(@(x) x(2), sigmaPooledMigraine);
sigmaTestPooledControl = cellfun(@(x) x(1), sigmaPooledControl);
sigmaZeroPooledControl = cellfun(@(x) x(2), sigmaPooledControl);
nControl = size(sigmaTestPooledControl,1);
nMigraine = size(sigmaTestPooledMigraine,1);

% Combine subjects. Data are now subj x contrast x light level x group
sigmaAll = [sigmaTestPooledMigraine; sigmaTestPooledControl];
sigmaZeroAll = [sigmaZeroPooledMigraine; sigmaZeroPooledControl];

[nS, nC, nL] = size(sigmaAll); % Subjects, Contrasts, LightLevels

% Create Factor Vectors using ndgrid 
% This creates coordinate matrices matching the size of sigmaAll
[S_idx, C_idx, L_idx] = ndgrid(1:nS, 1:nC, 1:nL);

% Create Group Vector
G_idx = ones(nS, nC, nL);
G_idx((nMigraine+1):end, :, :) = 2; % Subjects 16-30 are Control

% Participants are nested within groups
nest = zeros(4,4);
nest(1,2) = 1;   % subject nested in group

% Participants as random
[panova, output.anova, anova_table] = anovan(sigmaAll(:), {subjMatrix(:), ...
    groupMtrx(:), contrastMtrx(:), lightLevelMtrx(:)}, 'nested', nest, ...
    'random', 1, 'model', 'full', 'varnames', {'subject', 'group'...
    'contrast', 'light level'}, 'display', 'on');

% Participants as random
[panova, output.anovaZero, anova_table] = anovan(sigmaZeroAll(:), {subjMatrix(:), ...
    groupMtrx(:), contrastMtrx(:), lightLevelMtrx(:)}, 'nested', nest, ...
    'random', 1, 'model', 'full', 'varnames', {'subject', 'group'...
    'contrast', 'light level'}, 'display', 'on');

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

