dropBoxBaseDir=getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir='FLIC_data';
projectName='combiLED';
experimentName = 'DCPT_SDT';
% % Define the modulation and data directories
subjectDir = fullfile(...
    dropBoxBaseDir,...
    dropBoxSubDir,...
    projectName,...
    'FLIC_0015');

file = [subjectDir, '/LightFlux_ND0x5_shifted/DCPT_SDT/FLIC_0015_LightFlux_DCPT_SDT_cont-0x3_refFreq-17.3205Hz_hi.mat'];
load(file,'psychObj');
obj = psychObj; 

% Grab some variables
questData = obj.questData;
stimParamsDomainList = obj.stimParamsDomainList;
nTrials = length(obj.questData.trialData);

% Set up a figure
figHandle = figure('visible',true);
figuresize(750,250,'units','pt');

% Get the proportion respond "different" for each stimulus
stimCounts = qpCounts(qpData(questData.trialData),questData.nOutcomes);
stim = zeros(length(stimCounts),questData.nStimParams);
for cc = 1:length(stimCounts)
    stim(cc) = stimCounts(cc).stim;
    nTrials(cc) = sum(stimCounts(cc).outcomeCounts);
    pRespondDifferent(cc) = stimCounts(cc).outcomeCounts(2)/nTrials(cc);
end

% Plot these. Use a different marker for the 0 dB case
markerSizeIdx = discretize(nTrials(2:end),3);
markerSizeIdx = [3 markerSizeIdx];
markerSizeSet = [25,50,100];
for cc = 1:length(stimCounts)
    if cc == 1
        scatter(stim(cc),pRespondDifferent(cc),markerSizeSet(markerSizeIdx(cc)),'diamond', ...
            'MarkerFaceColor',[pRespondDifferent(cc) 0 1-pRespondDifferent(cc)], ...
            'MarkerEdgeColor','k', ...
            'MarkerFaceAlpha',nTrials(cc)/max(nTrials));
    else
        scatter(stim(cc),pRespondDifferent(cc),markerSizeSet(markerSizeIdx(cc)),'o', ...
            'MarkerFaceColor',[pRespondDifferent(cc) 0 1-pRespondDifferent(cc)], ...
            'MarkerEdgeColor','k', ...
            'MarkerFaceAlpha',nTrials(cc)/max(nTrials));
    end
    hold on
end

% Labels and range
ylim([-0.1 1.1]);
xlabel('stimulus difference [dB]')
ylabel('proportion respond different')
title('Psychometric function');

% "FINAL WORKING CODE STRUCTURE"
% Load real data
dB_data = questData.trialData.stim;          % vector of dB differences
response_data = [questData.trialData.respondYes]; % 0 = "Same", 1 = "Different"

% Set initial sigma and criterion baseline (the flat part of the criterion
% function)
sigma = 1;
crit_baseline = 2; 
m = 0.4;
x_limit = 2.5; % db value where the v starts dipping down


lb = [0, 0, 0.1, 0.01]; % lower bounds for m, crit_baseline, x_limit, sigma
ub = [Inf, Inf, 4, 10]; % upper bounds

opts = optimoptions('fmincon','Display','iter','Algorithm','sqp');
% Run MLE to minimize negative log likelihood
best_params = fmincon(@(p) neg_log_likelihood(p, dB_data, response_data), ...
                      initial_params, [], [], [], [], lb, ub, [], opts);

disp(['Best fit: m = ', num2str(best_params(1)), ', critBaseline = ', num2str(best_params(2))]);

% Compute predicted probabilities using fitted parameters
for i = 1:length(dB_range)
    dB_val = dB_range(i);
    c_val(i) = criterion(dB_val, best_params(1), best_params(2), best_params(3));
    predicted_P_diff(i) = compute_P_different(dB_val, sigma, c_val(i));
end

% Plot the fitted curve
plot(dB_range, predicted_P_diff, 'k-', 'LineWidth', 2);
legend({'Observed data', 'Fitted psychometric function'}, 'Location', 'Best');

figure;
plot(dB_range, c_val, 'ko', 'LineWidth', 2);

function c = criterion(dB_value, m, crit_baseline, x_limit)
    % Determining criterion values under the hypothesis that is
    % shrinks for dB values closer to 0    
    if abs(dB_value) <= x_limit
        c = crit_baseline - m * (x_limit - abs(dB_value));
    else
        c = crit_baseline;
    end
end

