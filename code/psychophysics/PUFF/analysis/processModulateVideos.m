
clear
close all

% Define some properties of the analysis
directionSet = {'-LMS','-Mel','-S'};
windowDurSecs = 7.5;
fps = 180;

% Get a list of the analysis files
dataDir = '/Users/aguirre/Aguirre-Brainard Lab Dropbox/Geoffrey Aguirre/BLNK_analysis/PuffLight/modulate/HERO_gka/videos';
mList = dir(fullfile(dataDir,'*trial*mat'));

dataVecs = nan(3,9,2,10800);
t = 0:1/fps:(10800-1)/fps;

% Loop over the data files
for ii = 1:length(mList)

    % Load the data
    load(fullfile(mList(ii).folder,mList(ii).name),'eye_features');

    if isfield(eye_features,'eye_features')
        eye_features = eye_features.eye_features;
    end

    % Discard the first second, and keep the next 60 seconds (10800) time points
    eye_features = eye_features(fps:fps*60-1);

    % Extract the upper and lower lid to calculate the height of the palpebral
    % fissure over time
    nTimePoints = length(eye_features);
    palpFissureHeight = nan(1,nTimePoints);
    pupilDiameter = nan(1,nTimePoints);

    for tt = 1:nTimePoints
        xVals = eye_features{tt}.eyelids.eyelid_x;
        lidUpper = eye_features{tt}.eyelids.eyelid_up_y;
        lidLower = eye_features{tt}.eyelids.eyelid_lo_y;
        [~,xIdx] = min(abs(xVals-mean(xVals)));
        val = lidLower(xIdx) - lidUpper(xIdx);
        if val > 0 && val < 100
            palpFissureHeight(tt) = val;
        end
        pupilDiameter(tt) = eye_features{tt}.pupil.diameter;
    end

    % subplot(2,1,1);
    % plot(palpFissureHeight);

    % This is a vector of blink events
    blinkVec = diff(palpFissureHeight < median(palpFissureHeight,'omitmissing')/2)>0;

    % Slide a window along and ensure that no more than one blink
    % event exists within a 0.25 second window
    for tt = 1:length(blinkVec)
        if blinkVec(tt) == 1
            blinkVec(tt+1:tt+fps/4)=0;
        end
    end

    % Perform a circular convolution with a square wave filter to obtain a
    % circular moving mean    
    % subplot(2,1,2);
    % hold off
    filter = zeros(size(blinkVec));
    filter(1:windowDurSecs*fps)=1;
    blinkVecSmooth = cconv(blinkVec,filter,length(blinkVec));

    % Convert the smooth blink vec into a %change in blink rate
    blinkVecSmooth = (blinkVecSmooth - mean(blinkVecSmooth))/mean(blinkVecSmooth);

    % Store the vec
    trialIdx = str2double(mList(ii).name(strfind(mList(ii).name,'trial-')+6:strfind(mList(ii).name,'trial-')+8));
    directionIdx = find(arrayfun(@(s) contains(mList(ii).name, s), directionSet));
    phaseIdx = double(contains(mList(ii).name,'phase-0.00'))+1;
    if phaseIdx == 1
        blinkVecSmooth = -blinkVecSmooth;
    end
    dataVecs(directionIdx,trialIdx,phaseIdx,1:length(blinkVecSmooth)) = blinkVecSmooth;
    fprintf('dir %d, trial %d, phase %d \n',directionIdx,trialIdx,phaseIdx);


    % plot(blinkVecSmooth);
    % ylim([-1 1]);
    % title(mList(ii).name);
    % pause
end

dataVecs = reshape(dataVecs,3,18,10800);

figure
plot(t,zeros(size(t)),':k','LineWidth',2);
hold on

colorSet = {[0 0 0],[0 1 1],[0 0 1]};
for ii = 1:3
    yMean = mean(squeeze(dataVecs(ii,:,:)),1,'omitmissing');
    ySEM = std(squeeze(dataVecs(ii,:,:)),1,'omitmissing') /sqrt(size(dataVecs,2));
    yMean = yMean-yMean(1);
    idx = ~isnan(yMean);
    yMean = yMean(idx);
    ySEM = ySEM(idx);
    yD = decimate(yMean,100);
    yS = decimate(ySEM,100);
    patch([t(idx) fliplr(t(idx))],[yMean+ySEM fliplr(yMean-ySEM)],colorSet{ii},'EdgeColor','none','FaceAlpha',0.2);
    deltaTD = (t(2)-t(1))*100;
    tD = t(1):deltaTD:deltaTD*(length(yD)-1);
    fitObj = fit(tD',yD','smoothingspline');
    plot(tD,fitObj(tD),'-','Color',colorSet{ii},'LineWidth',2);
end

for ii = 1:length(tD)-1
    colorVal = [1 1 0]* 0.5*(sin(tD(ii)/60*2*pi)+1);
    patch([tD(ii) tD(ii+1) tD(ii+1) tD(ii)],[-0.4 -0.4 -0.5 -0.5],colorVal,'EdgeColor','none')
end

ylabel('Proportion change in blink rate');
xlabel('Time [secs]');
box off
a=gca();
a.TickDir = 'out';

