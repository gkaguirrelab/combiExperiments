close all
clear

% Define the list of subjects. Data from subject BLNK_1010 was excluded
% post-hoc due to constant movement during recordings, which caused more
% than 50% loss of measurements in the majority of trials.
subjects = {'BLNK_1001'};

% Current half-finished subjects: _1002, _1003

% Define temporal properties of the recording
options.fps = 180;
options.vecDurSecs = 60;
nFrames = options.vecDurSecs * options.fps;

% Define the stimulus properties
directions = {'S_peripheral','LminusM_MelSilent_peripheral'};
directionLabels = {'S','LminusM'};
phaseLabels = {'OnOff','OffOn'};
contrastLabels = {'Max'};
phases = [0,pi];
contrasts = {[0.7,0.1]};
nTrials = 8;

% Store these stimulus settings in an options variable for the
% processModulateVideos function
stimOpts.directions = directions;
stimOpts.directionLabels = directionLabels;
stimOpts.phaseLabels = phaseLabels;
stimOpts.contrastLabels = contrastLabels;
stimOpts.phases = phases;
stimOpts.contrasts = contrasts;
stimOpts.nTrials = nTrials;
stimOpts.makePlotFlag = false;
stimOpts = namedargs2cell(stimOpts);

% Define plot properties
directionColors = {'b','r'};
directionLineColors = {'b','r'};
directionPlotOrder = [1,2];
contrastLineWidth = 3;


% Get the results
for ss = 1:length(subjects)
    results{ss} = processModulateVideos(subjects{ss},stimOpts{:});
end

% Create a figure with a separate sub-plot for each direction and contrast.
% Each figure shows the mean and 1SEM bivariate ellipse of the measurement
% for each subject
fh1 = figure();
tiledlayout(length(contrasts),length(directions)+1)
for dd = 1:length(directions)
    for cc = 1:length(contrasts)
        nexttile((cc-1)*(length(directions)+1)+directionPlotOrder(dd))
        for ss = 1:length(subjects)
            % Get the vector
            vecs=-results{ss}.(directionLabels{dd}).(contrastLabels{cc}).OffOn.palpFissure;
            vecs(nTrials+1:nTrials*2,:)=results{ss}.(directionLabels{dd}).(contrastLabels{cc}).OnOff.palpFissure;
            % Get a set of boot-strapped amplitude and phase values
            [amplitude, phase] = fitFourier(vecs, 'fitFreqHz', 1/60, 'returnBoots', true);
            % Obtain the mean within Cartesian space, then covert back
            [x, y] = pol2cart(phase, amplitude);
            mu_x = mean(x); mu_y = mean(y);
            [mu_phase, mu_amp] = cart2pol(mu_x, mu_y);
            % Store the results
            fitResults.(directionLabels{dd}).(contrastLabels{cc}).amplitude(ss)=mu_amp;
            fitResults.(directionLabels{dd}).(contrastLabels{cc}).phase(ss)=mu_phase;
            fitResults.(directionLabels{dd}).(contrastLabels{cc}).amplitude(ss)=mu_amp;
            fitResults.(directionLabels{dd}).(contrastLabels{cc}).phase(ss)=mu_phase;
            % Add the bivariate ellipse for this subject; we rotate -pi/2
            % so that up in the polar plot is eye closing, and down is eye
            % opening
            plotPolarBivariateEllipse(amplitude,phase,'errorType','sd',...
                'FillEdgeColor',directionLineColors{dd},...
                'FillFaceColor',directionColors{dd},...
                'FillFaceAlpha',0.1,...
                'MarkerSymbol','none');
        end
        title([directionLabels{dd} ' ' contrastLabels{cc}]);
        rlim([0 0.4]);
        a = gca();
        a.ThetaZeroLocation = 'bottom';
        a.Box = 'off';
        a.ThetaTickLabel = {};
        a.RTickLabel = {};
    end
end


% Create a figure with a polar plot with the mean±SEM across subjects for
% each direction. Two panels, one for high contrast, one for low
for dd = 1:length(directions)
    for cc = 1:length(contrasts)
        nexttile((cc-1)*(length(directions)+1)+length(directions)+1)
        amplitude = fitResults.(directionLabels{dd}).(contrastLabels{cc}).amplitude;
        phase = fitResults.(directionLabels{dd}).(contrastLabels{cc}).phase;
        % Add the bivariate ellipse for this direction and contrast
        plotPolarBivariateEllipse(amplitude,phase,'errorType','sem',...
            'FillEdgeColor',directionLineColors{dd},...
            'FillFaceColor',directionColors{dd},...
            'FillFaceAlpha',0.1,...
            'MarkerSymbol','.','MarkerEdgeColor',directionLineColors{dd});
        title([directionLabels{dd} ' ' contrastLabels{cc}]);
        rlim([0 0.2]);
        a = gca();
        a.ThetaZeroLocation = 'bottom';
        a.Box = 'off';
        a.ThetaTickLabel = {};
        a.RTickLabel = {};
        title(['Group: ' contrastLabels{cc}]);
    end
end




% Make a summary time-series figure
figure
t = 0:1/options.fps:(nFrames-1)/options.fps;
plot(t,zeros(size(t)),'-k');
hold on
for dd = 1:length(directions)
    for cc = 1:length(contrasts)
        for ss = 1:length(subjects)
            vecs=-results{ss}.(directionLabels{dd}).(contrastLabels{cc}).OffOn.palpFissure;
            vecs(nTrials+1:nTrials*2,:)=results{ss}.(directionLabels{dd}).(contrastLabels{cc}).OnOff.palpFissure;
            avgSubVec(ss,:) = mean(vecs,'omitmissing');
        end
        mu = mean(avgSubVec,'omitmissing');
        plot(t,mu,[directionColors{dd} '-'],'LineWidth',contrastLineWidth(cc));
        [~, ~,yFit] = fitFourier(mu, 'fitFreqHz', 1/60);
%        plot(t,yFit,[directionColors{dd} '-'],'LineWidth',contrastLineWidth(cc));
    end
end
xlabel('Time [secs]');
ylabel('proportion ∆ eye closure');
title('Across subject average');