function [fractions, t] = melaStateModel(spd, S, initialStates, options)
% Temporal evolution of tristable melanopsin states in response to an spd
%
% Syntax:
%   [fractions, t] = melaStateModel(wls, spd, duration, initial_states)
%
% Description:
%   Implementation of the state model from Emanuel & Do 2015, "Melanopsin
%   Tristability for Sustained and Broadband Phototransduction".
%
%   Melanopsin has two silent states (R-melanopsin and Extramelanopsin),
%   and one signaling state (M-melanopsin). From either silent states,
%   melanopsin can transition to the signaling state:
%
%       R (11-cis) ↔︎ M (all-trans) ↔︎ E (7-cis)
%
%   We incorporate as well the observed decay of M (and presumably E)
%   states back to the R groud state.
%
% Inputs:
%   wls
%   spd                   - in units of moles of photons per cm^2/s/nm.
%   initial_states        - 1x3 vector. Fractions of R, M, and E states.
%                           Must sum to unity.
%
% Options:
%  'lmax'                 - Lambda max of the R, M, and E spectral
%                           sensitvity functions.
%  'ext'                  - Extinction coefficients. Effectively, this is
%                           the relative overall sensitivity of the R, M,
%                           and E spectral sensitivity functions. This is
%                           expressed in the units cm^2/mol
%  'phi'                  - Quantum efficiencies for the R, M, and E
%                           species
%  'fMR', 'fME'           - The probability of producing the R and E states
%                           after the M state absorbs a photon.
%  'decayTimeConstant'    - Time constant with which E decays to M, and M
%                           to R.
%  'dt'                   - Time step size for the model, in seconds
%  'covergeTol'           - When the change in state fractions is less than
%                           this for a step, the model has converged.
%  'stopAfterConverging'  - Logical. Stop the model after converging.
%  'durationMax'          - The maximum modeled time in seconds for the
%                           search. We exit at this point even if the model
%                           has not coverged.
%
% Outputs:
%   fractions             - tx3 matrix. Proportions of the three states at
%                           each time step.
%   t                     - temporal support in seconds.
%
% Examples:
%{
    S = [380 1 401];
    spd = zeros(size(SToWls(S)));
    spd(50) = 1e-6;
    initialStates = [1 0 0]; % Start dark adapted
    [fractions, t] = melaStateModel(spd, S, initialStates);
%}

arguments
    spd
    S
    initialStates
    options.lmax = [467, 476, 446]
    options.ext  = [33000, 52600, 42000] * 1000
    options.phi  = [0.7, 0.2, 0.4]
    options.fMR  = 0.5
    options.fME = 0.5
    options.decayTimeConstant = 122
    options.dt = 1/100
    options.covergeTol = 1e-8
    options.stopAfterConverging = true
    options.durationMax = 300
end

% Convert S to wavelengths
wls = SToWls(S);

% Check the initial state
assert(abs(sum(initialStates) - 1) < 1e-6);

% Biophysical parameters from Emanuel & Do (2015)
lmax = options.lmax;
ext = options.ext;
phi = options.phi;
fMR = options.fMR;
fME = options.fME;

% Constants and resolution
dwl = mean(diff(wls));
dt  = options.dt;

% The normalized quantal absorbance for each melanopsin state
A_R = GovardovskiiNomogram(S,lmax(1))';
A_M = GovardovskiiNomogram(S,lmax(2))';
A_E = GovardovskiiNomogram(S,lmax(3))';

% The Transition Rates (K), which is the probability of each melanopsin
% state of capturing a photon per second
ln10 = log(10);
KR = sum(ln10 * spd .* ext(1) .* A_R .* phi(1)) * dwl;
KM = sum(ln10 * spd .* ext(2) .* A_M .* phi(2)) * dwl;
KE = sum(ln10 * spd .* ext(3) .* A_E .* phi(3)) * dwl;

% Decay rate constant. This is the probability of spontaneous conversion of
% E -> M, and M -> R
KDecay = 1 / options.decayTimeConstant;

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

    % Incorporates effect of light, and changes due to spontaneous decay
    dfR = (fMR * KM * fM - KR * fR + KDecay * fM) * dt;
    dfE = (fME * KM * fM - KE * fE - KDecay * fE) * dt;

    % Store next step
    fractions(n+1, 1) = fR + dfR;
    fractions(n+1, 3) = fE + dfE;
    
    % The M fraction is what remains
    fractions(n+1, 2) = 1 - (fractions(n+1, 1) + fractions(n+1, 3));
    
    % Extend the temporal support
    t(n+1) = t(n) + dt;

    % We can optionally stop if we have converged
    if options.stopAfterConverging && n > 1
        if all(abs(diff(fractions(n-1:n,:))) < options.covergeTol)
            notDone = false;
        end
    end

    % Enforce a maximum duration for the saerch
    if t(end) > options.durationMax
        notDone = false;
    end

    % Iter
    n = n+1;
end

end
