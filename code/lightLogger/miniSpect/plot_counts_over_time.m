function plot_counts_over_time(chipName, calPath, darkPeriodSeconds, lightPeriodSeconds)
% Plot the counts of a given chip over time as it observes the combiLED light source
%
% Syntax:
%   backgroundSettings = calcSettingsForD65(cal)
%
% Description:
%   Given a calibration file for a light source, this routine finds primary
%   settings that produce a source spectral power distribution that best
%   matches (in a least squares sense) the D65 illuminant reference.
%
% Inputs:
%   cal                   - Struct. A calibration structure. If a cell
%                           array is passed, then the last element of the
%                           array will be used.
%   plotResultsFlag       - Logical. If set to true, a plot of the best fit
%                           spd will be shown. Set to false if not defined.
%
% Outputs:
%   backgroundSettings    - 1xn float vector. The settings values [0-1] for
%                           each of the n primaries in the light source.
%
% Examples:
%{
    calPath = fullfile(tbLocateProjectSilent('combiExperiments'),'cal','CombiLED_shortLLG_testSphere_ND0x2.mat');
    load(calPath,'cals');
    cal = cals{end};
    backgroundSettings = calcSettingsForD65(cal,true);
%}

    % Set up a parser to parse and validate inputs
    parser = inputParser; 
    parser.addRequired('chipName', @(x) isstring(x) || ischar(x)); % Ensure the chipName is a string type
    parser.addRequired('calPath', @(x) isstring(x) || ischar(x)); % Ensure the calPath is a string type
    parser.addRequired('darkPeriodSeconds', @(x) isnumeric(x) && isscalar(x)); % Ensure the dark period length is a valid numeric value
    parser.addRequired('lightPeriodSeconds', @(x) isnumeric(x) && isscalar(x)); % Ensure the light period length is a valid numeric value
    parser.parse(chipName, calPath, darkPeriodSeconds, lightPeriodSeconds);

    % Retrieve the validated arguments 
    chipName = parser.Results.chipName;
    calPath = parser.Results.calPath; 

    % Open a connection to the Minispect 
    disp('Opening connection to MiniSpect...');
    MS = mini_spect_control();
    
    % Retrieve the underlying name of the chip 
    % and retrieve its channel-reading mode
    % as well as number of channels
    chip = MS.chip_name_map(chipName);
    chip_functions = MS.chip_functions_map(chip);
    mode = chip_functions('Channels');
    nChannels = MS.chip_nChannels_map(chip); 

    % Load the cal file for the combiLED
    load(calPath,'cals');
    cal = cals{end};

    % Set the settings to be the maximum brightness
    background = [1,1,1,1,1,1,1,1]; 
    
    % Initialize combiLED light source object
    disp('Opening connection to CombiLED');
    CL = CombiLEDcontrol();

    % Update the combiLED's gamma table
    CL.setGamma(cal.processedData.gammaTable);

    % Initialize the combiLED to dark 
    CL.goDark();

    % Set up results container to save count measurements
    results = {}; 

    % Record for 1 minute without turning on the combiLED
    disp('Beginning recording dark period...');
    tic ;

    while(toc < darkPeriodSeconds)
        % Retrieve the channel values from the chip
        channel_values = MS.read_minispect(chip, mode);

        % Save the channel values
        results{end+1} = channel_values; 
    end

    % Record for 4 minutes with the combiLED on max settings
    disp('Beginning recording light period...');
    CL.setPrimaries(background);

    tic ; 

    while(toc < lightPeriodSeconds)
        % Retrieve the channel values from the chip
        channel_values = MS.read_minispect(chip, mode);

        % Save the channel values
        results{end+1} = channel_values; 
    end

    % Reshape the results into an nMeasures x nChannels matrix
    disp('Reshaping results...');
    results = cell2mat(results');

    % Close the serial connections to the devices
    disp('Closing serial connections...')
    CL.serialClose(); 
    MS.serialClose_minispect();
 
    % Plot the results of a single channel
    disp('Plotting...')
    figure ; 
    hold on ; 
    plot(results(:,4));
    title(sprintf('%s Counts over Time', chipName)); 
    xlabel('Measurement');
    ylabel('Count');



end