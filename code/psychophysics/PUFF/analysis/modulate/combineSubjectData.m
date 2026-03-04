close all
clear

% Define the list of subjects. Data from subject BLNK_1010 was excluded
% post-hoc due to constant movement during recordings, which caused more
% than 50% loss of measurements in the majority of trials.
subjects = {'BLNK_1001','BLNK_1002','BLNK_1003','BLNK_1005','BLNK_1006',...
    'BLNK_1007','BLNK_1008','BLNK_1009','BLNK_1011','BLNK_1012'};

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
directionColors = {[0 1 1],[1 0.75 0],[0 0 1],[0 0 0]};
directionLineColors = {'c',[1 0.75 0],'b','k'};
directionPlotOrder = [2 3 4 1];
contrastLineWidth = [2,2];
contrastLineSpec = {'-',':'};


% Get the results
for ss = 1:length(subjects)
    results{ss} = processModulateVideos(subjects{ss},'makePlotFlag',false);
end

% Create a figure with a separate sub-plot for each direction and contrast.
% Each figure shows the mean and 1SEM bivariate ellipse of the measurement
% for each subject
fh{1} = figure('WindowStyle', 'normal');
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
            d = sqrt((x - mu_x).^2 + (y - mu_y).^2);
            semAmp = std(d); % The standard deviation of the boot-strap values
            % is the standard error of the mean
            [mu_phase, mu_amp] = cart2pol(mu_x, mu_y);
            % Store the results
            fitResults.(directionLabels{dd}).(contrastLabels{cc}).amplitude(ss)=mu_amp;
            fitResults.(directionLabels{dd}).(contrastLabels{cc}).phase(ss)=mu_phase;
            fitResults.(directionLabels{dd}).(contrastLabels{cc}).amplitudeSEM(ss)=semAmp;
            % Add the bivariate ellipse for this subject
            plotPolarBivariateEllipse(amplitude,phase,'errorType','sd',...
                'FillEdgeColor',directionLineColors{dd},...
                'FillFaceColor',directionColors{dd},...
                'FillFaceAlpha',0.1,...
                'MarkerSymbol','none');
        end
        title([directionLabels{dd} ' ' contrastLabels{cc}]);
        rlim([0 0.5]);
        a = gca();
        a.Box = 'off';
        a.ThetaTickLabel = {};
        a.RTickLabel = {};
    end
end

% Create a bar plot with the mean±SEM across subjects for
% each direction.
barPlotOrder=[4,1,2,3];
for dd = 1:length(directions)
    for cc = 1:length(contrasts)
        for ss = 1:length(subjects)
            vecs=-results{ss}.(directionLabels{dd}).(contrastLabels{cc}).OffOn.palpFissure;
            vecs(5:8,:)=results{ss}.(directionLabels{dd}).(contrastLabels{cc}).OnOff.palpFissure;
            avgSubVec(ss,:) = mean(vecs,'omitmissing');
        end
            [amplitude, phase] = fitFourier(avgSubVec, 'fitFreqHz', 1/60, 'returnBoots', true);
        [x, y] = pol2cart(phase, amplitude);
        mu_x = mean(x); mu_y = mean(y);
        % Some phase work here to get the positive and negative phase
        % values to correspond to the positive and negative directions of
        % eye closure response
        meanPhase(dd,cc) = wrapToPi(atan2(mu_y, mu_x)+pi/2);
        d = sqrt((x - mu_x).^2 + (y - mu_y).^2);
        semAmp(dd,cc) = std(d); % The standard deviation of the boot-strap values
        % is the standard error of the mean
        if meanPhase(dd,cc) >= 0
            meanAmp(dd,cc)=mean(amplitude);
        else
            meanAmp(dd,cc)=-mean(amplitude);
        end
    end
end
fh{2} = figure('WindowStyle', 'normal');
b = bar(meanAmp(barPlotOrder,:), 'grouped');
hold on;
for ii = 1:size(meanAmp, 2)
    b(ii).FaceColor = 'flat';
    b(ii).EdgeColor = 'none';
    x_coords = b(ii).XEndPoints;
    for jj = 1:size(meanAmp, 1) % Loop through direction rows
        b(ii).CData(jj,:) = directionColors{barPlotOrder(jj)};
        if ii == 1
            b(ii).FaceAlpha = 0.75;
        else
            b(ii).FaceAlpha = 0.25;
        end
        errorbar(x_coords, meanAmp(barPlotOrder,ii), semAmp(barPlotOrder,ii),...
            'Color', [0.5 0.5 0.5], ...     % Set color to grey
            'LineStyle', 'none', ...  % Remove connecting lines
            'LineWidth', 3, ...     % Adjust thickness
            'CapSize', 0);            % Removes the horizontal caps
    end
