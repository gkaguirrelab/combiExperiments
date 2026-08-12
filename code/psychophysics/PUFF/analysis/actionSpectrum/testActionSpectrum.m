%% --- Configuration & Execution ---
wavelengths = 380:1:780;
target_age = 25;

% INPUT: Narrow-band Green LED
% Peak at 530nm, Width (FWHM) approx 25nm, Peak Power 100
test_watts = 100 * exp(-0.5 * ((wavelengths - 530) / 12).^2); 

% Run the model
[squint_signal_log, sense] = calculateActionSpectrum(test_watts, wavelengths, ...
    'age', target_age, 'fieldSize', 10);

% Define colors
color_mel = [0, 0.8, 0.8];    
color_lm  = [1, 0.82, 0];     
color_s   = [0, 0.4, 1];      
color_total = [0, 0.6, 0]; % Dark Green for the LED drive

% Figure setup
figure('Color', 'w', 'Units', 'normalized', 'Position', [0.05, 0.1, 0.85, 0.75]);
tlo = tiledlayout(2,3, 'Padding', 'loose', 'TileSpacing', 'compact');

%% PLOT: Input Light Power (The Green LED)
nexttile;
fill(wavelengths, test_watts(:), [0.8 1 0.8], 'EdgeColor', [0 0.5 0], 'LineWidth', 1.5);
grid on; ylabel('Power (Watts/sr/m^2)');
title('Green LED Input Spectrum');

%% PLOT: Lens Transmittance
nexttile;
[~, ~, ~, adj] = ComputeCIEConeFundamentals([wavelengths(1) 1 length(wavelengths)], ...
    10, target_age, 3);
plot(wavelengths, adj.lens(:), 'k', 'LineWidth', 2);
grid on; ylabel('Transmittance'); 
title('Lens Filtering');
ylim([0 1.1]);

%% PLOT: Sensor Sensitivity
nexttile; hold on;
plot(wavelengths, sense.Intrinsic.Mel(:), '--', 'Color', color_mel, 'LineWidth', 1);
plot(wavelengths, sense.Intrinsic.LM(:),  '--', 'Color', color_lm,  'LineWidth', 1);
plot(wavelengths, sense.Intrinsic.S(:),   '--', 'Color', color_s,   'LineWidth', 1);
plot(wavelengths, sense.Mel(:), 'Color', color_mel, 'LineWidth', 2.5, 'DisplayName', 'Mel');
plot(wavelengths, sense.LM_combined(:), 'Color', color_lm, 'LineWidth', 2.5, 'DisplayName', 'L+M');
plot(wavelengths, sense.S(:), 'Color', color_s, 'LineWidth', 2.5, 'DisplayName', 'S');
grid on; ylabel('Relative Sensitivity');
title('Retinal Fundamentals');
ylim([0 1.1]);

%% PLOT: Integrated Action Spectrum
nexttile; hold on;
mel_comp = sense.Mel(:) * 1.0;
lm_comp  = sense.LM_combined(:) * 0.2;
s_comp   = sense.S(:) * -0.1;
total_as = mel_comp + lm_comp + s_comp;

plot(wavelengths, mel_comp, 'Color', color_mel, 'LineWidth', 1.1, 'DisplayName', 'Mel');
plot(wavelengths, lm_comp,  'Color', color_lm,  'LineWidth', 1.1, 'DisplayName', 'L+M');
plot(wavelengths, s_comp,   'Color', color_s,   'LineWidth', 1.1, 'DisplayName', 'S');
plot(wavelengths, total_as, 'k', 'LineWidth', 2.5, 'DisplayName', 'Combined AS');

yline(0, 'k-', 'Alpha', 0.3, 'HandleVisibility', 'off'); 
grid on; ylabel('Sensitivity');
title('Combined Action Spectrum');

%% PLOT: Spectral Neural Drive (The "Catch")
nexttile; hold on;
drive_curve = total_as(:) .* test_watts(:);

