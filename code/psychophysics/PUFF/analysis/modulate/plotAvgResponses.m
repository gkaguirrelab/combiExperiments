function plotAvgResponses(avgResults,options)

arguments
    avgResults
    options.directionColors = {[0 0 0],[0 1 1],[1 0.75 0],[0 0 1]}
    options.contrastLineSpec = {'-',':'}
    options.contrastLineWidth = [2,2]
    options.fps = 180;
end

directionColors = options.directionColors;

% Extract the number of subjects, and direction, contrast, and phase labels
% from the results structure
directionLabels = fieldnames(avgResults);
contrastLabels = fieldnames(avgResults.(directionLabels{1}));

% Create a bar plot with the mean±SEM across subjects for each direction.
for dd = 1:length(directionLabels)
    for cc = 1:length(contrastLabels)        
    meanAmp(dd,cc) = avgResults.(directionLabels{dd}).(contrastLabels{cc}).meanAmplitude;
    semAmp(dd,cc) = avgResults.(directionLabels{dd}).(contrastLabels{cc}).semAmplitude;
    end
end
figure('WindowStyle', 'normal');
b = bar(meanAmp, 'grouped');
hold on;
for ii = 1:size(meanAmp, 2)
    b(ii).FaceColor = 'flat';
    b(ii).EdgeColor = 'none';
    x_coords = b(ii).XEndPoints;
    for jj = 1:size(meanAmp, 1) % Loop through direction rows
        b(ii).CData(jj,:) = directionColors{jj};
        if ii == 1
            b(ii).FaceAlpha = 0.75;
        else
            b(ii).FaceAlpha = 0.25;
        end
        errorbar(x_coords, meanAmp(:,ii), semAmp(:,ii),...
            'Color', [0.5 0.5 0.5], ...     % Set color to grey
            'LineStyle', 'none', ...  % Remove connecting lines
            'LineWidth', 3, ...     % Adjust thickness
            'CapSize', 0);            % Removes the horizontal caps
    end
end
set(gca, 'XTickLabel', directionLabels);
xlabel('Direction');
ylabel('Proportion ∆ eye closure');
title('Across subject average response');
legend(contrastLabels, 'Location', 'northeast');
grid off;
box off
hold off;


% Make a summary time-series figure
figure('WindowStyle', 'normal');
tiledlayout(1,length(directionLabels),"TileSpacing","tight")
t = 0:1/options.fps:(length(avgResults.(directionLabels{1}).(contrastLabels{1}).palpFissure)-1)/options.fps;
for dd = 1:length(directionLabels)
    nexttile(dd)
    plot(t,zeros(size(t)),'--k');
    hold on
    for cc = 1:length(contrastLabels)
        mu = avgResults.(directionLabels{dd}).(contrastLabels{cc}).palpFissure;
        [~, ~,yFit] = fitFourier(mu, 'fitFreqHz', 1/60);
        plot(t,yFit,'-','Color',directionColors{dd},'LineWidth',options.contrastLineWidth(cc)*2);
        plot(t,mu,options.contrastLineSpec{cc},'Color',directionColors{dd},'LineWidth',options.contrastLineWidth(cc));
    end
    axis square
    xlabel('Time [secs]');
    box off
    a = gca();
    a.TickDir = 'out';
    ylim([-0.2 0.2]);
    if dd == 1
        ylabel('Proportion ∆ eye closure');
        a.YTick = [-0.2,-0.1,0,0.1,0.2];
    else
        a.YAxis.Visible = 'off';
    end
    title(directionLabels{dd});
end



end
