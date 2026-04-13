function plotIndividVariation(fourierFitResults, options)

arguments
    fourierFitResults
    options.dirSets = {{'S','Mel'},{'S','LMS'}}
    options.contrastLabel = 'High';
end

% Make a plot of individual variation
dirSets = options.dirSets;
conX = options.contrastLabel; conY = options.contrastLabel;
figure('WindowStyle', 'normal');
tiledlayout(1,length(dirSets));
for dd = 1:length(dirSets)

    dirX = dirSets{dd}{1}; dirY = dirSets{dd}{2};
    signSet = sign(wrapToPi(fourierFitResults.(dirX).(conX).phase+pi/2));
    xVals = fourierFitResults.(dirX).(conX).amplitude .* signSet;
    xSEM = fourierFitResults.(dirX).(conX).amplitudeSEM;

    signSet = sign(wrapToPi(fourierFitResults.(dirY).(conY).phase+pi/2));
    yVals = fourierFitResults.(dirY).(conY).amplitude .* signSet;
    ySEM = fourierFitResults.(dirY).(conY).amplitudeSEM;
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

end