end
set(gca, 'XTickLabel', directionLabels(barPlotOrder));
xlabel('Direction');
ylabel('Proportion ∆ eye closure');
title('Across subject average response');
legend(contrastLabels, 'Location', 'northeast');
grid off;
box off
hold off;


% Create a figure with a polar plot with the mean±SEM across subjects for
% each direction. Two panels, one for high contrast, one for low
fh{3} = figure('WindowStyle', 'normal');
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
        rlim([0 0.25]);
        a = gca();
        a.Box = 'off';
        a.ThetaTickLabel = {};
        a.RTickLabel = {};
        title(['Group: ' contrastLabels{cc}]);
    end
end


% Make a summary time-series figure
fh{4} = figure('WindowStyle', 'normal');
tiledlayout(1,length(directions),"TileSpacing","tight")
t = 0:1/options.fps:(nFrames-1)/options.fps;
for dd = 1:length(directions)
    nexttile(directionPlotOrder(dd))
    plot(t,zeros(size(t)),'--k');
    hold on
    for cc = 1:length(contrasts)
        for ss = 1:length(subjects)
            vecs=-results{ss}.(directionLabels{dd}).(contrastLabels{cc}).OffOn.palpFissure;
            vecs(5:8,:)=results{ss}.(directionLabels{dd}).(contrastLabels{cc}).OnOff.palpFissure;
            avgSubVec(ss,:) = mean(vecs,'omitmissing');
        end
        mu = mean(avgSubVec,'omitmissing');
        [~, ~,yFit] = fitFourier(mu, 'fitFreqHz', 1/60);
        plot(t,yFit,'-','Color',directionColors{dd},'LineWidth',contrastLineWidth(cc)*2);
        plot(t,mu,contrastLineSpec{cc},'Color',directionColors{dd},'LineWidth',contrastLineWidth(cc));
    end
    axis square
    xlabel('Time [secs]');
    box off
    a = gca();
    a.TickDir = 'out';
    ylim([-0.2 0.2]);
    if directionPlotOrder(dd) == 1
        ylabel('Proportion ∆ eye closure');
        a.YTick = [-0.2,-0.1,0,0.1,0.2];
    else
        a.YAxis.Visible = 'off';
    end
    title(directionLabels{dd});
end

% Make a plot of individual variation
dirSets = {{'S','Mel'},{'S','LMS'}};
conX = 'High'; conY = 'High';
figure
tiledlayout(1,length(dirSets));
for dd = 1:length(dirSets)

    dirX = dirSets{dd}{1}; dirY = dirSets{dd}{2};
    signSet = sign(wrapToPi(fitResults.(dirX).(conX).phase+pi/2));
    xVals = fitResults.(dirX).(conX).amplitude .* signSet;
    xSEM = fitResults.(dirX).(conX).amplitudeSEM;

    signSet = sign(wrapToPi(fitResults.(dirY).(conY).phase+pi/2));
    yVals = fitResults.(dirY).(conY).amplitude .* signSet;
    ySEM = fitResults.(dirY).(conY).amplitudeSEM;
    nexttile
    plot([-0.4,0.4],[0,0],'--k');
    hold on
    plot([0,0],[-0.4,0.4],'--k');
    h = errorbar(xVals, yVals, ySEM, ySEM, xSEM, xSEM, 'o');
    h.CapSize = 0;
    h.MarkerFaceColor = [1 0 0]; % Fills the circles
    h.MarkerEdgeColor = 'w';
    h.MarkerSize = 12;
    h.Color = [0.5 0.5 0.5]; % Makes the error bar lines a dark grey
    h.LineWidth = 2;
    axis square
    xlim([-0.3 0.3]);
    ylim([-0.3 0.3]);
    box off
    xlabel([dirX ' response amplitude']);
    ylabel([dirY ' response amplitude']);
    a = gca();
    a.TickDir = 'out';
    a.XTick = [-0.3, -0.15, 0, 0.15, 0.3];
    a.YTick = [-0.3, -0.15, 0, 0.15, 0.3];
end

% Fit the photoreceptor integration model and make a plot
fitWeightModel(fitResults);
