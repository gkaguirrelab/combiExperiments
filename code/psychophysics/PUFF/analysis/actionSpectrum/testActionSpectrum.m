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
% --- Configuration & Sweep Setup ---
wavelengths = 380:1:780;
target_age = 25;
test_power = 100; % Constant power for every monochromatic test

% Pre-allocate the results vector
final_signals = zeros(size(wavelengths));

% Loop through every wavelength and test it individually
for i = 1:length(wavelengths)
    % Create a "monochromatic" input: 100 Watts at only one wavelength
    mono_watts = zeros(size(wavelengths));
    mono_watts(i) = test_power; 
    
    % Run the model for this specific wavelength
    [squint_signal_log, ~] = calculateActionSpectrum(mono_watts, wavelengths, ...
        'age', target_age);
    
    % Store the scalar result
    final_signals(i) = squint_signal_log;
end

% --- Plotting the Sweep Results ---
figure('Color', 'w', 'Units', 'normalized', 'Position', [0.2, 0.2, 0.5, 0.5]);

% Plot the final signal vs wavelength
plot(wavelengths, final_signals, 'k', 'LineWidth', 3);
grid on; hold on;

% Add the Zero line to see the S-cone "subtraction" clearly
yline(0, 'r--', 'Alpha', 0.5, 'LineWidth', 1.5);

% Labeling
xlabel('Wavelength (nm)');
ylabel('Predicted Squint Response (Log_{10} Drive)');
title(['Model Action Spectrum (Monochromatic Sweep, Age ' num2str(target_age) ')']);
xlim([380 780]);

% Style the plot
set(gca, 'TickDir', 'out', 'Box', 'off');

