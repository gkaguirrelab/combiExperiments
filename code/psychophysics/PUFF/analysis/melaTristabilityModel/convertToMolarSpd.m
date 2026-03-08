function spdMolesPerCmSqPerSecPerNm = convertToMolarSpd(spdWattsPerMSqPerSrPerNm,S)

% First, account for the wavelength sampling
wlsSample = S(2);
spdWattsPerMSqPerSrPerNm = spdWattsPerMSqPerSrPerNm / wlsSample;

% The input SPD is a measure of radiance. We assume that this radiance is
% available uniformly across the visual field (as in a Ganzfeld dome). This
% is the condition for the blink / squint rig. We can therefore convert
% from Watts / m^2 / sr / nm to Watts / m^2 / nm by multiplying by the pi.
spdWattsPerMSqPerNm = spdWattsPerMSqPerSrPerNm * pi;

% Convert from watts to photons
h = 6.626e-34; % Plank's constant, in units of Joules * seconds
c = 2.998e8; % Speed of light m/s
lambda = SToWls(S) * 1e-9; % Wavelengths in meters

spdPhotonsPerMeterSqPerSecPerNm = spdWattsPerMSqPerNm .* lambda ./ ...
    (h*c);

% Convert from meters to cm, and divide by Avogadro's number to quantify
% photons in moles
meterToCm = 1e-4;
Avogadro = 6.022e23;

spdMolesPerCmSqPerSecPerNm = spdPhotonsPerMeterSqPerSecPerNm * meterToCm / Avogadro;

end
