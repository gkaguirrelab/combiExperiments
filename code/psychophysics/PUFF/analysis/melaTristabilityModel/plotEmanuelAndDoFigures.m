
% Housekeeping
clear; close all

% The wavelength support for the modeled SPD
S = [380 1 401];
wls = SToWls(S);

testWls = 400:5:600;          % Wavelengths for which we will create a plot

initialState = [1, 0, 0];      % Start Dark Adapted (all R)
intensity_mol = 1e-6;          % High intensity to ensure threshold is met

% These variables will hold our results of interest
equilibriumTimeByWls = zeros(length(testWls),1);
finalFractionsByWls = zeros(length(testWls),3);

% Loop through wavelengths
for ii = 1:length(testWls)

    % Create monochromatic SPD
    spd = zeros(size(wls));
    [~, idx] = min(abs(wls - testWls(ii)));
    spd(idx) = intensity_mol;
    
    % Run simulation
    [fractions, t] = melaStateModel(spd, S, initialState);
    
    % Store the values of interest
    equilibriumTimeByWls(ii) = t(end);
    finalFractionsByWls(ii,:) = fractions(end,:);
end

% Figure S4B
figure('Color', 'w');
semilogy(testWls, equilibriumTimeByWls/min(equilibriumTimeByWls), 'k-', 'LineWidth', 2);
xlabel('Wavelength (nm)');
ylabel('Relative Time to Equilibrium');
title('Figure S4B: Relative Time to Photoequilibrium');
grid on;
set(gca, 'TickDir', 'out', 'Box', 'off');

% Figure 7B
figure('Color', 'w'); hold on;
plot(testWls, finalFractionsByWls(:,1), 'k', 'LineWidth', 2);
plot(testWls, finalFractionsByWls(:,2), 'b', 'LineWidth', 2);
plot(testWls, finalFractionsByWls(:,3), 'r', 'LineWidth', 2);
xlabel('Wavelength (nm)'); ylabel('Pigment Fraction');
legend('R (Melanopsin)', 'M (Metamelanopsin)', 'E (Extramelanopsin)');
title('Figure 7B: Corrected Equilibrium Convergence');
grid on; axis([400 650 0 1]);
