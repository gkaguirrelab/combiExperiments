%% FIgure S4B simulation
% 1. Simulation Parameters
test_wls = 400:5:600;          % Wavelength range for S4B
wls_full = (380:1:780)';
initial_states = [1, 0, 0];    % Start Dark Adapted
intensity_mol = 1e-6;          % High intensity to ensure threshold is met
max_duration = 1000;            % Maximum allowable sim time (seconds)

% 2. Initialize storage
time_to_eq = zeros(size(test_wls));

fprintf('Calculating time to equilibrium (Threshold: 1e-10)...\n');

% 3. Loop through wavelengths
for i = 1:length(test_wls)
    % Create monochromatic SPD
    spd = zeros(size(wls_full));
    [~, idx] = min(abs(wls_full - test_wls(i)));
    spd(idx) = intensity_mol;
    
    % Run simulation
    [fractions, t] = melaStateModel(wls_full, spd, max_duration, initial_states);
    
    % 4. Find the equilibrium point
    % Calculate the absolute difference between successive time points
    % We sum the absolute differences of all three states
    diffs = sum(abs(diff(fractions)), 2);
    
    % Find the first index where the difference is less than 1e-10
    eq_idx = find(diffs < 1e-10, 1, 'first');
    
    if isempty(eq_idx)
        warning('Wavelength %d nm did not reach threshold within %d s', test_wls(i), max_duration);
        time_to_eq(i) = max_duration;
    else
        time_to_eq(i) = t(eq_idx);
    end
end

% 5. Normalize results for Figure S4B (Relative Time to Equilibrium)
% Figure S4B is plotted on a log scale normalized to the minimum time.
min_time = min(time_to_eq);
relative_time = time_to_eq / min_time;

% 6. Plotting
figure('Color', 'w');
semilogy(test_wls, relative_time, 'k-', 'LineWidth', 2);
xlabel('Wavelength (nm)');
ylabel('Relative Time to Equilibrium');
title('Figure S4B: Relative Time to Photoequilibrium');
grid on;
set(gca, 'TickDir', 'out', 'Box', 'off');




%% Figure 7B Simulation
wls = (380:1:750)';
test_wls = 400:5:650;
initial_states = [1, 0, 0];
intensity_mol = 2e-6; % Sufficiently high intensity

res_R = zeros(size(test_wls));
res_M = zeros(size(test_wls));
res_E = zeros(size(test_wls));

for i = 1:length(test_wls)
    spd = zeros(size(wls));
    [~, idx] = min(abs(wls - test_wls(i)));
    spd(idx) = intensity_mol;
    
    % Adaptive duration: Long-wavelength transitions are very slow.
    % We increase time for lambda > 500nm to ensure equilibrium.
    if test_wls(i) < 500
        sim_time = 100;
    else
        sim_time = 5000; % 10 minutes simulation time for the red tail
    end
    
    [fractions, ~] = melaStateModel(wls, spd, sim_time, initial_states);
    
    res_R(i) = fractions(end, 1);
    res_M(i) = fractions(end, 2);
    res_E(i) = fractions(end, 3);
end

% Plotting results
figure('Color', 'w'); hold on;
plot(test_wls, res_R, 'k', 'LineWidth', 2);
plot(test_wls, res_M, 'b', 'LineWidth', 2);
plot(test_wls, res_E, 'r', 'LineWidth', 2);
xlabel('Wavelength (nm)'); ylabel('Pigment Fraction');
legend('R (Melanopsin)', 'M (Metamelanopsin)', 'E (Extramelanopsin)');
title('Figure 7B: Corrected Equilibrium Convergence');
grid on; axis([400 650 0 1]);
