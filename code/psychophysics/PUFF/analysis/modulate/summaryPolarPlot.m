function summaryPolarPlot(fourierFitResults,options)


arguments
    fourierFitResults
    options.directionColors = {[0 0 0],[0 1 1],[1 0.75 0],[0 0 1]}
    options.directionLineColors = {'k','c',[1 0.75 0],'b'};
    options.contrastLineSpec = {'-',':'}
    options.contrastLineWidth = [2,2]
end

directionColors = options.directionColors;
directionLineColors = options.directionLineColors;

% Extract the number of subjects, and direction, contrast, and phase labels
% from the results structure
directionLabels = fieldnames(fourierFitResults);
contrastLabels = fieldnames(fourierFitResults.(directionLabels{1}));

% Create a figure with a polar plot with the mean±SEM across subjects for
% each direction. Two panels, one for high contrast, one for low
figure('WindowStyle', 'normal');
for dd = 1:length(directionLabels)
    for cc = 1:length(contrastLabels)
        nexttile((cc-1)*(length(directionLabels)+1)+length(directionLabels)+1)
        amplitude = fourierFitResults.(directionLabels{dd}).(contrastLabels{cc}).amplitude;
        phase = fourierFitResults.(directionLabels{dd}).(contrastLabels{cc}).phase;
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