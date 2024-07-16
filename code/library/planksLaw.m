function radiance = planksLaw(wls,T)
% Returns blackbody spectral radiance according to Plank's Law
%
% Syntax:
%   radiance = planksLaw(wls,T)
%
% Description:
%   Using the equations and constants in cgs units. The routine is off by a
%   factor of 10 relative to the plot shown as Figure 1 on the wikipedia
%   page for Plank's Law. I have not yet determined why this is...
%
% Inputs:
%   wls                   - Vector. Wavelengths in nanometers
%   T                     - Scalar. Temperature in Kelvins
%
% Outputs:
%   radiance              - Vector. The spectral radiance in units of:
%                               W / sr / m2 / nm
%
% Examples:
%{
    wls = 0:1:1000;
    T = 5000;
    plot(wls, planksLaw(wls,T))
    xlabel('wavelength [nm]');
    ylabel('radiance [W/sr/m2/nm]');
%}

ergSecToWatts = @(x) x*1e-7;
cm2ToM2 = @(x) x*0.0001;
nmToCm = @(x) x*1e-7;

h = 6.62607015 * 10^-27; % Planck's constant, erg/second
kB = 1.380649 * 10^-16; % Boltzmann constant, erg/K
c = 2.99792458 * 10^10; % cm / sec

blackBody = @(L,T) ((2*h*c^2)./(nmToCm(L).^5)) * 1 ./ ( exp( (h*c)./(nmToCm(L).*kB*T) ) -1 );

radiance = cm2ToM2( ergSecToWatts( blackBody(wls,T) ) );

end