close all
clear

% Define the list of subjects
subjects = {'BLNK_1001','BLNK_1003','BLNK_1006','BLNK_1007',...
    'BLNK_1009','BLNK_1010','BLNK_1011'};

% Define temporal properties of the recording
options.fps = 180;
options.vecDurSecs = 60;
nFrames = options.vecDurSecs * options.fps;

% Define the stimulus properties
directions = {'Mel','LMS','S_peripheral','LightFlux'};
directionLabels = {'Mel','LMS','S','LF'};
phaseLabels = {'OnOff','OffOn'};
contrastLabels = {'High','Low'};
phases = [0,pi];
contrasts = [0.4,0.2];
nTrials = 4;

% Define plot properties
directionColors = {'c','y','b','k'};
directionPlotOrder = [2 3 4 1];
contrastLineWidth = [1,2];


% Get the results
for ss = 1:length(subjects)
    results{ss} = processModulateVideos(subjects{ss},'makePlotFlag',false);
end

% Fit a Fourier regression to the data from every subject and condition
figure
tiledlayout(length(contrasts),length(directions))
for dd = 1:length(directions)
    for cc = 1:length(contrasts)
        for ss = 1:length(subjects)
            % Get the vector
            vecs=-results{ss}.(directionLabels{dd}).(contrastLabels{cc}).OffOn.palpFissure;
            vecs(5:8,:)=results{ss}.(directionLabels{dd}).(contrastLabels{cc}).OnOff.palpFissure;
            vec = mean(vecs,'omitmissing');
            % Fit the vector
            [amplitude, phase] = fitFourier(vec, 'fitFreqHz', 1/60);
            % Store the results
            fitResults.(directionLabels{dd}).(contrastLabels{cc}).amplitude(ss)=amplitude;
            fitResults.(directionLabels{dd}).(contrastLabels{cc}).phase(ss)=phase;
        end
        nexttile((cc-1)*length(directions)+directionPlotOrder(dd))
        plotFourierFits(fitResults.(directionLabels{dd}).(contrastLabels{cc}).amplitude,...
        fitResults.(directionLabels{dd}).(contrastLabels{cc}).phase,directionColors{dd});
        title([directionLabels{dd} ' ' contrastLabels{cc}]);
        rlim([0 0.4]);
    end
end

% Make a summary figure
figure
t = 0:1/options.fps:(nFrames-1)/options.fps;
figure
plot(t,zeros(size(t)),'-k');
hold on
for dd = 1:length(directions)
    for cc = 1:length(contrasts)
        for ss = 1:length(subjects)
            vecs=-results{ss}.(directionLabels{dd}).(contrastLabels{cc}).OffOn.palpFissure;
            vecs(5:8,:)=results{ss}.(directionLabels{dd}).(contrastLabels{cc}).OnOff.palpFissure;
            avgSubVec(ss,:) = mean(vecs,'omitmissing');
        end
        mu = mean(avgSubVec,'omitmissing');
        plot(t,mu,[directionColors{dd} '-'],'LineWidth',contrastLineWidth(cc));
        [~, ~,yFit] = fitFourier(mu, 'fitFreqHz', 1/60);
        plot(t,yFit,[directionColors{dd} '-'],'LineWidth',contrastLineWidth(cc));
    end
end
xlabel('Time [secs]');
ylabel('proportion ∆ eye closure');
title('Across subject average');