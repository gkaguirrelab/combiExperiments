% Create plots related to the "light level" experiment. In this experiment,
% participants observed a binocular uniform field. The field started dark,
% and then illuminated to one of 5, log-spaced light levels. While the
% light was on, the subject monitored for an infrequent diming of the light
% to which they were to make a button response. Each trial was 30 seconds
% total, including the initial 1 second dark period. There were a total of
% 26 trials presented in a counter-balanced order of illuminance (first
% trial discarded to achieve counter-balance).
%

clear
close all

% Do we want to plot individual time-series examples?
plotSubjectTimeSeriesFlag = false;

% Properties of the subjects and source data
subjectIDs = {...
    'BLNK_1001','BLNK_1002','BLNK_1003',...
    'BLNK_1004','BLNK_1005','BLNK_1006',...
    'BLNK_1007','BLNK_1008','BLNK_1009',...
    'BLNK_1010'};
projectName = 'PuffLight';
experimentName = 'lightLevel';
direction = 'LightFlux';
whichSequence = 1;

% Define some properties of the experiment
contrastLevels = [0.0375,0.075,0.15,0.30,0.6];
nLevels = length(contrastLevels);

% Define how we handle the time series. We will treat the first second of
% the measurement the initial dark period; the subsequent frames of the 30
% second measurement are the period with the light stimulus.
fps = 180;
allFramRange = 1:fps*30-1;
startFrameRange = 1:fps;
dataFrameRange = fps+1:fps*30-1;

% Get the path to the data files
dropboxBaseDir = getpref('combiExperiments','dropboxBaseDir');

% Prepare the photophic luminance function
load('T_xyz1931.mat','T_xyz1931','S_xyz1931');

% Hard-code the deBruijn sequences we will use to define the stimulus order
% across blocks. In all cases, the sequence begins with the middle
% intensity stimulus. The first trial is repeated, allowing us to discard
% the first trial and have a fully counter-balanced sequence.
sequenceSet{1} = [3,3,1,4,5,5,4,1,2,3,2,2,1,5,3,4,4,3,5,2,4,2,5,1,1,3];
sequenceSet{2} = [3,3,2,5,3,5,2,4,3,4,1,1,5,1,3,1,2,2,1,4,4,5,5,4,2,3];
sequenceSet{3} = [3,3,4,2,5,3,2,4,5,1,4,1,1,5,4,4,3,5,5,2,1,2,2,3,1,3];
sequenceSet{4} = [3,3,1,4,5,1,2,2,3,2,1,3,4,2,4,4,3,5,2,5,5,4,1,1,5,3];

% All subjects just did the first sequence
<<<<<<< HEAD
thisSequence = sequenceSet{whichSequence};
=======
thisSequence = sequenceSet{1};

% Define the data directory
dropboxBaseDir = getpref('combiExperiments','dropboxBaseDir');
projectName = 'PuffLight';
experimentName = 'lightLevel';
dataDir = fullfile(dropboxBaseDir,'BLNK_analysis',projectName,experimentName);
>>>>>>> fe2ca525aa29ee31cac5194defe67a3eef27b676

% Define the variables and temporal support for the data
dataVecsPalp = nan(length(subjectIDs),5,5,5800);
dataVecsAdj = nan(length(subjectIDs),5,5,5800);
dataVecsPupil = nan(length(subjectIDs),5,5,5800);
t = 0:1/fps:(5800-1)/fps;

% Define a sigmoid fitting function
mySigFit = @(x,p) 1 ./ (1 + exp(-p(2).*(x-p(1))));


% Loop over the data files
for subIdx = 1:length(subjectIDs)

    % This subject ID
    subjectID = subjectIDs{subIdx};

    % Derive the max illuminance for the data for this subject during the
    % lightLevel experiment by examining the modResult. We obtain the SPD
    % for the maximum positive modulation, calculate the luminance, and
    % then convert to illuminance for this hemi-field stimulus by
    % multiplying by pi.
    dataDir = fullfile(dropboxBaseDir,'BLNK_data',projectName,'lightLevel',subjectID);
    load(fullfile(dataDir,'modResult_LightFlux.mat'),'modResult');
    posModSPD = modResult.positiveModulationSPD;
    wavelengthsNm = modResult.wavelengthsNm;
    S = WlsToS(wavelengthsNm);
    T_xyz = SplineCmf(S_xyz1931,683*T_xyz1931,S);
    maxLuxBySub_lightLevel(subIdx) = T_xyz(2,:)*posModSPD*pi;

