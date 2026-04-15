function [squintSignal, excL, excM, excS, excMel] = calculateActionSpectrum(watts, lambda, options)
% CALCULATEACTIONSPECTRUM Models the ipRGC-driven squint response.
%   This function calculates individual photoreceptor excitations through 
%   an age-dependent lens and combines them into a logarithmic drive signal.
%
%   Inputs:
%       watts    - Spectral Irradiance (e.g., [1 x N] vector in Watts or similar)
%       lambda   - Wavelength vector (e.g., 380:780)
%       options  - Name-value pairs for age and pathway weights

    arguments
        watts (1,:) double
        lambda (1,:) double
        options.age (1,1) double = 25              % Observer age in years
        options.w_mel (1,1) double = 1.0           % Melanopsin excitation weight
        options.w_lm (1,1) double = 0.2            % L+M cone additive weight
        options.w_s (1,1) double = -0.1            % S-cone inhibitory weight
        options.lambda_max_mel (1,1) double = 480  % Peak sensitivity for Melanopsin
    end

    %% 1. Lens Transmittance (CIE 170-1:2006 Model)
    % Calculate the optical density of the human lens based on age.
    % D_lens_25 is the template for a 25-year-old.
    D_lens_25 = 1.49 * exp(-0.012 * (lambda - 400));
    
    % Scaling factor A_v accounts for the yellowing/thickening of the lens with age.
    if options.age <= 60
        A_v = 1 + 0.02 * (options.age - 25);
    else
        A_v = 1.7 + 0.05 * (options.age - 60);
    end
    
    % Convert density to transmittance (Beer-Lambert Law)
    transmittance = 10.^(-D_lens_25 * A_v);
    
    % Apply lens filtering to the incoming light power
    retinal_watts = watts .* transmittance;

    %% 2. Receptor Sensitivity Templates
    % Cone fundamentals modeled as Gaussian functions centered on peak sensitivities.
    L_rel = exp(-0.5 * ((lambda - 558.9) / 35.5).^2); % Long-wavelength (Red)
    M_rel = exp(-0.5 * ((lambda - 530.3) / 32.2).^2); % Medium-wavelength (Green)
    S_rel = exp(-0.5 * ((lambda - 444.6) / 24.1).^2); % Short-wavelength (Blue)
    
    % Melanopsin (ipRGC) template using a specialized Govardovskii-style 
    % nomogram approximation for photopigments.
    x = lambda / options.lambda_max_mel;
    A = 69.7; B = 28; C = -14.9; D = 0.674;
    Mel_rel = 1 ./ (exp(A*(D-x)) + exp(B*(D-x)) + exp(C*(D-x)) + 0.11);

    %% 3. Assign Absolute Outputs (Photoreceptor Catch)
    % These represent the absolute "photon catch" at the retina level.
    excL   = retinal_watts .* L_rel;
    excM   = retinal_watts .* M_rel;
    excS   = retinal_watts .* S_rel;
    excMel = retinal_watts .* Mel_rel;

    %% 4. Calculate Squint Signal (Neural Drive)
    % Baseline represents spontaneous neural firing (prevents log(0)).
    baseline = 0.01;
    
    % Sum the weighted inputs: 
    % Positive weights = Excitatory; Negative weights = Inhibitory (S-cone).
    drive = (options.w_mel * excMel) + ...
            (options.w_lm  * (excL + excM)) + ...
            (options.w_s   * excS) + baseline;

    % Apply log10 transform to simulate the non-linear physiological response.
    % max(..., baseline) ensures we don't try to log a negative number 
    % if the S-cone inhibition is extremely high.
    squintSignal = log10(max(drive, baseline));
end