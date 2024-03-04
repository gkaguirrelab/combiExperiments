% I collected 15 trials each of a 15 second pedestal pulse of spectral
% change from the low background state for three modulation directions. I
% adapted to each background for 5 minutes. This routine plots the results
% and fits the data with the "tpup" pupil model (McAdams 2018 IOVS).


% Details of the video recording and stimulus timing
deltaT = 1/60;
nFrames = 2090; % This is the minimum number of frames across all videos
nTrials = 15;
preDur = 2;
pulseDur = 15;
halfCosDur = 2;
vidDelayFixed = 5;

% RMSE threshold value of elipse fitting that will define a "bad" frame
rmseThresh = 3;

% Define the location of the data and the stimulus directions
dataDirStem = '/Users/aguirre/Aguirre-Brainard Lab Dropbox/Geoffrey Aguirre/MELA_data/combiLED/HERO_gka1/IncrementPupil';
analysisDirStem = '/Users/aguirre/Aguirre-Brainard Lab Dropbox/Geoffrey Aguirre/MELA_analysis/combiLED/HERO_gka1/IncrementPupil';
sesID = '2024-02-29';
directions = {'Mel','SnoMel','LplusMnoMel'};
plotColor = {'-c','-b','k'};

% Create the stimulus representation
stimTime = -preDur:deltaT:((nFrames-1)*deltaT)-preDur;
[~,zeroTimeIdx] = min(abs(stimTime));
stimulus = [zeros(1,preDur/deltaT) ones(1,pulseDur/deltaT)];
stimulus = [stimulus zeros(1,nFrames-length(stimulus))];
stimulus(preDur/deltaT+1:(preDur+halfCosDur)/deltaT) = (cos(linspace(pi,0,halfCosDur/deltaT))+1)/2;
stimulus((preDur+pulseDur-halfCosDur)/deltaT+1:(preDur+pulseDur)/deltaT) = (cos(linspace(0,pi,halfCosDur/deltaT))+1)/2;

% Set up a figure
figure
figuresize(2,4,'inches');
tiledlayout(3,1,'TileSpacing','tight','Padding','tight');


% Loop over stimulus directions
for dd = 1:length(directions)

    % Initialize the data variable
    data = nan(nFrames,nTrials);

    % Load the psychObj that contains the trial results. Silence a warning
    % about the combiLED object not being available
    warnState = warning();
    warning('off','serialport:serialport:ConnectionFailed');
    psychObjFile = fullfile(dataDirStem,directions{dd},sesID,'psychObj.mat');
    load(psychObjFile,'psychObj');
    warning(warnState);

    % Loop over trials
    for ii = 1:nTrials

        % Load the pupil data file, extract the pupil area vec
        pupilFilePath = fullfile(analysisDirStem,directions{dd},sesID,'rawPupilVideos',sprintf('trial_%02d_pupil.mat',ii));
        load(pupilFilePath,'pupilData')
        vec = pupilData.initial.ellipses.values(:,3);

        % Remove bad frames
        highRMSEidx = find(pupilData.initial.ellipses.RMSE > rmseThresh);
        for vv = -2:2
            idx = highRMSEidx+vv;
            idx = idx(idx>0);
            idx = idx(idx<nFrames);
            vec(idx) = nan;
        end

        % Shift the vector to account for variation in camera start time
        shiftSamples = round((psychObj.trialData(ii).vidDelaySecs - vidDelayFixed)*60);
        vec = circshift(vec,shiftSamples);

        % Convert the pupil vector to proportion change relative to the
        % pre-stimulus baseline period
        baseIdx = 0*60+1:preDur*60;
        base = mean(vec(baseIdx),"omitnan");
        vec = (vec - base)/base;

        % Store this vector
        data(:,ii) = vec(1:nFrames);

    end

    % Get the mean of the pupil response across trials
    signal = mean(data,2,"omitnan");

    % Plot this vector
    nexttile
    plot([-5 35],[0 0],'-r','LineWidth',1)
    hold on
    plot(stimTime,signal,'.','color',[0.75 0.75 0.75]);
    ylim([-0.5 0.25]);
    xlim([-5 35]);
    a = gca();
    a.YTick = [-0.5 -0.25 0 0.25];
    a.YTickLabels = {'-50','-25','0','25'};
    stimStart = stimTime(find(stimulus>0,1,"first"));
    stimEnd = stimTime(find(stimulus>0,1,"last"));
    plot([stimStart stimStart],[-0.5 0.25],':k','LineWidth',1.5)
    plot([stimEnd stimEnd],[-0.5 0.25],':k','LineWidth',1.5)
    if dd == 1
        ylabel('Pupil area [%∆]');
    else
        a.YTick = [];
    end
    if dd == 3
        xlabel('time [secs]')
    else
        a.XTick = [];
    end
    box off

    % Fit the vector with the tpup model
    yFit = tpupFit(signal,stimulus,stimTime);
    plot(stimTime,yFit,plotColor{dd},'LineWidth',3)

end



% LOCAL FUNCTIONS
function [yFit,p] = tpupFit(signal,stimulus,stimTime)

% Define an objective
myObj = @(p) norm(signal - tpupModel(stimulus,stimTime,p)');

% Initial guess and bounds
p0 = [-0.7161    1.0000    5.0000    0.7241    0.7703    1.5760];
lb = [-1,0.1,0.1,0,0,-100];
ub = [1,20,50,100,100,100];

% Fit and return fit vector
p = fmincon(myObj,p0,[],[],[],[],lb,ub);
yFit = tpupModel(stimulus,stimTime,p);

end