<<<<<<< HEAD
    % Now do the same for the background illuminance of the modulate
    % experiment. One of the lightLevel participants did not return for the
    % modulate experiment, so we detect their missing measurement and skip.
    dataDir = fullfile(dropboxBaseDir,'BLNK_data',projectName,'modulate',subjectID);
    if isfile(fullfile(dataDir,'modResult_LMS.mat'))
        load(fullfile(dataDir,'modResult_LMS.mat'),'modResult');
        backgroundSPD = modResult.backgroundSPD;
        wavelengthsNm = modResult.wavelengthsNm;
        S = WlsToS(wavelengthsNm);
        T_xyz = SplineCmf(S_xyz1931,683*T_xyz1931,S);
        bgLuxBySub_modulate(subIdx) = T_xyz(2,:)*backgroundSPD*pi;
    else
        bgLuxBySub_modulate(subIdx) = nan;
    end

    % Prepare to loop over trials and assemble the time-series data
    contrastCounter = zeros(size(contrastLevels));
    for tt = 1:length(thisSequence)-1
=======
    %preallocate
    baselineTossedPercent = nan(5, 5);

    % Loop over
    for tt = 1:25
>>>>>>> fe2ca525aa29ee31cac5194defe67a3eef27b676

        % We discard the first of the 26 trials. Also, the trial counter
        % was off by one for subject gka. Handle all this here.
        switch subjectID
            case 'HERO_gka'
                trialIdx = tt+2;
                contrastIdx = thisSequence(trialIdx-1);
            otherwise
                trialIdx = tt+1;
                contrastIdx = thisSequence(trialIdx);
        end

        % Get the contrast
        contrastLevel = contrastLevels(contrastIdx);

        % Increment the contrast counter
        contrastCounter(contrastIdx) = contrastCounter(contrastIdx)+1;

        % Directory
        dataDir = fullfile(dropboxBaseDir,'BLNK_analysis',projectName,experimentName,subjectID);

        % Filename
        fileName = sprintf( [subjectID '_' experimentName ...
            '_direction-' direction '_sequence-%d' ...
            '_contrast-%2.2f_trial-%03d_side-R_eye_features.mat'],...
            whichSequence, contrastLevel, trialIdx);
        fullPath = fullfile(dataDir, subjectID, fileName);

<<<<<<< HEAD
        % Load the data
        load(fullfile(dataDir,fileName));

        % Handle the new vs. old Zach style for storing these data
        if isfield(eye_features,'eye_features')
            eye_features = eye_features.eye_features;
        end

        % Extract the upper and lower lid to calculate the height of the
        % palpebral fissure over time, and the pupil diameter
        nTimePoints = length(eye_features);
        palpFissureHeight = nan(1,nTimePoints);
        pupilDiameter = nan(1,nTimePoints);

        % Loop over the time points and extract palpebral fissure size and
        % pupil diameter
=======
        % Get Palpebral Fissure for dark baseline and remove blinks
        baselineDur = 200/fps;
        [palpBaseline, pupilDiameterCleaned] = loadBlinkCleanedData(fullPath,...
            'videoDurSecs', baselineDur, 'fps', fps);
        trialStart = 201/fps;
        trialDur = 30 - trialStart;
        % Get Palpebral Fissure and Confidence for light trial
        [palpTrial, confidenceTrial] = loadSquintVector(fullPath, 'fps', fps, ...
            'startTimeSecs', trialStart, 'vecDurSecs', trialDur, 'smoothWindowSecs', 0);
        % Combine them back into one vector for storage
        palpFissureHeight = [palpBaseline, palpTrial];
        
        % Manual extraction of data because of Zach naming logic        
        tmp = load(fullPath);
        if isfield(tmp,'eye_features'), fts = tmp.eye_features; else, fts = tmp.eyeFeatures; end
        if isfield(fts,'eye_features'), fts = fts.eye_features; end
        % Handle potential .data nesting for pupil too
        if isstruct(fts) && isfield(fts, 'data'), fts = fts.data; end
        
        nTimePoints = length(palpFissureHeight);
        pupilDiameter = nan(1, nTimePoints);
