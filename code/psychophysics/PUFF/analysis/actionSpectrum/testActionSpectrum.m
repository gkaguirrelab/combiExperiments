%% --- Squint Analysis: Absolute Scaling ---
wavelengths = 380:1:780;           
input_power = 100; 
test_watts = input_power * ones(size(wavelengths)); 
ages = 25:5:80;

figure('Color', 'w', 'Units', 'normalized', 'Position', [0.1 0.1 0.6 0.8]);

%% Plot 1: Absolute Excitation Catch
subplot(2,1,1); hold on;
[~, L, M, S, Mel] = calculateActionSpectrum(test_watts, wavelengths, 'age', 25);

plot(wavelengths, L, 'r-', 'LineWidth', 2, 'DisplayName', 'L-cone');
plot(wavelengths, M, 'g-', 'LineWidth', 2, 'DisplayName', 'M-cone');
plot(wavelengths, S, 'b-', 'LineWidth', 2, 'DisplayName', 'S-cone');
plot(wavelengths, Mel, 'c-', 'LineWidth', 2.5, 'DisplayName', 'Melanopsin');

grid on; box off;
ylabel('Excitation (Retinal Watts)');
title(['Photoreceptor Absolute Catch (' num2str(input_power) 'W Input)']);
legend('Location', 'northeastoutside');

% DYNAMIC Y-LIMIT for Plot 1
yMax1 = max([L, M, S, Mel]);
ylim([0, yMax1 * 1.1]); 

%% Plot 2: Squint Drive (Log Scale)
subplot(2,1,2); hold on;
cmap = parula(length(ages)); 

yMin2 = inf; yMax2 = -inf; % Trackers for second plot

for i = 1:length(ages)
    [sSignal, ~, ~, ~, ~] = calculateActionSpectrum(test_watts, wavelengths, 'age', ages(i));
    
    yMin2 = min(yMin2, min(sSignal));
    yMax2 = max(yMax2, max(sSignal));
    
    plot(wavelengths, sSignal, 'LineWidth', 1.5, 'Color', cmap(i,:), ...
         'DisplayName', sprintf('%d y', ages(i)));
end

grid on; box off;
xlabel('Wavelength (nm)');
ylabel('log_{10}(ipRGC Drive)');
title('Squint Action Spectrum Sensitivity vs. Age');
legend('Location', 'northeastoutside');

% DYNAMIC Y-LIMIT for Plot 2
margin = (yMax2 - yMin2) * 0.1;
ylim([yMin2 - margin, yMax2 + margin]);

linkaxes(findall(gcf, 'Type', 'axes'), 'x');
xlim([380 780]);