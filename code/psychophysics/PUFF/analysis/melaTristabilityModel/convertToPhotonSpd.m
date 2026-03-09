function spdOut = convertToPhotonSpd(spdIn,S,options)
% Convert spd in radiance units to retinal irradiance in photons/μm/sec/nm
%
% Description
%   We assume that the input SPD is in units of Watts/m^2/sr/nm, and that
%   this radiance is present uniformly on a hemi-field that is viewed by a
%   human observer with a pupil radius and nodal distance of the eye that
%   is given in the optional input arguments.
%

arguments
    spdIn
    S
    options.pupilRadiusMm = 1       % Pupil radius in mm
    options.nodalDistanceMm = 16.7; % Posterior nodal distance in mm
end

% define some constants
h = 6.626e-34; % Plank's constant, in units of Joules * seconds
c = 2.998e8; % Speed of light m/s

% Derive the wls from S
wls = SToWls(S);

% Adjust the input SPD for wavelength sampling
wlsSample = S(2);
spdIn = spdIn / wlsSample;

% Calculate the pupil area in meters^2
areaPupil = pi * (options.pupilRadiusMm/1000)^2;

% Retinal Irradiance in Watts (W / m^2 / nm)
% Formula: E = L * (A_pupil / f^2)
spdOut = spdIn .* (areaPupil / (options.nodalDistanceMm / 1000)^2);

% Convert Watts to Photons per second
% Energy of one photon: E_p = (h*c) / lambda_meters
% We muliply wls by 1e-9 to convert nm to meters
photonEnergy = (h * c) ./ (wls .* 1e-9);

% Photons / m^2 / s / nm
spdOut = spdOut ./ photonEnergy;

% 5. Convert m^2 to micrometers^2 (1 m^2 = 10^12 um^2)
spdOut = spdOut / 1e12;


end