function P_diff = compute_P_different(dB_value, sigma, c)

    % Parameters
    mu_R = 0;     % mean of reference
    mu_T = dB_value;     % mean of test

    % Function for the joint PDF f(mR, mT)
    f = @(mR, mT) normpdf(mR, mu_R, sigma) .* normpdf(mT, mu_T, sigma);
    
    % The integral limits are defined by the criterion: mR - c <= mT <= mR + c
    
    mR_min = -inf;
    mR_max = inf;
    
    % Lower limit for mT: g(mR) = mR - c
    g = @(mR) mR - c;
    
    % Upper limit for mT: h(mR) = mR + c
    h = @(mR) mR + c;
    
    try
        P_same_integral2 = integral2(f, mR_min, mR_max, g, h);
    catch
        P_same_integral2 = NaN;
    end
    
    P_diff = 1 - P_same_integral2;

end

function nll = neg_log_likelihood(params, dB_data, response_data)
    m = params(1);
    crit_baseline = params(2);
    x_limit = params(3);
    sigma = params(4);


    nll = 0;

     if sigma <= 0
        nll = Inf;
        return;
    end
    
    for i = 1:length(dB_data)
        dB_value = dB_data(i);
        response = response_data(i);  % 1 = "Different", 0 = "Same"
    
        c = criterion(dB_value, m, crit_baseline, x_limit);
        P_diff = compute_P_different(dB_value, sigma, c);
    
        % Clamp probabilities to avoid log(0)
        P_diff = max(min(P_diff, 1 - 1e-9), 1e-9);
        P_same = 1 - P_diff;
    
        % Add log likelihood for this trial
        if response == 1
            nll = nll - log(P_diff);
        else
            nll = nll - log(P_same);
        end
    end
end




% subjectID = {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', 'FLIC_0018'};
% refFreqSetHz = logspace(log10(10),log10(30),5);
% modDirections = {'LightFlux'};
% targetPhotoContrast = [0.10; 0.30];  % [Low contrast levels; high contrast levels]
% % Light Flux is [0.10; 0.30]
% NDLabel = {'3x0', '0x5'};
% 
% dropBoxBaseDir=getpref('combiExperiments','dropboxBaseDir');
% dropBoxSubDir='FLIC_data';
% projectName='combiLED';
% experimentName = 'DCPT_SDT';
% 
% % Set the labels for the high and low stimulus ranges
% stimParamLabels = {'low', 'hi'};
% lightLevelLabels = {'Low Light', 'High Light'}; % to be used only for the title
% 
% % Set number of contrast levels and sides
% nContrasts = 2;
% nSides = 2;
% nSubjects = length(subjectID);
% 
% % Define the modulation and data directories
% subjectDir = fullfile(...
%     dropBoxBaseDir,...
%     dropBoxSubDir,...
%     projectName,...
%     subjectID);
% 
% for lightIdx = 1:length(NDLabel)
% 
%     % Set up a figure
%     figHandle = figure(lightIdx);
%     figuresize(750,1200,'units','pt')
% 
%     tcl = tiledlayout(length(refFreqSetHz),nContrasts);
%     title(tcl, [lightLevelLabels{lightIdx} ' with Photo Contrasts: ' num2str(targetPhotoContrast(1)) ', ' num2str(targetPhotoContrast(2))]);
% 
%     for freqIdx = 1:length(refFreqSetHz)
% 
%         for contrastIdx = 1:nContrasts
% 
%             nexttile;
%             hold on
% 
%             % To combine trial data across subjects
%             comboTrialData = cell(1, nSides);
% 
%             % Store the first psychObj per side
%             % All data is the same across subjects (within a condition) except for the trial data
%             templatePsychObj = cell(1, nSides);
% 
%             for sideIdx = 1:nSides
% 
%                 for subjIdx = 1:nSubjects
% 
%                     subjectID_this = subjectID{subjIdx};
%                     subjectDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, subjectID_this);
%                     dataDir = fullfile(subjectDir,[modDirections{1} '_ND' NDLabel{lightIdx} '_shifted'],experimentName);
% 
%                     % Load this measure
%                     psychFileStem = [subjectID_this '_' modDirections{1} ...
%                         '_' experimentName...
%                         '_cont-' strrep(num2str(targetPhotoContrast(contrastIdx)),'.','x') ...
%                         '_refFreq-' num2str(refFreqSetHz(freqIdx)) 'Hz' ...
%                         '_' stimParamLabels{sideIdx}];
%                     filename = fullfile(dataDir,psychFileStem);
%                     load(filename,'psychObj');
% 
%                     % Combine trial data for this side, across subjects
%                     comboTrialData{sideIdx} = [comboTrialData{sideIdx}; psychObj.questData.trialData];
% 
%                     % Store a template psychObj for this side
%                     if subjIdx == 1
%                         templatePsychObj{sideIdx} = psychObj;
%                     end
% 
%                 end
%             end
%     end