fill(wavelengths, drive_curve, color_total, 'FaceAlpha', 0.3, 'EdgeColor', 'none');
plot(wavelengths, drive_curve, 'Color', color_total, 'LineWidth', 2.5);

grid on; ylabel('Neural Catch (Linear)');
title('Green LED Neural Drive');

%% PLOT: Final Squint Signal
nexttile;
bar(1, squint_signal_log, 'FaceColor', [0 0.6 0]);
grid on; ylabel('Log_{10} Signal');
title(['Final Signal: ' num2str(squint_signal_log, '%.2f')]);
set(gca, 'XTick', 1, 'XTickLabel', {'Green LED'});

%% AXIS CALIBRATION
allAxes = findall(gcf, 'Type', 'axes');
for i = 1:length(allAxes)
    if isempty(strfind(allAxes(i).Title.String, 'Final Signal'))
        xlim(allAxes(i), [380 780]);
    end
end
linkaxes(allAxes(2:end), 'x');

%% Single wavelength
%% --- 1. Configuration & Model Sweep ---
wavelengths = 380:1:780;
target_age = 25;
test_power = 100; 
model_signals = zeros(size(wavelengths));

fprintf('Running model sweep... ');
for k = 1:length(wavelengths)
    mono_watts = zeros(size(wavelengths));
    mono_watts(k) = test_power; 
    
    % Run model (set fieldSize to 10 for 10-degree observer)
    [sig, ~] = calculateActionSpectrum(mono_watts, wavelengths, ...
        'age', target_age, 'fieldSize', 10);
    model_signals(k) = sig;
end
fprintf('Done.\n');

% Normalize Model (Peak to 0.0)
model_norm = model_signals - max(model_signals);

%% --- 2. Load Stringham Average Data ---
projectName = 'combiExperiments';
ProjectBaseDir = getpref(projectName, 'projectBaseDir');
filePath = fullfile(ProjectBaseDir, 'code', 'psychophysics', 'PUFF', 'analysis', ...
    'actionSpectrum', 'StringhamAvgPhotophobiaActionSpectrum.csv');

if ~exist(filePath, 'file')
    error('File not found at: %s', filePath);
end

% Load 2-column matrix (skipping 'Default Dataset' and 'X,Y' headers)
data = readmatrix(filePath, 'NumHeaderLines', 2);

rawX = data(:, 1);
rawY = data(:, 2);

% Clean NaNs and sort by wavelength
valid = ~isnan(rawX) & ~isnan(rawY);
xData = rawX(valid);
yData = rawY(valid);

[xData, sortIdx] = sort(xData);
yData = yData(sortIdx);

% Peak normalization to 0.0 log relative sensitivity
yNorm = yData - max(yData);

%% --- 3. Plotting the Comparison ---
figure('Color', 'w', 'Units', 'normalized', 'Position', [0.1, 0.1, 0.6, 0.7]);
hold on; grid on;

% Plot Average Stringham Data
plot(xData, yNorm, '-o', 'LineWidth', 2, 'MarkerSize', 7, ...
    'Color', [0.0, 0.45, 0.74], 'MarkerFaceColor', [0.0, 0.45, 0.74], ...
    'MarkerEdgeColor', 'w', 'DisplayName', 'Stringham Avg Data');

% Plot GKA Model Sweep
plot(wavelengths, model_norm, 'k', 'LineWidth', 3, 'DisplayName', 'GKA Model (10\circ)');

% Formatting
xlabel('Wavelength (nm)');
ylabel('Relative Sensitivity (Log_{10})');
title('Action Spectrum Comparison: GKA Model vs. Stringham Average');

% Axis Limits & Styling
xlim([380 650]); 
ylim([-1.2 0.1]);
set(gca, 'XTick', 380:40:650, 'TickDir', 'out', 'Box', 'off', 'FontSize', 12);
legend('Location', 'southoutside', 'NumColumns', 2);