>>>>>>> fe2ca525aa29ee31cac5194defe67a3eef27b676
        for pp = 1:nTimePoints
            pupilDiameter(pp) = fts{pp}.pupil.diameter;
        end
        % Store the vecs
        dataVecsPalp(subIdx,contrastIdx,contrastCounter(contrastIdx),1:nTimePoints) = palpFissureHeight;
        dataVecsPupil(subIdx,contrastIdx,contrastCounter(contrastIdx),1:nTimePoints) = pupilDiameter;

    end

<<<<<<< HEAD
    % Obtain the median, max and min palpebral fissure width during the
    % recording. The max will likely occur during the dark period (but is
    % not required to be so).
    vals = squeeze(dataVecsPalp(subIdx,1,:,allFramRange));
    openVal = median(max(vals,[],2,'omitmissing'));
    closedVal = min(vals(:),[],'omitmissing');
=======
    % Obtain the median palpebral fissure width for this subject
    allVals = squeeze(dataVecsPalp(subIdx,1,:,allFramRange));
    openVal = median(max(allVals,[],2,'omitmissing'));
    closedVal = min(allVals(:),[],'omitmissing');
>>>>>>> fe2ca525aa29ee31cac5194defe67a3eef27b676
    widthVal = openVal - closedVal;

    % For each trial, convert the data vector to proportion closure, and
    % then obtain the mean closure during the light pulse period
    for ll = 1:length(contrastLevels)
        tmpCloseVals = [];
        for rr = 1:contrastCounter(ll)
            vec = squeeze(dataVecsPalp(subIdx,ll,rr,:));
            goodIdx = ~isnan(vec);
            dataVecsAdj(subIdx,ll,rr,goodIdx) = 1 - (vec(goodIdx)-closedVal) / widthVal;
            tmpCloseVals(rr) = mean(squeeze(dataVecsAdj(subIdx,ll,rr,dataFrameRange)),'omitmissing');
        end

        % Obtain the mean and SEM of closure for each light level for this
        % subject. Also identify the trial with the closest to mean eye
        % closure
        palpCloseMean(subIdx,ll) = mean(tmpCloseVals,2);
        [~,exampleTrialIdx(subIdx,ll)] = min(abs(tmpCloseVals - mean(tmpCloseVals)));
        palpCloseSEM(subIdx,ll) = std(tmpCloseVals,[],2)/sqrt(contrastCounter(ll));
    end

<<<<<<< HEAD
    if plotSubjectTimeSeriesFlag
        figure
        for ll = 1:nLevels
            subplot(2,3,ll)
            % Plot the trial with the closest to the mean eye closure
            plot(t(allFramRange),1-squeeze(dataVecsAdj(subIdx,ll,exampleTrialIdx(subIdx,ll),allFramRange)),'-','Color',[0.5 0.5 0.5])
            hold on
            ylim([0,1]);
            ylabel('Proportion open');
            xlabel('time [secs]');
=======
    figure
    for ll = 1:5
        subplot(2,3,ll)
        % Plot the trial with the closest to the mean eye closure
        plot(t(allFramRange),1-squeeze(dataVecsAdj(subIdx,ll,exampleTrialIdx(subIdx,ll),allFramRange)),'-','Color',[0.5 0.5 0.5])
        hold on
        %plot line showing where dark baseline ended.
        xline(200/fps, '--r');
        ylim([0,1]);
        ylabel('Proportion open');
        xlabel('time [secs]');
    end

    drawnow

end


% Create a figure that shows the average, smoothed time-course of eye
% closure across subjects for a given light level
myExpFit = @(x,p) p(1) - p(2).*exp(-p(3).*x);

