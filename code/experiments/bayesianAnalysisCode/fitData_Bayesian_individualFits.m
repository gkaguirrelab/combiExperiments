% SETUP - defining variables and choosing subject IDs

% Choose whether you want to save the sigma data in a .mat file
saveData = true; 

% Choose whether you want to run migrainer or control subjects
control = true; 

% Defining the directory
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
experimentName = 'DCPT_SDT';

% Define subjects + parameters
if control   % control subject IDs
    subjectID = {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', ...
        'FLIC_0018', 'FLIC_0019','FLIC_0020', 'FLIC_0021', 'FLIC_0022', 'FLIC_0027', ...
        'FLIC_0028','FLIC_0039', 'FLIC_0042', 'FLIC_0049', 'FLIC_0050', 'FLIC_0051'};
else   % migrainer subject IDs
    subjectID = {'FLIC_1016','FLIC_1029','FLIC_1030','FLIC_1031','FLIC_1032', ...
        'FLIC_1034','FLIC_1035','FLIC_1036','FLIC_1038', 'FLIC_1041', 'FLIC_1043',...
        'FLIC_1044', 'FLIC_1046', 'FLIC_1047', 'FLIC_1048'};
end

% Define experimental condition variables 
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

% Initialize matrices of params
% nSubj x 2 x 2 x 5, subj x nContrasts x nLightLevels x nFreqs
sigmaTestMatrix = zeros(nSubj,nContrasts,nLightLevels,nFreqs);
sigmaRefMatrix = zeros(nSubj,nContrasts,nLightLevels,nFreqs);
fValMatrix = zeros(nSubj, nContrasts, nLightLevels, nFreqs);

