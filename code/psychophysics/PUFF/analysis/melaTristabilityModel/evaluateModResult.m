clear
subjectID = 'BLNK_1001';
directions = {'LightFlux','Mel','LMS','S_peripheral','LminusM_MelSilent_peripheral'};
dirLabels = {'LF','Mel','LMS','S','L-M'};
photoContrast = [0.4,0.4,0.4,0.4,0.1];

% Get the dropbox path
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');

% Preallocate matrices to store delta fractions and absolute steady states
deltaFraction_pos = zeros(3, length(directions));
deltaFraction_neg = zeros(3, length(directions));
steadyStatePos_all = zeros(3, length(directions));
steadyStateNeg_all = zeros(3, length(directions));

% Prepare a figure for kinetics
figure('Color', 'w');
tiledlayout(1,length(directions),'TileSpacing','tight');

for dd = 1:length(directions)
    % Load this modResult
    filename = ['modResult_' directions{dd} '.mat'];
    filepath = fullfile(dropBoxBaseDir,'BLNK_data','PuffLight','modulate',subjectID);
    load(fullfile(filepath,filename),'modResult');
    
    % Extract S, and the background spectrum
    S = modResult.meta.cal.rawData.S;
    
    % If this is the first direction, obtain the lens transmittance for this observer
    if dd == 1
        observerAgeInYears = modResult.meta.photoreceptors(1).observerAgeInYears;
        pupilDiameterMm = modResult.meta.photoreceptors(1).pupilDiameterMm;
        lensTransmitt = LensTransmittance(S,...
            'Human','StockmanSharpe',...
            observerAgeInYears,pupilDiameterMm)';
    end
    
    % Load the background spd
    backspd = modResult.backgroundSPD;
    
    % Calculate initial state after adapting to background spd
    if dd == 1
        irradianceSPD = convertToMolarSpd(convertToPhotonSpd(backspd.*lensTransmitt,S,"pupilRadiusMm",pupilDiameterMm/2));
        fractionsPos = melaStateModel(irradianceSPD,S, [1 0 0]);
        initialState = fractionsPos(end,:);
    end
    
    % Modulation contrast
    maxPhotoContrast = mean(abs(modResult.contrastReceptorsBipolar(modResult.meta.whichReceptorsToTarget)));
    modContrast = photoContrast(dd) / maxPhotoContrast;
    
    % Positive and negative spds
    posspd = backspd + modContrast * (modResult.positiveModulationSPD - backspd);
    negspd = backspd + modContrast * (modResult.negativeModulationSPD - backspd);
    
    % Adjust for lens transmittance
    posspd = posspd.*lensTransmitt;
    negspd = negspd.*lensTransmitt;
    
    % Move to next tile
    nexttile;
    hold on;
    
    % State plot for positive modulation
    irradianceSPD = convertToMolarSpd(convertToPhotonSpd(posspd,S,"pupilRadiusMm",pupilDiameterMm/2));
    [fractionsPos, t] = melaStateModel(irradianceSPD, S, initialState);
    plot(t, fractionsPos(:,1), 'k', 'LineWidth', 2);
    plot(t, fractionsPos(:,2), 'b', 'LineWidth', 2);
    plot(t, fractionsPos(:,3), 'r', 'LineWidth', 2);
    drawnow
    
    % State plot for negative modulation
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
    
    % Store steady-state fractions and delta values
    steadyStatePos = fractionsPos(end, :);
    steadyStateNeg = fractionsNeg(end, :);
    
    steadyStatePos_all(:, dd) = steadyStatePos';
    steadyStateNeg_all(:, dd) = steadyStateNeg';
    
    deltaFraction_pos(:, dd) = steadyStatePos - initialState;
    deltaFraction_neg(:, dd) = steadyStateNeg - initialState;
end

%% --- Create Bar Plot Figure ---
figure('Color', 'w', 'Name', 'Steady-State Absolute Change');
tl = tiledlayout(1, 2, 'TileSpacing', 'compact');
stateColors = [0 0 0; 0 0 1; 1 0 0]; 
fillOpacity = 0.4;

