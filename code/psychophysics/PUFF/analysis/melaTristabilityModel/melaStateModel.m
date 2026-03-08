function [fractions, t] = melaStateModel(spd, S, initialStates, options)
% Temporal evolution of tristable melanopsin states in response to an spd
%
% Syntax:
%   [fractions, t] = melaStateModel(wls, spd, duration, initial_states)
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
% Inputs:
%   wls
%   spd
%   duration              - Scalar, seconds
%   initial_states        - 1x3 vector. Fractions of R, M, and E states.
%                           Must sum to unity.
%
% Outputs:
%   fractions             - tx3 matrix. Proportions of the three states at
%                           each time step.
%   t                     - temporal support in seconds.
%
% Examples:
%{
    S = [300 2 251];
    spd = zeros(size(SToWls(S)));
    spd(50)=1;
    [P_M_spd,P_R_spd,P_E_spd] = melaStateModel(spd,S,'makeDemoPlot',true);
%}

arguments
    spd
    S
    initialStates
    options.lmax = [467, 476, 446]       % R, M, E peaks
    options.ext  = [33000, 52600, 42000] * 1000 % Convert to cm^2/mol
    options.phi  = [0.7, 0.2, 0.4]       % Quantum efficiencies
    options.fMR  = 0.5
    options.fME = 0.5        % Symmetry of conversion
    options.dt = 1/1000   % 1 ms
    options.stopAfterConverging = true   % 1 ms
    options.covergeTol = 1e-6   % 1 ms
    options.durationMax = 10000   % in seconds
end

% Convert S to wavelengths
wls = SToWls(S);

% Biophysical parameters from Emanuel & Do (2015)
lmax = options.lmax;
ext = options.ext;
phi = options.phi;
fMR = options.fMR;
fME = options.fME;

% Constants and resolution
dwl = mean(diff(wls));
dt  = options.dt;

% Calculate Transition Rates (K)
ln10 = log(10);
A_R = govardovskii_standard(wls, lmax(1));
A_M = govardovskii_standard(wls, lmax(2));
A_E = govardovskii_standard(wls, lmax(3));

% The probability of each melanopsin state of capturing a photon per second
KR = sum(ln10 * spd .* ext(1) .* A_R .* phi(1)) * dwl;
KM = sum(ln10 * spd .* ext(2) .* A_M .* phi(2)) * dwl;
KE = sum(ln10 * spd .* ext(3) .* A_E .* phi(3)) * dwl;

% Prepare variables for the iterative state model
n = 1;
t = 0;
fractions(1, :) = initialStates(:)';

% Numerical Loop
notDone = true;
while notDone

    % The current state fractions
    fR = fractions(n, 1);
    fM = fractions(n, 2);
    fE = fractions(n, 3);

    % R leaves via KR; M leaves via KM (splitting to R and E)
    dfR = (fMR * KM * fM - KR * fR) * dt;
    dfE = (fME * KM * fM - KE * fE) * dt;

    % Store the next step
    fractions(n+1, 1) = fR + dfR;
    fractions(n+1, 3) = fE + dfE;
    fractions(n+1, 2) = 1 - (fractions(n+1, 1) + fractions(n+1, 3));
    
    % Extend the temporal support
    t(n+1) = t(n) + dt;

    % We can optionally stop if we have converged
    if options.stopAfterConverging && n > 1
        if all(abs(diff(fractions(n-1:n,:))) < options.covergeTol)
            notDone = false;
        end
    end

    % If we have used all of our time steps, we are done
    if n > length(t)-1
        notDone = false;
    end

    % Iter
    n = n+1;
end

end