for subjIdx = 1:nSubj

    thisSubj = subjectID{subjIdx};

    % Create layouts, one per contrast
    figLow = figure;
    tLowContrast = tiledlayout(figLow, nLightLevels, nFreqs, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tLowContrast, ['Low contrast psychometric functions for ' thisSubj], 'FontWeight', 'bold');
    figuresize(1000, 300, 'units', 'pt');

    figHigh = figure;
    tHighContrast = tiledlayout(figHigh, nLightLevels, nFreqs, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tHighContrast, ['High contrast psychometric functions for ' thisSubj], 'FontWeight', 'bold');
    figuresize(1000, 300, 'units', 'pt');

    for lightIdx = 1:nLightLevels

        for refFreqIdx = 1:nFreqs
            currentRefFreq = refFreqHz(refFreqIdx);

            for contrastIdx = 1:nContrasts

                % Pick the correct layout
                if contrastIdx == 1
                    % Low contrast
                    nexttile(tLowContrast);
                else
                    % High contrast
                    nexttile(tHighContrast);
                end
                hold on;

                % Combined trial data for one subj over high and low sides
                comboTrialData = [];
                % Reset lists
                probData = [];
                nTrials = [];
                nTrialsPlot = [];

                for sideIdx = 1:length(stimParamLabels)

                    % Build path to the data file
                    subjectDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, thisSubj);
                    dataDir = fullfile(subjectDir, [modDirection '_ND' NDLabel{lightIdx} '_shifted'], experimentName);

                    fileName = fullfile(dataDir, ...
                        [thisSubj '_' modDirection '_' experimentName ...
                        '_cont-' targetPhotoContrast{contrastIdx} '_refFreq-' num2str(currentRefFreq) 'Hz_' stimParamLabels{sideIdx} '.mat']);

                    if exist(fileName, 'file')
                        load(fileName, 'psychObj');

                        thisTrialData = psychObj.questData.trialData;

                        % Flip the sign for the low side values
                        if contains(fileName, 'lo')
                            for trial = 1:numel(thisTrialData)
                                thisTrialData(trial).stim = -thisTrialData(trial).stim;
                            end
                        end

                        % Append to combined trial data
                        comboTrialData = [comboTrialData; thisTrialData];

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
                    else
                        warning('File not found: %s', fileName);
                    end

                end % sideIdx

                % FIRST, plot the data for this ref freq
                stimCounts = qpCounts(qpData(comboTrialData), templatePsychObj.questData.nOutcomes);
                stim = zeros(length(stimCounts), templatePsychObj.questData.nStimParams);
                pRespondDifferent = zeros(1,length(stimCounts));
                nTrialsPlot = zeros(1,length(stimCounts));

                for cc = 1:length(stimCounts)
                    stim(cc) = stimCounts(cc).stim;
                    nTrialsPlot(cc) = sum(stimCounts(cc).outcomeCounts);
                    pRespondDifferent(cc) = stimCounts(cc).outcomeCounts(2)/nTrialsPlot(cc);
                end

                % Determine marker sizes based on number of trials
                markerSizeIdx = discretize(nTrialsPlot(2:end),3); % divide into 3 bins
                markerSizeIdx = [3 markerSizeIdx]; % keep first point as largest
                markerSizeSet = [25, 50, 100];

                % Plot the points
                for cc = 1:length(stimCounts)
                    if stim(cc) == 0  % make the 0 dB case a different shape
                        markerShape = 'diamond';
                    else
                        markerShape = 'o';
                    end

                    scatter(stim(cc), pRespondDifferent(cc), markerSizeSet(markerSizeIdx(cc)), ...
                        'MarkerFaceColor', [pRespondDifferent(cc) 0 1-pRespondDifferent(cc)], ...
                        'MarkerEdgeColor','k', ...
                        'MarkerFaceAlpha', nTrialsPlot(cc)/max(nTrialsPlot), ...
                        'Marker', markerShape);
                    hold on;
                end

                % SECOND, load data. Compute unique dB values and prob data for this ref freq
                dB_data = [comboTrialData.stim];
                response_data = [comboTrialData.respondYes];
                uniqueDbValues = unique(dB_data);

                % Calculate observed proportion “different” per stim level
                for ii = 1:length(uniqueDbValues)
                    probData(ii) = mean(response_data(dB_data==uniqueDbValues(ii)));
                    nTrials(ii) = sum(dB_data == uniqueDbValues(ii)); % nTrials at each dB
                end

                epsilon = 0.01; % Define the constant lapse rate value

                % Fit the psychometric function
                initialParams = [0.5, 0.5];
                priorSame = 0.5; 

                options = bads('defaults');
                options.MaxIter = 50;
                options.MaxFunEvals = 500;
                lb  = [0.001, 0.001];
                ub  = [5, 5];
                [fit, fbest] = bads(@(p) negLogLikelihood(p, ...
                    stimParamsDomainList, ...
                    uniqueDbValues, ...
                    probData, ...
                    nTrials, ...
                    priorSame), ...
                    initialParams, lb, ub, lb, ub, [], options);

                % Add the fVal and sigma values to the matrix
                fValMatrix(subjIdx, contrastIdx, lightIdx, refFreqIdx) = fbest;
                sigmaTestMatrix(subjIdx, contrastIdx,lightIdx,refFreqIdx) = fit(1);
                sigmaRefMatrix(subjIdx, contrastIdx,lightIdx,refFreqIdx) = fit(2);

                % Plot the fit for this ref frequency
                hold on;

                x = -5:0.1:5;  % evaluate the model at more dB values
                plot(x, bayesianSameDiffModelTwoSigma(stimParamsDomainList,x,fit,priorSame), 'k-', 'LineWidth',2);

                xlabel('stimulus difference [dB]');
                if lightIdx == 1 && refFreqIdx == 1
                    ylabel({'LOW', 'proportion respond different'});
                end
                if lightIdx == 2 && refFreqIdx == 1
                    ylabel({'HIGH', 'proportion respond different'});
                end
                title(sprintf('Ref freq = %.1f Hz', currentRefFreq));
                ylim([-0.1 1.1]);
                xlim([-6.0 6.0]);


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

    % Determine whether the fitting was done for control or migrainer data
    subjNumber = str2double(thisSubj(end-3:end));
    if subjNumber >= 1000
        groupLabel = 'Migrainer';
    else
        groupLabel = 'Control';
    end

    % Build filename
    filename = fullfile(saveDir, [num2str(nSubj) groupLabel '_individualSigmaFits.mat']);

    save(filename, 'refFreqHz','subjectID','fValMatrix','sigmaRefMatrix','sigmaTestMatrix');

end

%% Objective function %%%

function nll = negLogLikelihood(sigma, stimParamsDomainList, uniqueDbValues, probData, nTrials, priorSame)

    % Predict probability of "different" at each unique dB level
    % P_diff = bayesianSameDiffModel(uniqueDbValues, sigma);
    P_diff = bayesianSameDiffModelTwoSigma(stimParamsDomainList, uniqueDbValues, sigma, priorSame);
    P_diff = max(min(P_diff, 1 - 1e-9), 1e-9); % To make sure 0 < P_diff < 1

    % Finding the count of different responses (aka the number of
    % "successes")
    k = probData .* nTrials; % prop observed diff multiplied by total number of trials at that dB
    
    % Finding the binomial negative log-likelihood
    nll = -sum(k .* log(P_diff) + (nTrials - k) .* log(1 - P_diff));

end

