% SETUP
% Defining the directory
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
experimentName = 'DCPT_SDT';

% Define subjects + parameters
% Control subject IDs: {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', ...
% 'FLIC_0018', 'FLIC_0019','FLIC_0020', 'FLIC_0021', 'FLIC_0022', 'FLIC_0027', 
% 'FLIC_0028','FLIC_0039', 'FLIC_0042'};
% Migraine subject IDs: {'FLIC_1016','FLIC_1029','FLIC_1030','FLIC_1031',
%                         'FLIC_1034','FLIC_1038', 'FLIC_1041'}; 
% Had to take out 'FLIC_0028' for controls bc haven't done the fitting with her
subjectID = {'FLIC_0013'};
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
sigmaMatrix = zeros(nSubj,nContrasts,nLightLevels,nFreqs);
critBaselineMatrix = zeros(nSubj,nContrasts,nLightLevels,nFreqs);

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

                        % Store one psychObj as template if needed
                        if refFreqIdx == 1 && sideIdx == 1
                            templatePsychObj = psychObj;
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
                % initial_params = [m, x_limit, crit_baseline, sigma]
                initial_params = [0,1,2,0.5];
                sigma = 0.5; 

                options = bads('defaults');
                options.MaxIter = 50;
                options.MaxFunEvals = 500;
                % lb = [0,1,0,0.001]; ub = [0,1,5,3];
                lb = 0.001; ub = 2;
                fit = bads(@(p) negLogLikelihood(p,uniqueDbValues,probData,nTrials), ...
                    sigma, lb, ub, lb, ub, [], options);

                % Add the crit_baseline and sigma values to the matrix
                sigmaMatrix(subjIdx, contrastIdx,lightIdx,refFreqIdx) = fit;
              %  critBaselineMatrix(subjIdx, contrastIdx,lightIdx,refFreqIdx) = fit(3);

                % Plot the fit for this ref frequency
                hold on;

                x = -5:0.1:5;  % evaluate the model at more dB values
                plot(x, bayesianSameDiffModel(x,fit), 'k-', 'LineWidth',2);

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

%% Objective function %%%

function nll = negLogLikelihood(sigma, uniqueDbValues, probData, nTrials)

    % Predict probability of "different" at each unique dB level
    P_diff = bayesianSameDiffModel(uniqueDbValues, sigma);
    P_diff = max(min(P_diff, 1 - 1e-9), 1e-9); % To make sure 0 < P_diff < 1

    % Finding the count of different responses (aka the number of
    % "successes")
    k = probData .* nTrials; % prop observed diff multiplied by total number of trials at that dB
    
    % Finding the binomial negative log-likelihood
    nll = -sum(k .* log(P_diff) + (nTrials - k) .* log(1 - P_diff));

end