% Optional: Highlight the peak
[maxVal, maxIdx] = max(final_signals);
plot(wavelengths(maxIdx), maxVal, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
text(wavelengths(maxIdx)+10, maxVal, sprintf('Peak: %d nm', wavelengths(maxIdx)), ...
    'FontWeight', 'bold');


%% 1. Setup Paths and Load Digitized Data
% Use gitpath to find the base directory of the project
baseDir = gitpath('combiExperiments');
filePath = fullfile(baseDir, 'code', 'psychophysics', 'PUFF', 'analysis', ...
    'actionSpectrum', 'StringhamPhotophobiaActionSpectrum.csv');

% Load the data, skipping the two-row header (Names and X,Y labels)
data = readmatrix(filePath, 'NumHeaderLines', 2);

% Identify the subjects based on the CSV structure
subjects = {'AW2', 'AW1', 'JS1', 'JS2'};
subjectColors = [0.8 0 0; 0.6 0 0.2; 0.4 0 0.4; 0.2 0 0.6]; % Shades of Red/Purple

%% 2. Generate the Model Action Spectrum (Monochromatic Sweep)
wavelengths = 380:1:780;
target_age = 25;   % Adjust to match the paper's cohort if known
test_power = 100;  % Constant power for monochromatic testing
model_signals = zeros(size(wavelengths));

fprintf('Running model sweep... ');
for i = 1:length(wavelengths)
    mono_watts = zeros(size(wavelengths));
    mono_watts(i) = test_power; 
    
    % We only need the scalar output for the sweep
    [sig, ~] = calculateActionSpectrum(mono_watts, wavelengths, 'age', target_age);
    model_signals(i) = sig;
end
fprintf('Done.\n');

% Normalize Model: Shift peak sensitivity to 0.0 (log scale) 
% to match the relative sensitivity format of digitized papers.
model_norm = model_signals - max(model_signals);

%% --- 1. Configuration & Sweep Setup ---
wavelengths = 380:1:780;
target_age = 25;
test_power = 100; % Constant power for monochromatic testing

% Pre-allocate the results vector
model_signals = zeros(size(wavelengths));

% Use 'k' for the loop index to avoid shadowing the imaginary unit
fprintf('Running model sweep... ');
for k = 1:length(wavelengths)
    % Create a "monochromatic" input: 100 Watts at only one wavelength
    mono_watts = zeros(size(wavelengths));
    mono_watts(k) = test_power; 
    
    % Run the model for this specific wavelength
    % We only care about the first output (the log signal)
    [sig, ~] = calculateActionSpectrum(mono_watts, wavelengths, 'age', target_age);
    model_signals(k) = sig;
end
fprintf('Done.\n');

% Normalize Model: Shift peak sensitivity to 0.0 (Log Relative Sensitivity)
model_norm = model_signals - max(model_signals);

%% --- 2. Load and Prepare Stringham Data ---
% Use gitpath as requested to find the file
baseDir = gitpath('combiExperiments');
relPath = 'code/psychophysics/PUFF/analysis/actionSpectrum/StringhamPhotophobiaActionSpectrum.csv';
filePath = fullfile(baseDir, relPath);

% Check if file exists to prevent hard errors
if ~exist(filePath, 'file')
    error('CSV file not found at: %s', filePath);
end

% Load the data (skipping the 2-row header)
data = readmatrix(filePath, 'NumHeaderLines', 2);

% Define the subjects and their colors explicitly here
subjects = {'AW2', 'AW1', 'JS1', 'JS2'};
subjectColors = [
    0.0, 0.45, 0.74; % Blue
    0.85, 0.33, 0.1; % Orange
    0.93, 0.69, 0.13; % Yellow
    0.49, 0.18, 0.56  % Purple
];

%% --- 1. Configuration & Model Sweep ---
wavelengths = 380:1:780;
target_age = 25;
test_power = 100; 

model_signals = zeros(size(wavelengths));

fprintf('Running model sweep... ');
for k = 1:length(wavelengths)
    mono_watts = zeros(size(wavelengths));
    mono_watts(k) = test_power; 
    
    % Reverted to fieldSize 10 for Peripheral (10-degree) observer
    [sig, ~] = calculateActionSpectrum(mono_watts, wavelengths, ...
        'age', target_age, 'fieldSize', 10);
    model_signals(k) = sig;
end
fprintf('Done.\n');

% Normalize Model (Peak to 0.0)
model_norm = model_signals - max(model_signals);

%% --- 2. Load and Map Stringham Data ---
filePath = '/Users/samanthamontoya/Documents/MATLAB/projects/combiExperiments/code/psychophysics/PUFF/analysis/actionSpectrum/StringhamPhotophobiaActionSpectrum.csv';

if ~exist(filePath, 'file')
    error('File not found at: %s', filePath);
end

data = readmatrix(filePath, 'NumHeaderLines', 2);

% Reordered list: AW1 then AW2, followed by JS
subDatasets = {'AW1', 'AW2', 'JS1', 'JS2'};

% Map indices to CSV columns: AW1 (3-4), AW2 (1-2), JS1 (5-6), JS2 (7-8)
colMapping = [3, 1, 5, 7]; 

% Define grouped shades
colors = [
    0.30, 0.75, 0.93;  % AW1: Sky Blue
    0.00, 0.25, 0.50;  % AW2: Navy Blue
    0.60, 0.20, 0.00;  % JS1: Rust/Dark Orange
    1.00, 0.60, 0.20   % JS2: Amber/Bright Orange
];

%% --- 3. Plotting the Comparison ---
figure('Color', 'w', 'Units', 'normalized', 'Position', [0.1, 0.1, 0.6, 0.7]);
hold on; grid on;

% A. Plot Stringham Data Points with lines
for k = 1:length(subDatasets)
    colX = colMapping(k);
    colY = colX + 1;
    
    rawX = data(:, colX);
    rawY = data(:, colY);
    
    % Clean NaNs and Sort by wavelength
    valid = ~isnan(rawX) & ~isnan(rawY);
    xData = rawX(valid);
    yData = rawY(valid);
    
    [xData, sortIdx] = sort(xData);
    yData = yData(sortIdx);
    
    % Normalize individual peak to 0.0
    yNorm = yData - max(yData);
    
    plot(xData, yNorm, '-o', 'LineWidth', 1.5, 'MarkerSize', 6, ...
        'Color', colors(k,:), 'MarkerFaceColor', colors(k,:), ...
        'MarkerEdgeColor', 'w', 'DisplayName', ['Stringham: ' subDatasets{k}]);
end

%% --- 1. Configuration & Model Sweep ---
wavelengths = 380:1:780;
target_age = 25;
test_power = 100; 

model_signals = zeros(size(wavelengths));

fprintf('Running model sweep... ');
for k = 1:length(wavelengths)
    mono_watts = zeros(size(wavelengths));
    mono_watts(k) = test_power; 
    
    % Model set to 10-degree (peripheral) observer as requested
    [sig, ~] = calculateActionSpectrum(mono_watts, wavelengths, ...
        'age', target_age, 'fieldSize', 2);
    model_signals(k) = sig;
end
fprintf('Done.\n');

% Normalize Model (Peak to 0.0)
model_norm = model_signals - max(model_signals);

%% --- 2. Load and Map Stringham Data ---
filePath = '/Users/samanthamontoya/Documents/MATLAB/projects/combiExperiments/code/psychophysics/PUFF/analysis/actionSpectrum/StringhamPhotophobiaActionSpectrum.csv';

if ~exist(filePath, 'file')
    error('File not found at: %s', filePath);
end

data = readmatrix(filePath, 'NumHeaderLines', 2);

% Reordered list: AW1 then AW2, followed by JS1 then JS2
subDatasets = {'AW1', 'AW2', 'JS1', 'JS2'};

% Map indices to CSV columns: AW1 (3-4), AW2 (1-2), JS1 (5-6), JS2 (7-8)
colMapping = [3, 1, 5, 7]; 

% Define grouped shades: 1s are Light, 2s are Dark
colors = [
    0.30, 0.75, 0.93;  % AW1: Light Blue
    0.00, 0.25, 0.50;  % AW2: Dark Blue
    1.00, 0.75, 0.25;  % JS1: Light Orange/Amber
    0.60, 0.20, 0.00   % JS2: Dark Orange/Rust
];

%% --- 3. Plotting the Comparison ---
figure('Color', 'w', 'Units', 'normalized', 'Position', [0.1, 0.1, 0.6, 0.7]);
hold on; grid on;

% A. Plot Stringham Data Points with lines
for k = 1:length(subDatasets)
    colX = colMapping(k);
    colY = colX + 1;
    
    rawX = data(:, colX);
    rawY = data(:, colY);
    
    % Clean NaNs and Sort by wavelength to ensure lines connect correctly
    valid = ~isnan(rawX) & ~isnan(rawY);
    xData = rawX(valid);
    yData = rawY(valid);
    
    [xData, sortIdx] = sort(xData);
    yData = yData(sortIdx);
    
    % Normalize individual peak to 0.0 for shape comparison
    yNorm = yData - max(yData);
    
    plot(xData, yNorm, '-o', 'LineWidth', 1.5, 'MarkerSize', 6, ...
        'Color', colors(k,:), 'MarkerFaceColor', colors(k,:), ...
        'MarkerEdgeColor', 'w', 'DisplayName', ['Stringham: ' subDatasets{k}]);
end

% B. Plot GKA Model Sweep
plot(wavelengths, model_norm, 'k', 'LineWidth', 4, 'DisplayName', 'GKA Model (10\circ)');

% C. Formatting
xlabel('Wavelength (nm)');
ylabel('Relative Sensitivity (Log_{10})');
title('Action Spectrum Comparison: GKA Model vs. Stringham Data');

% Axis Limits
xlim([380 650]); 
ylim([-1.2 0.1]); % Y-limit extended to -1 as requested

set(gca, 'XTick', 380:40:650, 'TickDir', 'out', 'Box', 'off', 'FontSize', 12);
legend('Location', 'southoutside', 'NumColumns', 2);