figure
for ll = 1:5
    for ss = 1:length(subjectIDs)
        dataMatrix = squeeze(dataVecsAdj(ss,ll,:,:));
        for rr = 1:size(dataMatrix,1)
            dataMatrix(rr,:) = smoothdata(dataMatrix(rr,:),'movmedian',10);
>>>>>>> fe2ca525aa29ee31cac5194defe67a3eef27b676
        end
        drawnow
    end

end

% Calculate mean across subject illuminance of the stimuli for each of the
% contrast levels
illuminanceLevels = contrastLevels * mean(maxLuxBySub_lightLevel);

% Calculate mean across subject illuminance of the background used for the
% modulate experiment
bgLuxMean_modulate = mean(bgLuxBySub_modulate,'omitmissing');



%%%%%%%%%%%%%
%% FIGURES %%
%%%%%%%%%%%%%


%% The average across-subject response function with a sigmoid fit
figure('Position', [100 100 300 300])

% Get the mean and SEM across subjects
meanData = mean(palpCloseMean);
semData = std(palpCloseMean)/sqrt(size(palpCloseMean,1));

% Fit the sigmoid function
myObj = @(p) norm(meanData - mySigFit(log10(illuminanceLevels),p));
p = fmincon(myObj,[1 3]);

% plot the error bars
for ii = 1:length(illuminanceLevels)
    plot([log10(illuminanceLevels(ii)), log10(illuminanceLevels(ii))],...
        [meanData(ii)-semData(ii), meanData(ii)+semData(ii)],...
        '-','Color',[0.5 0.5 0.5],'LineWidth',3);
    hold on
end

% Add the fit
xFit = 0:0.1:6;
yFit = mySigFit(xFit,p);
plot(xFit,yFit,'-r','LineWidth',1);

% Add the data points
plot(log10(illuminanceLevels),meanData,'.k','MarkerSize',25);

% Clean up
ylim([0 1]);
box off
set(gca, 'TickDir', 'out')
xlabel('log_1_0 lux');
ylabel('Proportion eye closure');
set(gca, 'XTick', [0 2 4 6])
set(gca, 'YTick', [0 0.5 1])
text(4,0.15,'±SEM');


%% Illustration of the modulate background on the group, light-level
%% squint function
figure('Position', [100 100 300 300])
plot(xFit,yFit,'-','Color',[0.5,0.5,0.5],'LineWidth',1);
hold on
% Background
xVal = log10(bgLuxMean_modulate);
yVal = mySigFit(xVal,p);
plot([xVal xVal],[0 yVal],':','Color',[0.5 0.5 0.5],'LineWidth',1);
plot([0 xVal],[yVal yVal],':','Color',[0.5 0.5 0.5],'LineWidth',1);
% Positive arm
xVal = log10(bgLuxMean_modulate*1.4);
yVal = mySigFit(xVal,p);
plot([xVal xVal],[0 yVal],':r','LineWidth',1);
plot([0 xVal],[yVal yVal],':r','LineWidth',1);
% Negative arm
xVal = log10(bgLuxMean_modulate/1.4);
yVal = mySigFit(xVal,p);
plot([xVal xVal],[0 yVal],':k','LineWidth',1);
plot([0 xVal],[yVal yVal],':k','LineWidth',1);
% Clean up
ylim([0 1]);
box off
set(gca, 'TickDir', 'out')
xlabel('log_1_0 lux');
ylabel('Proportion eye closure');
set(gca, 'XTick', [0 2 4 6])
set(gca, 'YTick', [0 0.5 1])




%% The per-subject response function with a sigmoid fit

figure
<<<<<<< HEAD
=======
% Define a sigmoid fitting function
% p(1) — 50% Threshold
% p(2) — Slope
mySigFit = @(x,p) 1 ./ (1 + exp(-p(2).*(x-p(1))));
>>>>>>> fe2ca525aa29ee31cac5194defe67a3eef27b676

subjectPlotOrder = [3    10     7     4     9     1     5     6     8     2];

for ss = 1:length(subjectPlotOrder)

    subIdx = subjectPlotOrder(ss);
    subplot(4,3,ss);

