%% --- Configuration ---
wavelengths = 380:1:780;
target_age = 25;
input_power = 100; % [Watts]
test_watts = input_power * ones(size(wavelengths));

[squint_signal_log, sense] = calculateActionSpectrum(test_watts, wavelengths, ...
    'age', target_age, 'fieldSize', 10);

% Custom Colors for Visibility
color_mel = [0, 0.8, 0.8];    % Bright Cyan
color_lm  = [1, 0.82, 0];     % High-contrast Golden (Yellow with minimal red)
color_s   = [0, 0.4, 1];      % Azure Blue

% Weighted Components for Plot 3
mel_drive = sense.Mel .* test_watts * 1.0;
lm_drive  = sense.LM_combined .* test_watts * 0.2;
s_drive   = sense.S .* test_watts * -0.1;
total_drive = mel_drive + lm_drive + s_drive;

% Extract lens for Plot 1
[~, ~, ~, adj] = ComputeCIEConeFundamentals([380 1 401], 10, target_age, 3);
transmittance = adj.lens(:)';

figure('Color', 'w', 'Position', [100, 100, 1100, 850]);

%% PLOT 1: Lens
subplot(2,2,1);
plot(wavelengths, transmittance, 'k', 'LineWidth', 2);
grid on; ylabel('Transmittance'); 
title(['Lens Transmittance (Age ' num2str(target_age) ')']);
ylim([0 1.1]); xlim([380 780]);

%% PLOT 2: Intrinsic vs. Retinal Sensitivity
subplot(2,2,2); hold on;
% Intrinsic (Dashed)
plot(wavelengths, sense.Intrinsic.Mel, '--', 'Color', color_mel, 'LineWidth', 1.5, 'DisplayName', 'Intrinsic Mel');
plot(wavelengths, sense.Intrinsic.LM,  '--', 'Color', color_lm,  'LineWidth', 1.5, 'DisplayName', 'Intrinsic L+M');
plot(wavelengths, sense.Intrinsic.S,   '--', 'Color', color_s,   'LineWidth', 1.5, 'DisplayName', 'Intrinsic S');

% Retinal (Solid)
plot(wavelengths, sense.Mel, 'Color', color_mel, 'LineWidth', 2.5, 'DisplayName', 'Retinal Mel');
plot(wavelengths, sense.LM_combined, 'Color', color_lm, 'LineWidth', 2.5, 'DisplayName', 'Retinal L+M');
plot(wavelengths, sense.S, 'Color', color_s, 'LineWidth', 2.5, 'DisplayName', 'Retinal S');

grid on; ylabel('Relative Sensitivity');
title('Intrinsic vs. Retinal Catch'); % Peak removed
legend('Location', 'best', 'FontSize', 8); 
xlim([380 780]);
ylim([0 1.1]);

%% PLOT 3: iPRGC Drive (Weighted Linear)
subplot(2,2,3); hold on;
plot(wavelengths, mel_drive, 'Color', color_mel, 'LineWidth', 1.2, 'DisplayName', 'Mel (w=1.0)');
plot(wavelengths, lm_drive,  'Color', color_lm,  'LineWidth', 1.2, 'DisplayName', 'L+M (w=0.2)');
plot(wavelengths, s_drive,   'Color', color_s,   'LineWidth', 1.2, 'DisplayName', 'S (w=-0.1)');
plot(wavelengths, total_drive, 'k', 'LineWidth', 3, 'DisplayName', 'Total Drive');

yline(0, 'k-', 'Alpha', 0.3, 'HandleVisibility', 'off'); 
grid on; 
ylabel('iPRGC Drive (Weighted Watts)');
title(['Weighted Linear Signal (' num2str(input_power) ' Watts)']);
legend('Location', 'best', 'FontSize', 8); 
xlim([380 780]);

%% PLOT 4: Response (Log Transform)
subplot(2,2,4);
plot(wavelengths, squint_signal_log, 'k', 'LineWidth', 2.5);
grid on; 
ylabel('Response (log_{10} Drive)');
title(['Final Squint Signal (' num2str(input_power) ' Watts)']);
xlim([380 780]);

% Sync X-axes
linkaxes(findall(gcf, 'Type', 'axes'), 'x');