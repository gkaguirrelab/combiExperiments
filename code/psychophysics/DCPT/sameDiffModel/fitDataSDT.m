% Defining the directory
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
experimentName = 'DCPT_SDT';

% Define subjects + parameters
subjectID = {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', 'FLIC_0018', 'FLIC_0020', ...
    'FLIC_0021', 'FLIC_0022'};
modDirection = 'LightFlux';
NDLabel = {'3x0', '0x5'};   % Options are {'3x0', '0x5'}
stimParamLabels = {'low', 'hi'}; % {'low', 'hi'}
refFreqHz = logspace(log10(10),log10(30),5);  % logspace(log10(10),log10(30),5)
targetPhotoContrast = '0x3';  % {'0x1','0x3'}

% Create tiled figure
figHandle = figure('Visible', true);
nFreqs = length(refFreqHz);
t = tiledlayout(figHandle, 1, nFreqs, 'TileSpacing', 'compact', 'Padding', 'compact');
figuresize(1000, 300, 'units', 'pt');  
title(t, 'Psychometric functions, combined across subjects', 'FontWeight', 'bold');

for refFreqIdx = 1:nFreqs
    nexttile(refFreqIdx);
    hold on;
    currentRefFreq = refFreqHz(refFreqIdx);

    % Initialize combined trial data for this ref frequency
    comboTrialData = [];

    for subjIdx = 1:length(subjectID)   % Loop over subjs and combine their trial data
        subj = subjectID{subjIdx};

        for sideIdx = 1:length(stimParamLabels)

            % Build path to the data file
            subjectDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, subj);
            dataDir = fullfile(subjectDir, [modDirection '_ND' NDLabel{2} '_shifted'], experimentName);

            fileName = fullfile(dataDir, ...
                [subj '_' modDirection '_' experimentName ...
                '_cont-' targetPhotoContrast '_refFreq-' num2str(currentRefFreq) 'Hz_' stimParamLabels{sideIdx} '.mat']);

            if exist(fileName, 'file')
                load(fileName, 'psychObj');

                thisTrialData = psychObj.questData.trialData;

                if contains(fileName, 'lo')
                    for trial = 1:numel(thisTrialData)
                        thisTrialData(trial).stim = -thisTrialData(trial).stim;
                    end
                end

                % Append to combined trial data
                comboTrialData = [comboTrialData; thisTrialData];

                % Store one psychObj as template if needed
                if subjIdx == 1 && sideIdx == 1
                    templatePsychObj = psychObj;
                end
            else
                warning('File not found: %s', fileName);
            end

        end
    end % subjIdx

    % FIRST, plot group-level data
    % Compute group-level counts
    stimCounts = qpCounts(qpData(comboTrialData), templatePsychObj.questData.nOutcomes);
    stim = zeros(length(stimCounts), templatePsychObj.questData.nStimParams);
    pRespondDifferent = zeros(1,length(stimCounts));
    nTrials = zeros(1,length(stimCounts));

    for cc = 1:length(stimCounts)
        stim(cc) = stimCounts(cc).stim;
        nTrials(cc) = sum(stimCounts(cc).outcomeCounts);
        pRespondDifferent(cc) = stimCounts(cc).outcomeCounts(2)/nTrials(cc);
    end

    % Determine marker sizes based on number of trials
    markerSizeIdx = discretize(nTrials(2:end),3); % divide into 3 bins
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
            'MarkerFaceAlpha', nTrials(cc)/max(nTrials), ...
            'Marker', markerShape);
        hold on;
    end

    % SECOND, load data for fitting
    dB_data = [comboTrialData.stim];
    response_data = [comboTrialData.respondYes];
    uniqueDbValues = unique(dB_data);

    % split positive and negative values
    posDbValues = uniqueDbValues(uniqueDbValues >= 0);
    negDbValues = uniqueDbValues(uniqueDbValues <= 0);

    % Initialize variables for current ref freq
    nTrialsPos = zeros(size(posDbValues));
    probDataPos = zeros(size(posDbValues));
    nTrialsNeg = zeros(size(negDbValues));
    probDataNeg = zeros(size(negDbValues));

    % Calculate observed proportion “different” per stim level
    for ii = 1:length(uniqueDbValues)
        probData(ii) = mean(response_data(dB_data==uniqueDbValues(ii)));
        nTrials(ii) = sum(dB_data == uniqueDbValues(ii)); % nTrials at each dB
    end
    for ii = 1:length(posDbValues)
        probDataPos(ii) = mean(response_data(dB_data==posDbValues(ii)));
        nTrialsPos(ii) = sum(dB_data == posDbValues(ii)); % nTrials at each pos dB
    end
    for ii = 1:length(negDbValues)
        probDataNeg(ii) = mean(response_data(dB_data==negDbValues(ii)));
        nTrialsNeg(ii) = sum(dB_data == negDbValues(ii)); % nTrials at each neg dB
    end

    % Fit the group-level psychometric function
    % Best initial params for Euclidean error (not split by side) are: sigma = .3, 
    % crit_baseline = 2, m = 1.45, and x_limit = 1
    pos_initial_params = [1.6002,1.4479,0.25,0.6];
    neg_initial_params = [1.2940,1.5,0.33,0.7];
    options = bads('defaults');
    options.MaxIter = 500;
    options.MaxFunEvals = 5000;
    lb = [0,0,0.1,0]; ub = [100,5,10,3];

    posFit = bads(@(p) negLogLikelihood(p,posDbValues,probDataPos,nTrialsPos), ...
        pos_initial_params, lb, ub, lb, ub, [], options);
    negFit = bads(@(p) negLogLikelihood(p,negDbValues,probDataNeg,nTrialsNeg), ...
        neg_initial_params, lb, ub, lb, ub, [], options);

    % Plot fitted curve (predicted probabilities using fitted parameters) 
    hold on;
    plot(posDbValues, modifiedSameDiffModel(posDbValues,posFit), 'k-', 'LineWidth',2);
    plot(negDbValues, modifiedSameDiffModel(negDbValues,negFit), 'k-', 'LineWidth',2);

    xlabel('stimulus difference [dB]');
    ylabel('proportion respond different');
    title(sprintf('Ref freq = %.1f Hz', currentRefFreq));
    ylim([-0.1 1.1]);
    xlim([-6.0 6.0]);

