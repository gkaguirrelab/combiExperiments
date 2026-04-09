function plotSummaryPolar(fourierFitResults,options)


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
for cc = 1:length(contrastLabels)
    nexttile((cc-1)*(length(directionLabels)+1)+length(directionLabels)+1)
    for dd = 1:length(directionLabels)
        amplitude = fourierFitResults.(directionLabels{dd}).(contrastLabels{cc}).amplitude;
        phase = fourierFitResults.(directionLabels{dd}).(contrastLabels{cc}).phase;
        % Add the bivariate ellipse for this direction and contrast
        plotPolarBivariateEllipse(amplitude,phase,'errorType','sem',...
            'FillEdgeColor',directionLineColors{dd},...
            'FillFaceColor',directionColors{dd},...
            'FillFaceAlpha',0.1,...
            'MarkerSymbol','.','MarkerEdgeColor',directionLineColors{dd});
    end
    % Add lines to show the vector addition of the LMS and Mel
    theta_mel = fourierFitResults.Mel.(contrastLabels{cc}).phase;
    rho_mel = fourierFitResults.Mel.(contrastLabels{cc}).amplitude;
    theta_lms = fourierFitResults.LMS.(contrastLabels{cc}).phase;
    rho_lms = fourierFitResults.LMS.(contrastLabels{cc}).amplitude;
    [x_mel,y_mel]=pol2cart(theta_mel,rho_mel);
    [x_lms,y_lms]=pol2cart(theta_lms,rho_lms);
    [theta_sum,rho_sum]=cart2pol(mean(x_mel)+mean(x_lms),mean(y_mel)+mean(y_lms));
    polarplot([theta_sum,theta_sum],[0,rho_sum],':k');
    % Clean up
    title([directionLabels{dd} ' ' contrastLabels{cc}]);
    rlim([0 0.25]);
    a = gca();
    a.ThetaZeroLocation = 'top';
    a.Box = 'off';
    a.ThetaTickLabel = {};
    a.RTickLabel = {};
    title(['Group: ' contrastLabels{cc}]);
end