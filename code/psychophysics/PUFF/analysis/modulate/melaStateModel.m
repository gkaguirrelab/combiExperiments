function [P_M,P_R,P_E] = melaStateModel(spd,S,options)
% Return the proportion of tristable melanopsin states for an arbitrary spd
%
% Syntax:
%   [P_M_spd,P_R_spd,P_E_spd] = melaStateModel(spd,S)
%
% Description:
%   Implementation of the state model from Emanuel & Do 2015, "Melanopsin
%   Tristability for Sustained and Broadband Phototransduction". The model
%   is extended to provide the proportion of melanopsin tristable states
%   for an arbitrary spd.
%
%   Melanopsin has two silent states (R-melanopsin and Extramelanopsin),
%   and one signaling state (M-melanopsin). From either silent states,
%   melanopsin can transition to the signaling state:
%
%       R (11-cis) ↔︎ M (all-trans) ↔︎ E (7-cis)
%
%   We are intrigued by the possibility that different spectral profiles
%   can result in greater 
%
% Inputs:
%   spd                   -
%   S                     - 
%
% Outputs:
%   P_M,P_R,P_E           - Scalars. Proportions of the three states.
%
% Examples:
%{
    S = [300 2 251];
    spd = zeros(size(SToWls(S)));
    spd(50)=1;
    [P_M_spd,P_R_spd,P_E_spd] = melaStateModel(spd,S,'makeDemoPlot',true);
%}
%

arguments
    spd
    S
    options.makeDemoPlot
end


% Wavelengths from S
wls = SToWls(S);

% Melanopsin states peak Wavelengths (lambda_max from Matsuyama 2012 /
% Emanuel & Do 2015)
lmax_R = 467; % Melanopsin
lmax_M = 476; % Metamelanopsin
lmax_E = 446; % Extramelanopsin

% Biochemical Parameters (From Emanuel & Do 2015 Methods section)
% Extinction Coefficients (M^-1 cm^-1)
eps_max = [33000, 52600, 21700]; % [R, M, E]

% Quantum Efficiencies (phi)
phi_RM = 0.5;   % R -> M
phi_MR = 0.1;   % M -> R
phi_ME = 0.1;   % M -> E
phi_EM = 0.7;   % E -> M

% Calculate Absorption Spectra (Govardovskii Nomogram)
A_R = govardovskii_full(wls, lmax_R);
A_M = govardovskii_full(wls, lmax_M);
A_E = govardovskii_full(wls, lmax_E);

% Calculate Photosensitivities (Photosensitivity = epsilon * A * phi)
% Transition sensitivities
S_RM = eps_max(1) .* A_R .* phi_RM;
S_MR = eps_max(2) .* A_M .* phi_MR;
S_ME = eps_max(2) .* A_M .* phi_ME;
S_EM = eps_max(3) .* A_E .* phi_EM;

% Combined exit sensitivity for state M (for Fig 7A)
S_M_total = S_MR + S_ME;

% --- Normalization: Relative to the Peak of the R-form (11-cis) ---
% Peak of R -> M is the baseline (1.0)
norm_val = max(S_RM);
S_R_plot = S_RM / norm_val;      % Should peak at 1.0
S_M_plot = S_M_total / norm_val; % Should peak at ~0.63
S_E_plot = S_EM / norm_val;      % Should peak at ~0.92

% 6. Solve for Equilibrium Fractions (Steady State)
% From the tristable chain: R <-> M <-> E
% Equations: S_RM * P_R = S_MR * P_M  AND  S_ME * P_M = S_EM * P_E
% With P_R + P_M + P_E = 1

% Calculate Integrated Rate Constants
% Total transition rate = integral of (Intensity * Sensitivity)
K_RM = trapz(wls, spd .* S_RM);
K_MR = trapz(wls, spd .* S_MR);
K_ME = trapz(wls, spd .* S_ME);
K_EM = trapz(wls, spd .* S_EM);

% Solve for Steady-State Scalar Proportions
% Denominator derived from: P_M(1 + K_MR/K_RM + K_ME/K_EM) = 1
denom = 1 + (K_MR / K_RM) + (K_ME / K_EM);
P_M = 1 / denom;
P_R = P_M * (K_MR / K_RM);
P_E = P_M * (K_ME / K_EM);

% If asked, recreate Figure 7 of Emauel and Do. 
if options.makeDemoPlot
    figure('Color', 'w', 'Position', [100, 100, 1000, 450]);
    % Figure 7A: Relative Photosensitivities
    subplot(1, 2, 1);
    hold on;
    plot(wls, S_R_plot, 'k', 'LineWidth', 2.5);
    plot(wls, S_M_plot, 'b', 'LineWidth', 2.5);
    plot(wls, S_E_plot, 'r', 'LineWidth', 2.5);
    xlabel('Wavelength (nm)');
    ylabel('Relative Photosensitivity');
    title('Figure 7A: State Photosensitivities');
    legend('R \rightarrow M', 'M exit (signaling)', 'E \rightarrow M', 'Location', 'northeast');
    grid on; axis([300 700 0 1.05]); 

    % Figure 7B: Equilibrium Fractions
    subplot(1, 2, 2);

    % Analytical solution for monochromatic light
    % P_M = 1 / (1 + S_MR/S_RM + S_ME/S_EM)
    denom_plot = 1 + (S_MR ./ S_RM) + (S_ME ./ S_EM);
    P_M_plot = 1 ./ denom_plot;
    P_R_plot = P_M_plot .* (S_MR ./ S_RM);
    P_E_plot = P_M_plot .* (S_ME ./ S_EM);
    hold on;
    plot(wls, P_R_plot, 'k', 'LineWidth', 2.5);
    plot(wls, P_M_plot, 'b', 'LineWidth', 2.5);
    plot(wls, P_E_plot, 'r', 'LineWidth', 2.5);
    xlabel('Wavelength (nm)');
    ylabel('Equilibrium Fraction');
    title('Figure 7B: Equilibrium Proportions');
    legend('P_R', 'P_M', 'P_E');
    grid on; ylim([0 1]);
end

end

%% Helper Function: Full Govardovskii Template (Alpha + Beta bands)
function S = govardovskii_full(wav, lmax)
% Alpha-band (main peak)
x = lmax ./ wav;
A = 69.7; B = 28; C = -14.9; D = 0.674;
a = 0.879; b = 0.924; c = 1.104;
S_alpha = 1 ./ (exp(A*(a-x)) + exp(B*(b-x)) + exp(C*(c-x)) + D);

% Beta-band (UV peak required for "Broadband" modeling)
lmax_beta = 189 + 0.315 * lmax;
S_beta = 0.26 * exp(-((wav - lmax_beta) ./ (wav .* 0.12)).^2);

S = S_alpha + S_beta;
end