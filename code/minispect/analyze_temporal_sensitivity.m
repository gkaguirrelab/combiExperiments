function analyze_temporal_sensitivty(cal_path,chip_name)
% Analyzes the temporal sensitivity of a given light-sensing chip in the minispect
%
% Syntax:
%   analyze_temporal_sensitivty(cal_path,chip_name)
%
% Description:
%  Generates temporal sensitivity plots for both high and low light levels
%  of a given light-sensing chip in the MiniSpect. Also displays source modulation, 
%  observed, with observed counts and fitted counts layered ontop during runtime. Does 
%  not save these.  
%
% Inputs:
%   cal_path              - String. Represents the path to the light source
%                           calibration file.      
%
%   chip_name             - String. Represents the full name of the light-sensing
%                           chip to use for the experiment          
%
% Outputs:
%   experiment_results    - Array. Contains the amplitudes per channel 
%                           per frequency, for the low and high light levels
%
% Examples:
%{
   chip_name = 'TSL2591';
   cal_path = './cal';
   analyze_temporal_sensitivty(cal_path,chip_name);
%}

    % Utility Functions
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

    calDir = fullfile(tbLocateProjectSilent('combiExperiments'),'cal'); % Which Cal file to use (currently hard-coded)
    calFileName = 'CombiLED_shortLLG_testSphere_ND0x2.mat';

    cal_path = fullfile(calDir,calFileName);

    load(cal_path,'cals'); % Load the cal file
    cal = cals{end};
    
    CL = CombiLEDcontrol(); % Initialize CombiLED Object
    CL.setGamma(cal.processedData.gammaTable);  % Update the combiLED's gamma table

    % Step 2: Ensure MS is at our desired settings
    MS.reset_settings();

    % Step 3: Select chip of MS to analyze
    light_sensing_chips = ['AMS7341','TSL2591']; % The chips on the MS that can detect light 
    chip = MS.chip_name_map(chip_name); % the underlying representation of the chip 
    
    % Step 4: Retrieve information about the experiment/chip
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

    % Step 5: Setup information for setting CombiLED and the experiment 
    observerAgeInYears = str2double(GetWithDefault('Age in years','30'));
    pupilDiameterMm = str2double(GetWithDefault('Pupil diameter in mm','3'));

    photoreceptors = photoreceptorDictionaryHuman('observerAgeInYears',observerAgeInYears,'pupilDiameterMm',pupilDiameterMm);

    low_bound_freq = 0.1;  % The lowest frequency with which the CombiLED will flicker    
    high_bound_freq = 8;   % The highest frequency with which the CombiLED will flicker
    num_points = 2;       % The number of points between the low and high frequency to measure
    nMeasures = 5;       % The number of measurements at a given frequency

    frequencies = logspace(log10(low_bound_freq), log10(high_bound_freq), num_points); % create num_points equally log spaced
                                                                                       % points between the low and high bounds

    % Step 6: Set up containers to hold results over the experiment
    experiment_results = nan(size(ndf_range,2),size(frequencies,2),nDetectorChannels);

    % Step 7: Begin experiment, go over the low and high NDF ranges
    for bb = 1:size(ndf_range,2)
        NDF = ndf_range(bb);

        fprintf('Place %.1f filter onto light source. Press any key when ready\n', NDF);
        pause()
        fprintf('You now have 30 seconds to leave the room if desired.\n');
        pause(30)

        secsPerMeasure = 0; 
        
        % Step 8: Iterate over frequencies 
        for ff = 1:size(frequencies,2)
            fprintf('Frequency: %d / %d\n', ff, size(frequencies,2));
            f0 = frequencies(1,ff); % Get the current frequency
            
            % Step 9: Prepare CombiLED for flicker
            modResult = designModulation('LightFlux',photoreceptors,cal);
            CL.setSettings(modResult);
            CL.setWaveformIndex(1);
            CL.setFrequency(f0);
            CL.setContrast(1);
            
            % Step 10: Prepare minispect for reading, 
            %         Define nMeasures and setup 
            %         storage for readings
            mode = chip_functions('Channels');
            counts = nan(nMeasures,nDetectorChannels);
            measurement_times = nan(nMeasures,1);
            
            % Step 11: Begin flicker and
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

            % Step 12: Derive amplitude of counts at the fundamental
            %         frequency of CombiLED's flicker
            secsPerMeasure = elapsed_seconds/nMeasures;
            
            channel_amplitudes = nan(1,nDetectorChannels);
            for cc = 1:nDetectorChannels
                signal = counts(:,cc);
                signalT = 0:secsPerMeasure:elapsed_seconds-secsPerMeasure; 


                sig_mean = mean(signal);
                signal = signal - mean(signal);  % freq is the source flicker freq in Hz. Signal is the vector of measures for a channel
                % sampling frequency of signal 
                fs = 1./secsPerMeasure;
                modeldT = 0.01; 
                modelT = 0:modeldT:elapsed_seconds - modeldT; 
                % Set up the regression matrix
                X = [];
                X(:,1) = sin(  modelT./(1/f0).*2*pi );
                X(:,2) = cos(  modelT./(1/f0).*2*pi );
                % Perform the fit
                y = interp1(signalT,signal,modelT,'nearest','extrap')';
                b = X\y;

                fit = X * b;  % high temporal resolution fit,
                
                amplitude  = norm(b);
                phase = -atan(b(2)/b(1));
                
                % Save the ampltiude of the current channel 
                channel_amplitudes(1,cc) = amplitude;
                fprintf('Channel %d | Amplitude %f | Phase %f\n', cc, amplitude, phase)

                % Step 13: Plot the source modulation, the detected, and the fit
                % counts to see how well they match for channel 1
                
                if(cc > 1)
                    continue
                end

                figure ;
  
                plot(signalT,signal+sig_mean);
                hold on; 
                plot(modelT,fit+sig_mean);

                title(sprintf('Signal and Fit: Channel %d Freq: %f', cc, f0));
                xlabel('Time (seconds)');
                ylabel('Counts');
                legend('Signal','Fit');
                hold off; 
                 
            end

            experiment_results(bb,ff,:) = channel_amplitudes;

        end
    end

    % Step 14: Save the results of the experiment, so we don't need to 
    % rerun it if there are plotting issues
    save(sprintf('%s_results.mat',chip_name),'experiment_results');

    % Step 15: Plot Temporal Sensitivity for a sample channel
    figure ; 
    hold on;

    x = frequencies; % First, plot the low bound results' amplitude (normalized)
    y = experiment_results(1,:,channel_to_plot) / max(experiment_results(1,:,channel_to_plot)); 
    plot(log10(x),y,'*-');

    x = frequencies; % Then, plot the high bound results' amplitude (normalized)
    y = experiment_results(2,:,channel_to_plot) / max(experiment_results(2,:,channel_to_plot)); 
    plot(log10(x),y,'*-');

    sourceFreqsHz = frequencies; % Then, plot the "ideal device"
    dTsignal = secsPerMeasure; 
    
    x = frequencies;
    y = idealDiscreteSampleFilter(sourceFreqsHz,dTsignal);
    plot(log10(x),y,'-');


    % Take sampling frequency * 2 -> 1 / that and then plot this onto plot 
    % this is the nyquist. 

    xlabel('Source Frequency [log]');   
    ylabel('Relative amplitude of response');
    title(' Temporal Sensitivity for Clear/FS Channel');
    legend('Low bound','High Bound','Ideal Device');
    hold off; 

    % Step 16: Save graphs, if desired
    save_or_not = input('Save figure? (y/n)', 's');
    drop_box_dir = [getpref('combiExperiments','dropboxBaseDir'), '/FLIC_admin/Equipment/MiniSpect/calibration/graphs/'];
    if(save_or_not(1) == 'y')
        saveas(gcf, sprintf('%s%s_TemporalSensitivity.png',drop_box_dir,chip_name));
    end 

end