function analyze_temporal_sensitivty(cal_path)

    % Utility
    function filterProfile = idealDiscreteSampleFilter(sourceFreqsHz,dTsignal)
        nCycles = 100;
        dTsource = 0.01; % seconds

        for ii = 1:length(sourceFreqsHz)
            % Define the signal length
            sourceDurSecs = nCycles/sourceFreqsHz(ii);
            sourceTime = 0:dTsource:sourceDurSecs-dTsource;
            % Create a source modulation
            source = sin(sourceTime/(1/sourceFreqsHz(ii))*2*pi);
            % Downsample the source to create the signal
            signalTime = 0:dTsignal:sourceDurSecs-dTsignal;
            signal = interp1(sourceTime,source,signalTime,'linear');
            % Set up the regression matrix
            X = [];
            X(:,1) = sin(  sourceTime./(1/sourceFreqsHz(ii)).*2*pi );
            X(:,2) = cos(  sourceTime./(1/sourceFreqsHz(ii)).*2*pi );
            % Perform the fit
            y = interp1(signalTime,signal,sourceTime,'nearest','extrap')';
            b = X\y;
            filterProfile(ii)  = norm(b);
        end
    end

    % Step 1: Connect MiniSpect and CombiLED
    MS = mini_spect_control(); % Initialize MiniSpect Object

    % Step 2: Ensure MS is at our desired settings
    MS.reset_settings();

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
    upper_bound_ndf_map = containers.Map({'AMS7341','TSL2591'},{0.2,2}); % associate our desired upper bounds
    lower_bound_ndf_map = containers.Map({'AMS7341','TSL2591'},{4,6});   % associate our desired lower bounds
    channel_to_plot_map = containers.Map({'AMS7341','TSL2591'},{9,1}); % Plot clear channel for AS, full spectrum for TS
    nDetectorChannels = MS.chip_nChannels_map(chip);
    
    assert(any(ismember(chip_name,light_sensing_chips) == true)); % assert chip choice is among light-sensing chips

    upper_bound_ndf = upper_bound_ndf_map(chip_name); % retrieve upper bound ndf for this chip
    lower_bound_ndf = lower_bound_ndf_map(chip_name); % retrieve lower bound ndf for this chip
    
    ndf_range = [lower_bound_ndf,upper_bound_ndf]; % build the range of the chip
    channel_to_plot = channel_to_plot_map(chip_name); % channel to use for our plotting

    % Step 3: Setup information for setting CombiLED 
    observerAgeInYears = str2double(GetWithDefault('Age in years','30'));
    pupilDiameterMm = str2double(GetWithDefault('Pupil diameter in mm','3'));

    photoreceptors = photoreceptorDictionaryHuman('observerAgeInYears',observerAgeInYears,'pupilDiameterMm',pupilDiameterMm);

    low_bound_freq = 0.1;
    high_bound_freq = 8;
    num_points = 20;

    frequencies = logspace(log10(low_bound_freq), log10(high_bound_freq), num_points);
    %frequencies = [1,2];

    % Step : Set up containers to hold results over the experiment
    experiment_results = nan(size(ndf_range,2),size(frequencies,2),nDetectorChannels);

    % Plot Temporal Sensitivity for a sample channel
    for bb = 1:size(ndf_range,2)
        NDF = ndf_range(bb);

        %  Step : Place the current bound NDF filter onto the light source, and begin testing
        fprintf('Place %.1f filter onto light source. Press any key when ready\n', NDF);
        pause()
        fprintf('You now have 30 seconds to leave the room if desired.');
        pause(30)

        secsPerMeasure = 0; 
        
        % Step  : Iterate over frequencies 
        for ff = 1:size(frequencies,2)
            fprintf('Frequency: %d / %d\n', ff, size(frequencies,2));
            f0 = frequencies(1,ff); % Get the current frequency
            
            % Step  : Prepare CombiLED for flicker
            modResult = designModulation('LightFlux',photoreceptors,cal);
            CL.setSettings(modResult);
            CL.setWaveformIndex(1);
            CL.setFrequency(f0);
            CL.setContrast(1);
            
            % Step 5: Prepare minispect for reading, 
            %         Define nMeasures and setup 
            %         storage for readings
            mode = chip_functions('Channels');
            nMeasures = 100; 
            counts = nan(nMeasures,nDetectorChannels);
            measurement_times = nan(nMeasures,1);
            
            % Step 5: Begin flicker and
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
                
                % Step  : Get the amplitude + phase
                amplitude  = norm(b);
                phase = -atan(b(2)/b(1));
                
                % Save the ampltiude of the current channel 
                channel_amplitudes(1,cc) = amplitude;
                fprintf('Channel %d | Amplitude %f | Phase %f\n', cc, amplitude, phase)

                % Step  Plot the source modulation, the detected, and the fit
                % counts to see how well they match 
                if(cc > 1)
                    continue
                end
                
                figure ; 
                t_measures = measurement_times;
                
                f_sinusoid = f0;
                t_sin = linspace(phase, t_measures(end), nMeasures*50);
                sinusoid = sin(2 * pi * f_sinusoid * t_sin)*amplitude + sig_mean;
            
                plot(t_sin,sinusoid);
                hold on; 
                plot(t_measures,signal+sig_mean);
                plot(t_measures,fit+sig_mean);

                title(sprintf('Signal and Fit: Channel %d Freq: %f', cc, f0));
                xlabel('Time (seconds)');
                ylabel('Counts');
                legend('Source Modulation','Signal','Fit');
                hold off; 
                 
            end

            experiment_results(bb,ff,:) = channel_amplitudes;

        end
    end

    % Step: Plot Temporal Sensitivity for a sample channel
    figure ; 
    hold on;

    % First, plot the low bound results' amplitude (normalized)
    x = frequencies; 
    y = experiment_results(1,:,channel_to_plot) / max(experiment_results(1,:,channel_to_plot)); 
    semilogx(x,y,'*-');

    
    % Then, plot the high bound results' amplitude (normalized)
    x = frequencies; 
    y = experiment_results(2,:,channel_to_plot) / max(experiment_results(2,:,channel_to_plot)); 
    semilogx(x,y,'*-');

    % Then, plot the "ideal device"
    sourceFreqsHz = frequencies;
    dTsignal = secsPerMeasure; 
    
    x = frequencies;
    y = idealDiscreteSampleFilter(sourceFreqsHz,dTsignal);
    semilogx(x,y,'-')


    xlabel('Source Frequency [log]');   
    ylabel('Relative amplitude of response');
    title(' Temporal Sensitivity for Clear/FS Channel');
    legend('Low bound','High Bound','Ideal Device');
    hold off; 

    % Step 12: Save graphs, if desired
    low_high_name_map = containers.Map({1,2},{'low','high'});
    save_or_not = input('Save figure? (y/n)', 's');
    if(save_or_not(1) == 'y')
        saveas(gcf, sprintf('%s_%s_boundTemporalSensitivity.png',chip_name, low_high_name_map(bb)));
    end 


end