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