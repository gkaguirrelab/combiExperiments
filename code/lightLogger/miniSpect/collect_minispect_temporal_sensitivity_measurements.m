function collect_minispect_temporal_sensitivty_measurements(cal_path, chip_name, email)
% Collect measurements for use of measuring the temporal sensitivity of the MS
%
% Syntax:
%   collect_minispect_temporal_sensitivty_measurements(cal_path, chip_name, email)
%
% Description:
%  Collect measurements using the MS and the combiLED to be used 
%  for analyzing the temporal sensitivity of the given chip. When NDF levels 
%  need to be exchanged, sends an alert email to the given email. When finished,
%  also sends an email to the given email.   
%
% Inputs:
%   cal_path              - String. Represents the path to the light source
%                           calibration file.      
%
%   chip_name             - String. Represents the full name of the light-sensing
%                           chip to use for the experiment   
%   email                 - String. Represents the adddress to send an email to 
%                           when measurement collection is finished.        
%
% Outputs:
%   results               - Struct. Contains the measured amplitudes and per-frequency 
%                           fits, as well as other information (NDF range, secsPerMeasure)
%                           about the experiment. 
%
%   modResult             - Struct. Contains the information used to compose
%                           the flicker profile. 
%
% Examples:
%{
   chip_name = 'TSL2591';
   cal_path = '/Users/zacharykelly/Documents/MATLAB/projects/combiExperiments/cal/CombiLED_shortLLG_sphere_ND0.mat';
   email = 'Zachary.Kelly@pennmedicine.upenn.edu';
   collect_minispect_temporal_sensitivity_measurements(cal_path, chip_name, email)
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


    % Parse and validate the input arguments
    parser = inputParser; 

    parser.addRequired('cal_path', @(x) ischar(x) || isstring(x)) % Ensure cal_path is a string
    parser.addRequired('chip_name', @(x) ischar(x) || isstring(x)) % Ensure chip_name is a string 
    parser.addRequired('email', @(x) ischar(x) || isstring(x)); % Ensure email is a string

    parser.parse(cal_path, chip_name, email);

    cal_path = parser.Results.cal_path;
    chip_name = parser.Results.chip_name;
    email = parser.Results.email; 

    % Step 1: Connect MiniSpect and CombiLED
    MS = mini_spect_control(); % Initialize MiniSpect Object

    load(cal_path,'cals'); % Load the cal file
    cal = cals{end};
    
    CL = CombiLEDcontrol(); % Initialize CombiLED Object
    CL.setGamma(cal.processedData.gammaTable);  % Update the combiLED's gamma table

    % Step 2: Ensure MS is at our desired settings
    MS.reset_settings();

    % Step 3: Select chip of MS to analyze 
    assert(any(ismember(chip_name, MS.light_sensing_chips) == true)); % assert chip choice is among light-sensing chips
    chip = MS.chip_name_map(chip_name); % the underlying representation of the chip 
    
    % Step 4: Retrieve information about the chip
    chip_functions = MS.chip_functions_map(chip); % Retrieve the available functions of the given chip
    upper_bound_ndf_map = containers.Map({'AMS7341','TSL2591'},{0,2}); % associate our desired upper bounds
    lower_bound_ndf_map = containers.Map({'AMS7341','TSL2591'},{4,6});   % associate our desired lower bounds
    channel_to_plot_map = containers.Map({'AMS7341','TSL2591'},{9,1}); % Plot clear channel for AS, full spectrum for TS
    nDetectorChannels = MS.chip_nChannels_map(chip);

    upper_bound_ndf = upper_bound_ndf_map(chip_name); % retrieve upper bound ndf for this chip
    lower_bound_ndf = lower_bound_ndf_map(chip_name); % retrieve lower bound ndf for this chip
    
    ndf_range = [lower_bound_ndf, upper_bound_ndf]; % build the range of the chip
    channel_to_plot = channel_to_plot_map(chip_name); % channel to use for our plotting

    % Step 5: Setup information for setting CombiLED and the experiment 
    observerAgeInYears = 30;
    pupilDiameterMm = 3;
    
    photoreceptors = photoreceptorDictionaryHuman('observerAgeInYears',observerAgeInYears,'pupilDiameterMm',pupilDiameterMm);

    low_bound_freq = 0.1;  % The lowest frequency with which the CombiLED will flicker    
    high_bound_freq = 8;   % The highest frequency with which the CombiLED will flicker
    num_points = 2;       % The number of points between the low and high frequency to measure
    nMeasures = 5;       % The number of measurements at a given frequency

    frequencies = logspace(log10(low_bound_freq), log10(high_bound_freq), num_points); % create num_points equally log spaced
                                                                                       % points between the low and high bounds
    modResult = designModulation('LightFlux',photoreceptors,cal);
    CL.setSettings(modResult);
    CL.setWaveformIndex(1);
    CL.setContrast(1);

    % Step 6: Set up containers to hold results over the experiment
    % Container for how well the observed modulation fits the source modulation
    fits = containers.Map(ndf_range, {containers.Map(frequencies, cell(length(frequencies), 1)), containers.Map(frequencies, cell(length(frequencies), 1))});

    % container for amplitudes for each freq at each ndf
    ndf_freq_amplitudes = nan(size(ndf_range,2),size(frequencies,2),nDetectorChannels);

    % Initialize variable to track how long each measurement takes
    secsPerMeasure = 0; 

    % Step 7: Begin experiment, go over the low and high NDF ranges
    for bb = 1:size(ndf_range,2)
        NDF = ndf_range(bb);

        fprintf('Place %.1f filter onto light source. Press any key when ready\n', NDF);
        pause()
        fprintf('You now have 30 seconds to leave the room if desired.\n');
        pause(30)
        
        % Step 8: Iterate over frequencies 
        for ff = 1:size(frequencies,2)
            fprintf('Frequency: %d / %d\n', ff, size(frequencies,2));
            f0 = frequencies(1,ff); % Get the current frequency
            
            % Step 9: Prepare CombiLED for flickering at 
            % a given frequency 
            CL.setFrequency(f0);
            
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
                
                % Retrieve the map of frequencies to their fits 
                frequency_fit_map = fits(NDF);
                
                % Assert the fit information are in col vector format before saving
                assert(iscolumn(signalT'));
                assert(iscolumn(signal));
                assert(iscolumn(modelT'));
                assert(iscolumn(fit)); 

                % Save the fit information for this frequency in a matrix
                frequency_fit_map(f0) = {signalT', (signal+sig_mean), modelT', (fit+sig_mean)}; 
                
                % Resave the map with the now added fit
                fits(NDF) = frequency_fit_map;

                plot(signalT,signal+sig_mean);
                hold on; 
                plot(modelT,fit+sig_mean);

                title(sprintf('Signal and Fit: Channel %d  %.1f NDF %fhz', NDF, cc, f0));
                xlabel('Time (seconds)');
                ylabel('Counts');
                legend('Signal','Fit');
                hold off; 
                 
            end
            
            % Store the amplitude results for this NDF bound and this frequency
            ndf_freq_amplitudes(bb,ff,:) = channel_amplitudes;

        end

        % Alert the user that the NDF filter needs to be exchanged 
        sendmail(email, 'Change the NDF filter for MS temporal sensitivity measurement');

    end 

    % Close serial connections 
    CL.serialClose();
    MS.serialClose_minispect();

    % Save the experiment results into the results struct 
    results.frequencies = frequencies; 
    results.ndf_range = ndf_range; 
    results.fits = fits; 
    results.ndf_freq_amplitudes = ndf_freq_amplitudes; 
    results.secsPerMeasure = secsPerMeasure; 
    results.chip_name = chip_name; 

    % Save the measurements and the flicker profile used to generate them. 
    drop_box_dir = [getpref('combiExperiments','dropboxBaseDir'), '/FLIC_admin/Equipment/MiniSpect/calibration/graphs/'];
    save(sprintf('%s%s_TemporalSensitivtyMeasurements.mat', drop_box_dir, chip_name), 'results');
    save(sprintf('%s%s_TemporalSensitivityFlicker.mat', drop_box_dir, chip_name), 'modResult');

    % Send an email that the measurement has finished
    sendmail(email, 'Finished collecting MS temporal sensitivity measurment');

end