myObj = @(p) norm(palpCloseMean(subIdx,~isnan(palpCloseMean(subIdx,:))) - ...
             mySigFit(log10(illuminanceLevels(~isnan(palpCloseMean(subIdx,:)))), p));
p(subIdx,:) = fmincon(myObj,[1 3]);

    % plot
    for ii = 1:length(illuminanceLevels)
        plot([log10(illuminanceLevels(ii)), log10(illuminanceLevels(ii))],...
            [palpCloseMean(subIdx,ii)-2*palpCloseSEM(subIdx,ii), palpCloseMean(subIdx,ii)+2*palpCloseSEM(subIdx,ii)],...
            '-','Color',[0.5 0.5 0.5],'LineWidth',1.5);
        hold on
    end
    xFit = 0:0.1:6;
    yFit = mySigFit(xFit,p(subIdx,:));
    plot(xFit,yFit,'-r');
    plot(log10(illuminanceLevels),palpCloseMean(subIdx,:),'.k','MarkerSize',10);
    ylim([0 1]);
    box off
    set(gca, 'TickDir', 'out')
    if ss == 1
        xlabel('log_1_0 lux');
        ylabel('Proportion closed');
        set(gca, 'XTick', [0 2 4 6])
        set(gca, 'YTick', [0 0.5 1])
    else
        set(gca, 'XTickLabel', [])
        set(gca, 'YTickLabel', [])
        set(gca,'xtick',[])
        set(gca,'ytick',[])
    end
    text(1,0.85,sprintf('S%d',ss));
end

subplot(4,3,12);
yFit = mySigFit(xFit,p(6,:));
plot(xFit,yFit,'-r');
hold on
plot([0 p(6,1)],[0.5 0.5],':k');
plot([p(6,1) p(6,1)],[0 0.5],':k');
box off
set(gca, 'TickDir', 'out')
set(gca, 'XTickLabel', [])
set(gca, 'YTickLabel', [])
set(gca,'xtick',[])
set(gca,'ytick',[])



%% Loop through the psychometric objects and

% If you have the psychObj in memory, these commands will give you the
% proportion correct on the detection task, and identify the trials in
% which any missed events occured
%{
    sum([psychObj.trialData.detected])/length([psychObj.trialData.detected])
    find(arrayfun(@(x) any(x.detected==0),psychObj.trialData))
%}




% Create a figure that shows the average, smoothed time-course of eye
% closure across subjects for a given light level
myExpFit = @(x,p) p(1) - p(2).*exp(-p(3).*x);

figure
for ll = 1:nLevels
    for ss = 1:length(subjectIDs)
        dataMatrix = squeeze(dataVecsAdj(ss,ll,:,:));
        for rr = 1:size(dataMatrix,1)
            dataMatrix(rr,:) = smoothdata(dataMatrix(rr,:),'movmedian',10);
        end
        dataSub(ss,:) = smoothdata(mean(dataMatrix,'omitmissing'),'movmedian',1);
    end
    yVec = 1-smoothdata(mean(dataSub,'omitmissing'),'movmedian',1);
    yVec = yVec(260:5500);
    xVec = t(260:5500)-t(260);
    t5idx = find(xVec>5,1);
    plot(xVec,yVec,'.','Color',[0.5 0.5 0.5]);
    hold on
    myObj = @(p) norm(yVec(1:t5idx)-myExpFit(xVec(1:t5idx),p));
    p = fmincon(myObj,[1 1 1]);
    xFit = xVec(1):diff(xVec(1:2)):xVec(t5idx);
    yExpFit = myExpFit(xFit,p);
    plot(xFit,yExpFit,'-r','LineWidth',1.5);
    coef(ll,:) = polyfit(xVec(t5idx:end),yVec(t5idx:end),1);
    yFit = polyval(coef(ll,:),xVec(t5idx:end));
    yFit = yFit - yFit(1) + yExpFit(end);
    plot(xVec(t5idx:end),yFit,'-r','LineWidth',1.5);
end
ylim([0 1]);
box off
xlabel('Time [s]');
ylabel('Proportion eye open');
set(gca,'TickDir','out');
set(gca,'YTick',[0 0.5 1]);
p=[];