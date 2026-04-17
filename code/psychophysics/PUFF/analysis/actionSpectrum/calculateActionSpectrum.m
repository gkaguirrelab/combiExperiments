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
    
    % Orientation setup
    lambdaCol = lambda(:); 
    lambdaRow = lambda(:)'; 
    S = [lambdaRow(1) (lambdaRow(2)-lambdaRow(1)) length(lambdaRow)];

    %% 1. INTRINSIC SENSITIVITY (Nomograms)
    sense.Intrinsic.Mel = PhotopigmentNomogram(lambdaCol, 480, 'Govardovskii')';
    absL = PhotopigmentNomogram(lambdaCol, 558.9, 'StockmanSharpe')';
    absM = PhotopigmentNomogram(lambdaCol, 530.3, 'StockmanSharpe')';
    absS = PhotopigmentNomogram(lambdaCol, 420.7, 'StockmanSharpe')';
    sense.Intrinsic.LM = (absL + absM) ./ max(absL + absM);
    sense.Intrinsic.S  = absS ./ max(absS);

    %% 2. RETINAL SENSITIVITY (Lens filtered)
    [T_mel_quantal_norm] = ComputeCIEMelFundamental(S, options.fieldSize, options.age, options.pupilSize, []);
    [T_lms_quantal_norm] = ComputeCIEConeFundamentals(S, options.fieldSize, options.age, options.pupilSize);

    T_mel_energy = EnergyToQuanta(S, T_mel_quantal_norm')';
    T_lms_energy = EnergyToQuanta(S, T_lms_quantal_norm')';
    
    sense.Mel = T_mel_energy(1,:) ./ max(T_mel_energy(1,:));
    tempLM_ret = T_lms_energy(1,:) + T_lms_energy(2,:);
    sense.LM_combined = tempLM_ret ./ max(tempLM_ret);
    sense.S = T_lms_energy(3,:) ./ max(T_lms_energy(3,:));

    %% 3. FINAL SIGNAL CALCULATION
    % The integrated iPRGC Action Spectrum (The sensitivity curve)
    sense.iprgcActionSpectrum = (options.w_mel * sense.Mel) + ... 
                                (options.w_lm  * sense.LM_combined) + ...
                                (options.w_s   * sense.S);
            
    % Total Neural Drive (Integrated catch across the spectrum)
    totalNeuralDrive = sum(sense.iprgcActionSpectrum .* watts);
    
    % The "Squint Signal" output (Scalar)
    squintSignal = log10(max(totalNeuralDrive, 1e-4));
end