% 1. Positive Modulation Bar Plot
nexttile;
bPos = bar(deltaFraction_pos', 'grouped');
for k = 1:3
    bPos(k).FaceColor = stateColors(k, :);
    bPos(k).FaceAlpha = fillOpacity;
    bPos(k).EdgeColor = stateColors(k, :);
    bPos(k).LineStyle = '-';
    bPos(k).LineWidth = 1.5;
end
set(gca, 'XTickLabel', dirLabels, 'FontSize', 11);
ylabel('\Delta Pigment Fraction');
title('Positive Peak Modulation');
grid on;
ylim([-0.04 0.04]);
legend({'R (Melanopsin)', 'M (Metamelanopsin)', 'E (Extramelanopsin)'}, 'Location', 'best');

% 2. Negative Modulation Bar Plot
nexttile;
bNeg = bar(deltaFraction_neg', 'grouped');
for k = 1:3
    bNeg(k).FaceColor = stateColors(k, :);
    bNeg(k).FaceAlpha = fillOpacity;
    bNeg(k).EdgeColor = stateColors(k, :);
    bNeg(k).LineStyle = '--';
    bNeg(k).LineWidth = 1.5;
end
set(gca, 'XTickLabel', dirLabels, 'FontSize', 11);
ylabel('\Delta Pigment Fraction');
title('Negative Peak Modulation');
grid on;
ylim([-0.04 0.04]);

title(tl, ['Steady-State \Delta Pigment Fraction (' subjectID ')'], ...
    'FontSize', 14, 'FontWeight', 'bold');

%% --- Create Species Distribution Shift Plot (Pos vs. Neg) ---
figure('Color', 'w', 'Name', 'Pigment Species Shift', 'Units', 'normalized', 'Position', [0.12, 0.3, 0.75, 0.4]);
tLayout3 = tiledlayout(1, length(directions), 'Padding', 'compact', 'TileSpacing', 'compact');
speciesColors = [0 0 0; 0 0 1; 1 0 0]; % Black (R), Blue (M), Red (E)
fullSpeciesNames = {'R (Melanopsin)', 'M (Metamelanopsin)', 'E (Extramelanopsin)'};

% Store line handles for the external legend
hLines = gobjects(1, 3);

for dd = 1:length(directions)
    ax = nexttile;
    
    % Data matrix: 3 rows (R, M, E) x 2 cols (Pos, Neg)
    dataPlot = [steadyStatePos_all(:, dd), steadyStateNeg_all(:, dd)]; 
    
    hold on;
    % Plot lines connecting Positive to Negative state values
    for sp = 1:3
        h = plot([1, 2], dataPlot(sp, :), '-o', ...
            'Color', speciesColors(sp, :), ...
            'LineWidth', 2, ...
            'MarkerFaceColor', speciesColors(sp, :), ...
            'MarkerSize', 6);
        
        if dd == 1
            hLines(sp) = h; % Save handles from first tile for legend
        end
    end
    hold off;
    
    title(dirLabels{dd}, 'FontSize', 12, 'FontWeight', 'bold');
    xlim([0.6, 2.4]);
    xticks([1, 2]);
    xticklabels({'Pos', 'Neg'});
    ylim([0, 1]);
    yticks(0:0.2:1); % Explicitly define YTicks so grid lines align across all tiles
    
    % Horizontal gridlines only (no vertical lines)
    ax.XGrid = 'off';
    ax.YGrid = 'on';
    
    % Y-axis formatting: show labels and tick numbers ONLY on the first plot
    if dd == 1
        ylabel('Pigment Fraction', 'FontSize', 11);
    else
        % Keep ticks/grid intact, but suppress numbers
        ax.YAxis.TickLabels = {}; 
    end
end

% Single legend placed outside all subplots on the right
lgd = legend(hLines, fullSpeciesNames, 'Location', 'eastoutside');
lgd.Layout.Tile = 'east'; 
title(tLayout3, 'Pigment Species Shift Across Modulations', ...
    'FontSize', 14, 'FontWeight', 'bold');