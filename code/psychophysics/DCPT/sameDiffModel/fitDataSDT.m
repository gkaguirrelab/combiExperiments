% Defining the directory
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
experimentName = 'DCPT_SDT';

% Define subjects + parameters
% List of possible subject IDs: {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', ...
% 'FLIC_0018', 'FLIC_0020', 'FLIC_0021', 'FLIC_0022'};
subjectID = {'FLIC_0013'};
modDirection = 'LightFlux';
NDLabel = {'0x5'};   % {'3x0', '0x5'}
stimParamLabels = {'low', 'hi'}; % {'low', 'hi'}
refFreqHz = logspace(log10(10),log10(30),5);  % logspace(log10(10),log10(30),5)
targetPhotoContrast = '0x3';  % {'0x1','0x3'}

% Create tiled figure
figHandle = figure('Visible', true);
nFreqs = length(refFreqHz);
t = tiledlayout(figHandle, 1, nFreqs, 'TileSpacing', 'compact', 'Padding', 'compact');
figuresize(1000, 300, 'units', 'pt');  
title(t, ['Psychometric functions for ' subjectID{1}], 'FontWeight', 'bold');

% Initialize cell arrays
uniqueDbValues = cell(1,nFreqs);
probData = cell(1,nFreqs);
nTrials = cell(1,nFreqs);

% Combined trial data for one subj across all reference freqs
comboTrialData = [];

for refFreqIdx = 1:nFreqs
    nexttile(refFreqIdx);
    hold on;
    currentRefFreq = refFreqHz(refFreqIdx);

    for sideIdx = 1:length(stimParamLabels)

        % Build path to the data file
        subjectDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, subj);
        dataDir = fullfile(subjectDir, [modDirection '_ND' NDLabel{1} '_shifted'], experimentName);

        fileName = fullfile(dataDir, ...
            [subj '_' modDirection '_' experimentName ...
            '_cont-' targetPhotoContrast '_refFreq-' num2str(currentRefFreq) 'Hz_' stimParamLabels{sideIdx} '.mat']);

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

    % SECOND, load data. Compute unique dB values and prob data for this ref freq
    dB_data = [comboTrialData.stim];
    response_data = [comboTrialData.respondYes];
    currentUniqueDbValues = unique(dB_data);

    % Calculate observed proportion “different” per stim level
    for ii = 1:length(currentUniqueDbValues)
        thisProbData(ii) = mean(response_data(dB_data==currentUniqueDbValues(ii)));
        thisNTrials(ii) = sum(dB_data == currentUniqueDbValues(ii)); % nTrials at each dB
    end

    % Store in cell arrays
    uniqueDbValues{refFreqIdx} = currentUniqueDbValues;
    probData{refFreqIdx} = thisProbData;
    nTrials{refFreqIdx} = thisNTrials;

end % refFreqIdx

% Fit the psychometric function
% initial_params = [m, x_limit, crit_baseline1, sigma1, ...,
% crit_baseline5, sigma5]
initial_params = [1.6002,1.4479,0.25,0.6,1.6002,1.4479,0.25,0.6, ...
                  1.6002,1.4479,0.25,0.6];
options = bads('defaults');
options.MaxIter = 500;
options.MaxFunEvals = 5000;
lb = [0,0,0.1,0]; ub = [100,5,10,3];

fit = bads(@(p) negLogLikelihood(p,uniqueDbValues,probData,nTrials), ...
    initial_params, lb, ub, lb, ub, [], options);
    
% Plot fitted curve 
hold on;
for refFreqIdx = 1:nFreqs
   
  %  plot(uniqueDbValues, modifiedSameDiffModel(uniqueDbValues,fit), 'k-', 'LineWidth',2);

    xlabel('stimulus difference [dB]');
    ylabel('proportion respond different');
    title(sprintf('Ref freq = %.1f Hz', currentRefFreq));
    ylim([-0.1 1.1]);
    xlim([-6.0 6.0]);

end % refFreqIdx


%%% Objective function %%%

function nll = negLogLikelihood(params, uniqueDbValues, probData, nTrials)
    
    nFreqs = length(uniqueDbValues);
    each_nll = zeros(1, nFreqs);
    
    for refFreqIdx = 1:nFreqs  % Looping through each ref freq

        crit_baseline_idx = refFreqIdx*2+1; 
        sigma_idx = refFreqIdx*2+2; 
        theseParams = params(1, 2, crit_baseline_idx, sigma_idx);
        % Predict probability diff at each unique dB level, for this freq
        P_diff = modifiedSameDiffModel(uniqueDbValues{refFreqIdx}, theseParams);
        P_diff = max(min(P_diff, 1 - 1e-9), 1e-9); % To make sure 0 < P_diff < 1
    
        % Trial counts for this frequency
        k = probData{refFreqIdx} .* nTrials{refFreqIdx}; % count of diff responses
        N = nTrials{refFreqIdx};
        
        % Binomial log likelihood for this frequency
        thisNLL = -sum(k .* log(P_diff) + (N - k) .* log(1 - P_diff));

        % Store in list
        each_nll(refFreqIdx) = thisNLL; 

    end
    
    % Total nll across all frequencies
    nll = sum(each_nll);

end

