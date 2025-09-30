
clear
close all

subjectIDs = {'HERO_gka',...
    'BLNK_1001','BLNK_1002','BLNK_1003',...
    'BLNK_1004','BLNK_1005','BLNK_1006',...
    'BLNK_1007','BLNK_1008'};
experimentName = 'lightLevel';
direction = 'LightFlux';
whichSequence = 1;

% Define some properties of the analysis
fps = 180;
contrastLevels = [0.0375,0.075,0.15,0.30,0.6];

% Derive lux from the contrast levels
illuminanceLevels = contrastLevels * (4273*2) * pi;

% Hard-code a couple of deBruijn sequences we will use to define the
% stimulus order across blocks. In all cases, the sequence begins with the
% middle intensity stimulus. The first trial is repeated, allowing us to
% discard the first trial and have a fully counter-balanced sequence.
sequenceSet{1} = [3,3,1,4,5,5,4,1,2,3,2,2,1,5,3,4,4,3,5,2,4,2,5,1,1,3];
sequenceSet{2} = [3,3,2,5,3,5,2,4,3,4,1,1,5,1,3,1,2,2,1,4,4,5,5,4,2,3];
sequenceSet{3} = [3,3,4,2,5,3,2,4,5,1,4,1,1,5,4,4,3,5,5,2,1,2,2,3,1,3];
sequenceSet{4} = [3,3,1,4,5,1,2,2,3,2,1,3,4,2,4,4,3,5,2,5,5,4,1,1,5,3];

% All subjects just did the first sequence
thisSequence = sequenceSet{1};

% Define the data directory
dataDir = '/Users/aguirre/Aguirre-Brainard Lab Dropbox/Geoffrey Aguirre/BLNK_analysis/PuffLight/lightLevel';

dataVecsPalp = nan(length(subjectIDs),5,5,5800);
dataVecsPupil = nan(length(subjectIDs),5,5,5800);
t = 0:1/fps:(10800-1)/fps;

% Loop over the data files
for ss = 1:length(subjectIDs)

    subjectID = subjectIDs{ss};

    contrastCounter = zeros(size(contrastLevels));

    % Loop over
    for tt = 1:25

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

        % Filename
        fileName = sprintf( [subjectID '_' experimentName ...
            '_direction-' direction '_sequence-%d' ...
            '_contrast-%2.2f_trial-%03d_side-R_eye_features.mat'],...
            whichSequence, contrastLevel, trialIdx);

        % Load the data
        load(fullfile(dataDir,subjectID,fileName));

        % Handle the new vs. old Zach style for storing these data
        if isfield(eye_features,'eye_features')
            eye_features = eye_features.eye_features;
        end

        % Extract the upper and lower lid to calculate the height of the
        % palpebral fissure over time, and the pupil diameter
        nTimePoints = length(eye_features);
        palpFissureHeight = nan(1,nTimePoints);
        pupilDiameter = nan(1,nTimePoints);

        for pp = 1:nTimePoints
            xVals = eye_features{pp}.eyelids.eyelid_x;
            lidUpper = eye_features{pp}.eyelids.eyelid_up_y;
            lidLower = eye_features{pp}.eyelids.eyelid_lo_y;
            [~,xIdx] = min(abs(xVals-mean(xVals)));
            val = lidLower(xIdx) - lidUpper(xIdx);
            if val > 0 && val < 100
                palpFissureHeight(pp) = val;
            end
            pupilDiameter(pp) = eye_features{pp}.pupil.diameter;
        end

        % Store the vecs
        dataVecsPalp(ss,contrastIdx,contrastCounter(contrastIdx),1:nTimePoints) = palpFissureHeight;
        dataVecsPupil(ss,contrastIdx,contrastCounter(contrastIdx),1:nTimePoints) = pupilDiameter;

    end

    figure
    for kk = 1:5; subplot(2,3,kk); for ii = 1:5; plot(squeeze(dataVecsPalp(ss,kk,ii,:))); hold on; end; end

    % Obtain the median palpebral fissure width during the first 200 frames
    % for this subject
    vals = dataVecsPalp(ss,:,:,1:200);
    openVal = max(vals(:),[],'omitmissing');
    vals = dataVecsPalp(ss,:,:,201:end);
    closedVal = max(vals(:),[],'omitmissing');

    % For each trial, convert the data vector to proportion closure, and
    % then obtain the mean closure during the light pulse period
    for ll = 1:length(contrastLevels)
        tmpCloseVals = [];
        for rr = 1:contrastCounter(ll)
            vec = squeeze(dataVecsPalp(ss,ll,rr,:));
            goodIdx = ~isnan(vec);
            dataVecsPalp(ss,ll,rr,goodIdx) = 1 - vec(goodIdx) / (openVal);
            tmpCloseVals(rr) = mean(squeeze(dataVecsPalp(ss,ll,rr,201:end)),'omitmissing');
        end

        % Obtain the mean and SEM of closure for each light level for this
        % subject
        palpCloseMean(ss,ll) = mean(tmpCloseVals,2);
        palpCloseSEM(ss,ll) = std(tmpCloseVals,[],2)/sqrt(contrastCounter(ll));   
    end

end

figure
plot(log10(illuminanceLevels),palpCloseMean')
ylim([0 1]);


% If you have the psychObj in memory, these commands will give you the
% proportion correct on the detection task, and identify the trials in
% which any missed events occured
%{
    sum([psychObj.trialData.detected])/length([psychObj.trialData.detected])
    find(arrayfun(@(x) any(x.detected==0),psychObj.trialData))
%}


%
% dataVecs = reshape(dataVecs,3,18,10800);
%
% figure
% plot(t,zeros(size(t)),':k','LineWidth',2);
% hold on
%
% colorSet = {[0 0 0],[0 1 1],[0 0 1]};
% for tt = 1:3
%     yMean = mean(squeeze(dataVecs(tt,:,:)),1,'omitmissing');
%     ySEM = std(squeeze(dataVecs(tt,:,:)),1,'omitmissing') /sqrt(size(dataVecs,2));
%     yMean = yMean-yMean(1);
%     idx = ~isnan(yMean);
%     yMean = yMean(idx);
%     ySEM = ySEM(idx);
%     yD = decimate(yMean,100);
%     yS = decimate(ySEM,100);
%     patch([t(idx) fliplr(t(idx))],[yMean+ySEM fliplr(yMean-ySEM)],colorSet{tt},'EdgeColor','none','FaceAlpha',0.2);
%     deltaTD = (t(2)-t(1))*100;
%     tD = t(1):deltaTD:deltaTD*(length(yD)-1);
%     fitObj = fit(tD',yD','smoothingspline');
%     plot(tD,fitObj(tD),'-','Color',colorSet{tt},'LineWidth',2);
% end
%
% for tt = 1:length(tD)-1
%     colorVal = [1 1 0]* 0.5*(sin(tD(tt)/60*2*pi)+1);
%     patch([tD(tt) tD(tt+1) tD(tt+1) tD(tt)],[-0.4 -0.4 -0.5 -0.5],colorVal,'EdgeColor','none')
% end
%
% ylabel('Proportion change in blink rate');
% xlabel('Time [secs]');
