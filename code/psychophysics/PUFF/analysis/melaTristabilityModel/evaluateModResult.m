clear

subjectID = 'BLNK_1001';
directions = {'LightFlux','Mel','LMS','S_peripheral','LminusM_MelSilent_peripheral'};
dirLabels = {'LF','Mel','LMS','S','L-M'};
photoContrast = [0.4,0.4,0.4,0.4,0.1];

% Get the dropbox path
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');

% Prepare a figure
figure('Color', 'w');
tiledlayout(1,length(directions),'TileSpacing','tight');

for dd = 1:length(directions)

    % Load this modResult
    filename = ['modResult_' directions{dd} '.mat'];
    filepath = fullfile(dropBoxBaseDir,'BLNK_data','PuffLight','modulate',subjectID);
    load(fullfile(filepath,filename),'modResult');

    % Extract S, and the background spectrum
    S = modResult.meta.cal.rawData.S;

    % If this is the first direction, obtain the lens transmittance for
    % this observer
    if dd == 1
        % Get the lens transmittance for this observer
        observerAgeInYears = modResult.meta.photoreceptors(1).observerAgeInYears;
        pupilDiameterMm = modResult.meta.photoreceptors(1).pupilDiameterMm;
        lensTransmitt = LensTransmittance(S,...
            'Human','StockmanSharpe',...
            observerAgeInYears,pupilDiameterMm)';
    end

    % Load the background spd; we don't correct for lens transmittance
    % just yet, as we need this original spd to derive the positive and
    % negative spds
    backspd = modResult.backgroundSPD;

    % If this is the first direction, calculate the
    % initial state after adapting to the background spd
    if dd == 1
        irradianceSPD = convertToMolarSpd(convertToPhotonSpd(backspd.*lensTransmitt,S,"pupilRadiusMm",pupilDiameterMm/2));
        fractionsPos = melaStateModel(irradianceSPD,S, [1 0 0]);
        initialState = fractionsPos(end,:);
    end

    % Calculate the modulation contrast needed to achieve the called-for
    % photoreceptor contrast
    maxPhotoContrast = mean(abs(modResult.contrastReceptorsBipolar(modResult.meta.whichReceptorsToTarget)));
    modContrast = photoContrast(dd) / maxPhotoContrast;

    % Produce the positive and negative spds
    posspd = backspd + modContrast * (modResult.positiveModulationSPD - backspd);
    negspd = backspd + modContrast * (modResult.negativeModulationSPD - backspd);

    % Adjust for lens transmittance
    posspd = posspd.*lensTransmitt;
    negspd = negspd.*lensTransmitt;

    % Move to the next tile
    nexttile;
    hold on;

    % Get the state plot for the positive, then negative modulations.
    irradianceSPD = convertToMolarSpd(convertToPhotonSpd(posspd,S,"pupilRadiusMm",pupilDiameterMm/2));
    [fractionsPos, t] = melaStateModel(irradianceSPD, S, initialState);
    plot(t, fractionsPos(:,1), 'k', 'LineWidth', 2);
    plot(t, fractionsPos(:,2), 'b', 'LineWidth', 2);
    plot(t, fractionsPos(:,3), 'r', 'LineWidth', 2);
    drawnow

    irradianceSPD = convertToMolarSpd(convertToPhotonSpd(negspd,S,"pupilRadiusMm",pupilDiameterMm/2));
    [fractionsNeg, t] = melaStateModel(irradianceSPD, S, initialState);
    plot(t, fractionsNeg(:,1), ':k', 'LineWidth', 2);
    plot(t, fractionsNeg(:,2), ':b', 'LineWidth', 2);
    plot(t, fractionsNeg(:,3), ':r', 'LineWidth', 2);
    drawnow

    xlabel('time [secs]'); ylabel('Pigment Fraction');
    if dd == 1
        legend('R (Melanopsin)', 'M (Metamelanopsin)', 'E (Extramelanopsin)');
    end
    title(dirLabels{dd},'Interpreter','none');
    ylim([0 1]);

    % Delta Fraction = State_steady - State_bg
    steadyStatePos = fractionsPos(end, :);
    steadyStateNeg = fractionsNeg(end, :);
    
    deltaFraction_pos(:, dd) = steadyStatePos - initialState;
    deltaFraction_neg(:, dd) = steadyStateNeg - initialState;
