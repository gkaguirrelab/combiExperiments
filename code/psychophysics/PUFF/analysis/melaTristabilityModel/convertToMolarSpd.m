function spdOut = convertToMolarSpd(spdIn)
% Convert retinal irradiance in photons/μm^2/s/nm to moles/cm^2/s/nm

% Avogadro's constant
Na = 6.02214076e23;

% Area conversion factor: (10,000 um / 1 cm)^2 = 10^8
um2_to_cm2 = 1e8;

% Multiply by 10^8 to scale area up to cm^2,
% then divide by Na to convert photons to moles.
spdOut = (spdIn .* um2_to_cm2) ./ Na;


end
