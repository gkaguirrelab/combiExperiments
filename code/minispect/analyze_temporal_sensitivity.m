function analyze_temporal_sensitivty(cal_path)
    % Step 1: Connect MiniSpect and CombiLED
    MS = mini_spect_control(); % Initialize MiniSpect Object

    calDir = fullfile(tbLocateProjectSilent('combiExperiments'),'cal'); % Which Cal file to use (currently hard-coded)
    calFileName = 'CombiLED_shortLLG_testSphere_ND0x2.mat';

    cal_path = fullfile(calDir,calFileName);

    load(cal_path,'cals'); % Load the cal file
    cal = cals{end};
    
    CL = CombiLEDcontrol(); % Initialize CombiLED Object
    CL.setGamma(cal.processedData.gammaTable);  % Update the combiLED's gamma table

    % Step 2: Select chip of MS to analyze
    light_sensing_chips = ['AMS7341','TSL2591'];
    chip_name = 'AMS7341';
    chip = MS.chip_name_map(chip_name);
    chip_functions = MS.chip_functions_map(chip); % Retrieve the available functions of the given chip

    assert(any(ismember(chip_name,light_sensing_chips) == true)); % assert chip choice is among light-sensing chips

    % Step 3: Prepare CombiLED for experiment

    observerAgeInYears = str2double(GetWithDefault('Age in years','30'));
    pupilDiameterMm = str2double(GetWithDefault('Pupil diameter in mm','3'));

    photoreceptors = photoreceptorDictionaryHuman('observerAgeInYears',observerAgeInYears,'pupilDiameterMm',pupilDiameterMm);

    frequencies = [2];
    experiment_results = nan(size(frequencies,2),10);
    for ff = 1:size(frequencies,2)
        fprintf('Frequency: %d / %d\n', ff, size(frequencies,2));
        f0 = frequencies(1,ff);

        modResult = designModulation('LightFlux',photoreceptors,cal);
        CL.setSettings(modResult);
        CL.setWaveformIndex(1);
        CL.setFrequency(f0);
        CL.setContrast(1);
        
        % Step 4: Prepare minispect for reading, 
        %         Define nMeasures and setup 
        %         storage for readings
        mode = chip_functions('Channels');
        nMeasures = 200; 
        nDetectorChannels = MS.chip_nChannels_map(chip);
        counts = nan(nMeasures,nDetectorChannels);
        measurement_times = nan(nMeasures,1);
        % Step 5: Begin flicker and ,1
        %         take nMeasures from 
        %         the minispect chip 
        CL.startModulation();
        tic ; 
        for ii = 1:nMeasures
            fprintf('Measurement: %d / %d\n', ii, nMeasures);
            channel_values = MS.read_minispect(chip,mode);
            t_i = toc ; 
            counts(ii,:) = channel_values;
            measurement_times(ii) = t_i;

        end
        elapsed_seconds = toc; 

        % Step 7: Derive amplitude of counts at the fundamental
        %         frequency of CombiLED's flicker
        secsPerMeasure = elapsed_seconds/nMeasures;
        
        channel_amplitudes = nan(1,nDetectorChannels);
        for cc = 1:nDetectorChannels
            signal = counts(:,cc);

            sig_mean = mean(signal);
            signal = signal - mean(signal);  % freq is the source flicker freq in Hz. Signal is the vector of measures for a channel
            % sampling frequency of signal
            fs = 1./secsPerMeasure;
            % Set up the regression matrix
            t = 1:length(signal);
            X = [];
            X(:,1) = sin(  t./(fs/f0).*2*pi );
            X(:,2) = cos(  t./(fs/f0).*2*pi );
            % Perform the fit 
            y = signal;
            b = X\y;

            fit = X * b; 
            
            if(cc == 1)
                figure ; 
                t_measures = measurement_times;

                plot(t_measures,signal+sig_mean);
                hold on; 
                plot(t_measures,fit+sig_mean);

                f_sinusoid = f0;
                t_sin = linspace(0, t_measures(end), nMeasures*10);
                sinusoid = sin(2 * pi * f_sinusoid * t_sin);
              
                plot(t_sin,sinusoid);


                title(sprintf('Signal and Fit: Channel %d Freq: %f', cc, f0));
                xlabel('Time (seconds)');
                ylabel('Counts');
                legend('Signal','Fit', 'Source Modulation');

            end


            amplitude  = norm(b);
            phase = -atan(b(2)/b(1));

            channel_amplitudes(1,cc) = amplitude;
            fprintf('Channel %d | Amplitude %f | Phase %f\n', cc, amplitude, phase)

        end

        experiment_results(ff,:) = channel_amplitudes;

    end


    figure ; 

    for cc = 1:nDetectorChannels      
        semilogx(frequencies,experiment_results(:,cc));
        hold on;

    end
    % NEED TO IMPROVE TIC LABELS
    xlabel('Source Frequency [log]');   
    ylabel('Amplitude of Detector Response');
    title('Amplitude of Response by Log Source Frequency');

    figure ; 
    [frq, amp, phase] = simpleFFT(experiment_results(:,1),1./secsPerMeasure);
    plot(frq,amp);
    xlabel('Frequency');
    ylabel('Amplitude'); 



end