end

%% --- Create Bar Plot Figure ---
figure('Color', 'w', 'Name', 'Steady-State Absolute Change');
tl = tiledlayout(1, 2, 'TileSpacing', 'compact');

% Colors matching the kinetics plots: R (Black), M (Blue), E (Red)
stateColors = [0 0 0; 0 0 1; 1 0 0]; 
fillOpacity = 0.4; % Set desired fill opacity (0 = transparent, 1 = opaque)

% 1. Positive Modulation Bar Plot (Solid outlines, lower opacity fill)
nexttile;
bPos = bar(deltaFraction_pos', 'grouped');
for k = 1:3
    bPos(k).FaceColor = stateColors(k, :);
    bPos(k).FaceAlpha = fillOpacity;       % Lower opacity fill
    bPos(k).EdgeColor = stateColors(k, :); % Solid outline matching bar color
    bPos(k).LineStyle = '-';               % Solid line
    bPos(k).LineWidth = 1.5;
end
set(gca, 'XTickLabel', dirLabels, 'FontSize', 11);
ylabel('\Delta Pigment Fraction');
title('Positive Peak Modulation');
grid on;
ylim([-0.04 0.04]);
legend({'R (Melanopsin)', 'M (Metamelanopsin)', 'E (Extramelanopsin)'}, 'Location', 'best');

% 2. Negative Modulation Bar Plot (Dotted outlines, lower opacity fill)
nexttile;
bNeg = bar(deltaFraction_neg', 'grouped');
for k = 1:3
    bNeg(k).FaceColor = stateColors(k, :);
    bNeg(k).FaceAlpha = fillOpacity;       % Lower opacity fill
    bNeg(k).EdgeColor = stateColors(k, :); % Outline matching bar color
    bNeg(k).LineStyle = '--';              % Dashed line
    bNeg(k).LineWidth = 1.5;
end
set(gca, 'XTickLabel', dirLabels, 'FontSize', 11);
ylabel('\Delta Pigment Fraction');
title('Negative Peak Modulation');
grid on;
ylim([-0.04 0.04]);

% Add overall title across subplots
title(tl, ['Steady-State \Delta Pigment Fraction (' subjectID ')'], ...
    'FontSize', 14, 'FontWeight', 'bold');

% %% --- Create Horizontal Stacked Proportions Bar Plot ---
% figure('Color', 'w', 'Name', 'State Proportions (100% Stacked)');
% 
% % 1. Gather proportions (%) for each state/direction
% prop_bg  = initialState * 100;                        % 1x3 vector [R, M, E]
% prop_pos = (initialState + deltaFraction_pos') * 100; % 5x3 matrix
% prop_neg = (initialState + deltaFraction_neg') * 100; % 5x3 matrix
% 
% % Combine rows into an 11x3 matrix: [Background; +Directions; -Directions]
% allProportions = [prop_bg; prop_pos; prop_neg];
% 
% % Define row y-tick labels
% rowLabels = [{'Background'}, strcat('+', dirLabels), strcat('-', dirLabels)];
% 
% % 2. Create Horizontal Stacked Bar Chart
% b = barh(allProportions, 'stacked');
% 
% % Apply colors matching your state kinetics: R (Black), M (Blue), E (Red)
% stateColors = [0 0 0; 0 0 1; 1 0 0];
% for k = 1:3
%     b(k).FaceColor = stateColors(k, :);
% end
% 
% % Format Axis and Labels
% set(gca, 'YTick', 1:length(rowLabels), ...
%          'YTickLabel', rowLabels, ...
%          'YDir', 'reverse', ... % Places Background at the top
%          'FontSize', 11);
% 
% xlabel('Pigment State Proportion (%)');
% ylabel('Condition');
% title(['Melanopsin State Proportions (100% Stacked) - ' subjectID]);
% xlim([0 100]);
% grid on;
% legend({'R (Melanopsin)', 'M (Metamelanopsin)', 'E (Extramelanopsin)'}, ...
%     'Location', 'eastoutside');