function plot_counts_over_time(chipName, calPath, darkPeriodSeconds, lightPeriodSeconds, NDF, email)
% Plot the counts of a given chip over time as it observes the combiLED light source
%
% Syntax:
%   plot_counts_over_time(chipName, calPath, darkPeriodSeconds, lightPeriodSeconds, NDF, email)
%
% Description:
%   Record from a given MS chip for a given amount of time dark, 
%   then a given amount of time light at a given NDF level. Plot 
%   the resulting counts. 
%
% Inputs:
%
%   chipName               - String. Represents the name of the chip
%                           to use for recording. 
%
%
%   calPath                - String. Represents the path to the light 
%                           source calibration file. 
%
%   darkPeriodSeconds      - Int. The number of seconds to record 
%                           in complete darkness. 
%
%   lightPeriodSeconds     - Int. The number of seconds to record 
%                           at half the maximum light level.       
%
% Outputs:
%   
%   None
%
% Examples:
%{
    chipName = "ASM7341"; 
    calPath = fullfile(tbLocateProjectSilent('combiExperiments'),'cal','CombiLED_shortLLG_sphere_ND0.mat');
    darkPeriodSeconds = 5; 
    lightPeriodSeconds = 5; 
    NDF = 0; 
    email = "Zachary.Kelly@pennmedicine.upenn.edu";
    plot_counts_over_time(chipName, calPath, darkPeriodSeconds, lightPeriodSeconds, NDF, email); 
%}

    % Set up a parser to parse and validate inputs
    parser = inputParser; 
    parser.addRequired('chipName', @(x) isstring(x) || ischar(x)); % Ensure the chipName is a string type
    parser.addRequired('calPath', @(x) isstring(x) || ischar(x)); % Ensure the calPath is a string type
    parser.addRequired('darkPeriodSeconds', @(x) isnumeric(x) && isscalar(x)); % Ensure the dark period length is a valid numeric value
    parser.addRequired('lightPeriodSeconds', @(x) isnumeric(x) && isscalar(x)); % Ensure the light period length is a valid numeric value
    parser.addRequired('NDF', @(x) isnumeric(x) && isscalar(x)); % Ensure the NDF is a valid numeric value
    parser.addRequired('email', @(x) isstring(x) || ischar(x)); % Ensure the email is a string
    parser.parse(chipName, calPath, darkPeriodSeconds, lightPeriodSeconds, NDF, email);

    % Retrieve the validated arguments 
    chipName = parser.Results.chipName;
    calPath = parser.Results.calPath; 
    darkPeriodSeconds = parser.Results.darkPeriodSeconds;
    lightPeriodSeconds = parser.Results.lightPeriodSeconds; 
    NDF = parser.Results.NDF; 
    email = parser.Results.email; 

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

    % Set the settings to be half of the max brightness for a given NDF level
    background = [1,1,1,1,1,1,1,1] * 0.5; 
    
    % Initialize combiLED light source object
    disp('Opening connection to CombiLED');
    CL = CombiLEDcontrol();

    % Update the combiLED's gamma table
    CL.setGamma(cal.processedData.gammaTable);
    CL.setDirectModeGamma(true);

    % Initialize the combiLED to dark 
    CL.goDark();

    % Set up results container to save count measurements
    results = {}; 

    % Pause to allow for user to leave the room 
    disp('You know have 30 seconds to leave the room before measurement begins');
    pause(30);

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

    save(sprintf('%dNDF_counts_over_time.mat', NDF), 'results');

    sendmail(email, 'Done recording counts over time!');




end