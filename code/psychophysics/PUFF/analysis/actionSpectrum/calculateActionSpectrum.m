function [squintSignal, sense] = calculateActionSpectrum(watts, lambda, options)
    arguments
        watts (1,:) double
        lambda (1,:) double
        options.age (1,1) double = 25
        options.fieldSize (1,1) double = 10 
        options.pupilSize (1,1) double = 3 
        options.w_mel (1,1) double = 1.0
        options.w_lm (1,1) double = 0.2
        options.w_s (1,1) double = -0.1
    end
    
    S = [lambda(1) (lambda(2)-lambda(1)) length(lambda)];

    %% 1. Get Intrinsic (Unfiltered) Photopigment Nomograms
    % (Standard Stockman-Sharpe)
    mel_raw = exp(-((log10(lambda) - log10(480)) / 0.09).^2);
    L_raw = exp(-0.5 * ((lambda - 558.9) / 35.5).^2);
    M_raw = exp(-0.5 * ((lambda - 530.3) / 32.2).^2);
    S_raw = exp(-0.5 * ((lambda - 444.6) / 24.1).^2);
    
    sense.Intrinsic.Mel = mel_raw(:)';
    sense.Intrinsic.LM  = ((L_raw + M_raw) ./ max(L_raw + M_raw))';
    sense.Intrinsic.S   = S_raw(:)';

    %% 2. Get Retinal Fundamentals (Filtered)
    % FIX: Ensure we call for 'Mel' specifically or handle the correct index.
    % In most Aguirre Lab setups, Mel is a separate call or specific struct:
    
    % Attempting to pull Mel explicitly
    try
        [~, ~, T_mel_quantal] = ComputeCIEMelFundamental(S, options.fieldSize, ...
            options.age, options.pupilSize);
    catch
        % Fallback if your toolbox uses a different wrapper
        [~, ~, T_all_quantal] = ComputeCIEConeFundamentals(S, options.fieldSize, ...
            options.age, options.pupilSize);
        % If T_all_quantal is 3-rows (L,M,S), we need to ensure Mel isn't L!
        % We will use the intrinsic Mel template filtered by the lens adj
        [~, ~, ~, adj] = ComputeCIEConeFundamentals(S, options.fieldSize, options.age, options.pupilSize);
        T_mel_quantal = mel_raw(:)' .* adj.lens(:)';
    end
    
    % Get LMS
    [~, ~, T_LMS_quantal] = ComputeCIEConeFundamentals(S, options.fieldSize, ...
        options.age, options.pupilSize);
    
    % Convert to Energy (Watts) and Normalize
    T_mel_energy = EnergyToQuanta(S, T_mel_quantal')';
    T_LMS_energy = EnergyToQuanta(S, T_LMS_quantal')';
    
    sense.Mel = T_mel_energy(1,:) ./ max(T_mel_energy(1,:));
    
    tempLM = T_LMS_energy(1,:) + T_LMS_energy(2,:);
    sense.LM_combined = tempLM ./ max(tempLM);
    
    sense.S = T_LMS_energy(3,:) ./ max(T_LMS_energy(3,:));
    
    % Force Row Vectors
    sense.Mel = sense.Mel(:)';
    sense.LM_combined = sense.LM_combined(:)';
    sense.S = sense.S(:)';
    
    %% 3. Calculate Final Squint Signal
    drive = (options.w_mel * (sense.Mel .* watts)) + ...
            (options.w_lm  * (sense.LM_combined .* watts)) + ...
            (options.w_s   * (sense.S .* watts));
            
    squintSignal = log10(max(drive, 1e-4));
end