end % refFreqIdx


%%% Objective functions %%%

function error = euclideanError(params, uniqueDbValues, probData, nTrials)
    
    % Predict probability of "different" at each unique dB level
    P_diff = modifiedSameDiffModel(uniqueDbValues, params);
    P_diff = max(min(P_diff, 1 - 1e-9), 1e-9); % To make sure 0 < P_diff < 1

    % Create weights and artifically boost trials close to 0 dB
    boostIdx = abs(uniqueDbValues) > 0 & abs(uniqueDbValues) < 0.9;
    nTrials(boostIdx) = 10 * nTrials(boostIdx);
    w = nTrials / sum(nTrials); % Normalization

    % Compute error as the norm of the vector of the differences between the observed and
    % modeled proportion "different" responses
    diffVec = probData - P_diff;  
    weightedDiffVec = w .* diffVec;  % Weighted diffs

    error = norm(weightedDiffVec); 

end

function nll = negLogLikelihood(params, uniqueDbValues, probData, nTrials)

    % Predict probability of "different" at each unique dB level
    P_diff = modifiedSameDiffModel(uniqueDbValues, params);
    P_diff = max(min(P_diff, 1 - 1e-9), 1e-9); % To make sure 0 < P_diff < 1

    % Finding the count of different responses (aka the number of
    % "successes")
    k = probData .* nTrials; % prop observed diff multiplied by total number of trials at that dB

    % Create weights and artifically boost trials close to 0 dB
    weights = ones(size(uniqueDbValues));
    mask = (abs(uniqueDbValues) > 0) & (abs(uniqueDbValues) < 0.9) & (probData < 0.1);
    weights(mask) = 20;
    
    % Finding the binomial negative log-likelihood
    nll = -sum(weights .* (k .* log(P_diff) + (nTrials - k) .* log(1 - P_diff)));
    % Try out version with all 4 possibilities

end

