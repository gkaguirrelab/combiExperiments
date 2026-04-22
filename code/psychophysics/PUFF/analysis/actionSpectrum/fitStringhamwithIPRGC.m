%% BADS Optimization for Stringham Action Spectrum
% Finds global weights [w_mel, w_lm, w_s] to fit the photophobia data.

% 1. Load and Grid the Data
stringhamData = readtable('StringhamAvgPhotophobiaActionSpectrum.csv', 'NumHeaderLines', 1);

% Override digitized X with the intended 20nm clean grid
targetWl = (440:20:640)'; 
% Use the digitized Y-values (ensure we match the 11 points from 440-640)
targetLogSens = stringhamData.Y(1:length(targetWl));

% 2. Optimization Settings (BADS)
% Order: [w_mel, w_lm, w_s]
w0 = [1.0, 0.2, -0.1];  
lb = [-3, -3, -3];      
ub = [3, 3, 3];        
plb = [-1, 0, -1];      
pub = [2, 1, 0];        

% 3. Run Global Search for 2 Degrees (Foveal)
fprintf('Searching for 2-degree weights (Macular Pigment included)...\n');
bestW2 = bads(@(w) stringhamObjective(w, targetWl, targetLogSens, 2), ...
    w0, lb, ub, plb, pub);

% 4. Run Global Search for 10 Degrees (Peripheral)
fprintf('Searching for 10-degree weights (Minimal Macular Pigment)...\n');
bestW10 = bads(@(w) stringhamObjective(w, targetWl, targetLogSens, 10), ...
    w0, lb, ub, plb, pub);

%% 5. Plot Results
figure('Color', 'w', 'Position', [100 100 1200 500]);
tlo = tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'loose');

% Plot 2 Degrees
ax1 = nexttile(tlo); hold on;
renderFit(ax1, targetWl, targetLogSens, bestW2, 2, [0.8 0.2 0.2]);

% Plot 10 Degrees
ax2 = nexttile(tlo); hold on;
renderFit(ax2, targetWl, targetLogSens, bestW10, 10, [0.2 0.2 0.8]);

title(tlo, 'Global BADS Fit to Stringham Photophobia Data', 'FontSize', 16);

%% --- Support Functions ---

function rmse = stringhamObjective(w, targetWl, targetLogSens, fieldSize)
    % 1. Calculate the action spectrum
    [~, sense] = calculateActionSpectrum(ones(size(targetWl)), targetWl, ...
        'fieldSize', fieldSize, 'w_mel', w(1), 'w_lm', w(2), 'w_s', w(3));
    
    % 2. Force everything to be a COLUMN vector to avoid matrix expansion
    % sense.iprgcActionSpectrum is likely a row, targetLogSens is likely a column
    modelVals = sense.iprgcActionSpectrum(:);
    targetVals = targetLogSens(:);
    
    % 3. Calculate log sensitivity
    modelLog = log10(max(modelVals, 1e-6));
    
    % 4. Find optimal vertical offset (mean centering)
    % Now that both are column vectors, this will return a single scalar
    offset = mean(targetVals - modelLog);
    modelLog = modelLog + offset;
    
    % 5. Return the RMSE (Scalar)
    rmse = sqrt(mean((targetVals - modelLog).^2));
end

function renderFit(ax, wl, target, w, fieldSize, color)
    % Calculate smooth curve for plotting
    plotWl = (400:1:700)';
    [~, senseSmooth] = calculateActionSpectrum(ones(size(plotWl)), plotWl, ...
        'fieldSize', fieldSize, 'w_mel', w(1), 'w_lm', w(2), 'w_s', w(3));
    
    % Calculate at data points to find the correct alignment offset
    [~, sensePoints] = calculateActionSpectrum(ones(size(wl)), wl, ...
        'fieldSize', fieldSize, 'w_mel', w(1), 'w_lm', w(2), 'w_s', w(3));
    
    % Force column orientation for the offset calculation
    modelAtPoints = log10(max(sensePoints.iprgcActionSpectrum(:), 1e-6));
    targetVals = target(:);
    offset = mean(targetVals - modelAtPoints);
    
    % Draw plot
    plot(ax, wl, target, 'ko', 'MarkerFaceColor', 'k', 'DisplayName', 'Stringham Data');
    plot(ax, plotWl, log10(max(senseSmooth.iprgcActionSpectrum(:), 1e-6)) + offset, ...
        'Color', color, 'LineWidth', 3, 'DisplayName', 'Best Model Fit');
    
    title(ax, sprintf('%d Degree (CIE Observer)', fieldSize));
    subtitle(ax, sprintf('Weights: Mel=%.2f, LM=%.2f, S=%.2f', w(1), w(2), w(3)));
    xlabel(ax, 'Wavelength (nm)'); ylabel(ax, 'Log Sensitivity');
    grid(ax, 'on'); legend(ax, 'Location', 'south'); axis(ax, 'square');
    ylim([-1.2 0.1]);
end