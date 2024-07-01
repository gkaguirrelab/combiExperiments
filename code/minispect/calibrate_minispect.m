function calibrate_minispect(NDF,cal_path,nPrimarySteps,nSamplesPerStep,reps,randomizeOrder,simulateSource,simulateDetector,save_path)

if(~islogical(randomizeOrder) || ~islogical(simulateSource) || ~islogical(simulateDetector))
    error("Ensure flag arguments are of boolean/logical type");
end 

% Hard Coded Parameters for now
simulateSource = false;
simulateDetector = false;
nPrimarySteps = 10;
nSamplesPerStep = 10;
reps = 1; 

try

% Which Cal file to use (currently hard-coded)
calDir = fullfile(tbLocateProjectSilent('combiExperiments'),'cal');
calFileName = 'CombiLED_shortLLG_testSphere_ND0x2.mat';

cal_path = fullfile(calDir,calFileName);

% Load the cal file
load(cal_path,'cals');
cal = cals{end};


% If we are not simulating, initialize the detector
if ~simulateDetector
    % Initialize minispect object
    MS = mini_spect_control();

    % Initialize the chip we want and the mode for it to be in
    chip = MS.chip_name_map("AMS7341");
    chip_functions = MS.chip_functions_map(chip);
    mode = chip_functions('Channels');
    
    % Get the number of channels it can observe
    nChannels = MS.nChannels;

    % Get the device's serial number
    deviceSerialNumber = MS.read_minispect('S','S');
else 
    % Otherwise hard code device info
    nChannels = 10;
    deviceSerialNumber = 'SIMULATED';
end 

% If we are not simulating, initialize the light source
if ~simulateSource
    % Initialize combiLED object
    CL = CombiLEDcontrol();
    
    % Update the gamma table
    CL.setGamma(cal.processedData.gammaTable);
end


% Extract some information regarding the light source that is being used to
% calibrate the minispect
sourceS = cal.rawData.S;
sourceP_abs = cal.processedData.P_device;
nSourcePrimaries = cal.describe.displayPrimariesNum;

% Initialize holder for measurements 
counts = nan(reps,nPrimarySteps,nChannels,nSamplesPerStep);

% Define combiLED settings and their order
order_map = containers.Map({true,false},{randperm(nPrimarySteps),1:nPrimarySteps});
setting_formula = @(ii) 0.05+((ii-1)/(nPrimarySteps-1))*0.9;
combi_settings = arrayfun(setting_formula, 1:nPrimarySteps);
settings_order = order_map(randomizeOrder);

% Finalized settings
combi_settings = combi_settings(settings_order);

% Run through every combiLED setting
for ii = 1:length(combi_settings)
    fprintf("Primary Step: %d / %d\n", ii, nPrimarySteps);

    % Perform desired repetitions of each setting
    for jj = 1:reps
        fprintf("Repetition: %d / %d\n", jj, reps);

        % Get the current combiLED setting
        primary_setting = combi_settings(ii);

        % Set the CombiLED settings
        CL_settings = primary_setting * ones(1,8);

        % Set primaries if we are not simulating
        if ~simulateSource
            CL.setPrimaries(CL_settings);
        end

        % Record N samples from the minispect
        if ~simulateDetector
            for kk = 1:nSamplesPerStep
                fprintf("Sample: %d / %d\n", kk, nSamplesPerStep);
                channel_values = MS.read_minispect(chip,mode);

                counts(jj,ii,:,kk) = channel_values;

            end
        end
    end
end

% Make sure all data was read properly
if(any(isnan(counts)))
    error('NaNs present in counts');
end 

MSCalData = struct; 

raw_data = struct; 
raw_data.counts = counts; 
raw_data.meta = combi_settings; 

parameters = struct; 
parameters.NDF = NDF;
parameters.nPrimarySteps = nPrimarySteps;
parameters.nSamplesPerStep = nSamplesPerStep; 
parameters.reps = reps; 
parameters.simulateSource = simulateSource;
parameters.simulateDector = simulateDetector; 
parameters.randomizeOrder = randomizeOrder; 

meta_data = struct; 
meta_data.serialNumber = deviceSerialNumber;
meta_data.cal = cal_path; 
meta_data.params = parameters; 
meta_data.date = datetime('now');

MSCalData.raw = raw_data;
MSCalData.meta = meta_data; 

% Save the calibration results
save(save_path,'MSCalData');

% Close the serial ports with the devices if we did not simulate them
if ~simulateSource
    CL.serialClose();
    clear CL;
end

if ~simulateDetector
    MS.serialClose_minispect();
    clear MS;
end

catch e
    disp('Catching Error and closing ports')
    
    disp(e)
    disp(e.stack)
    
    CL.serialClose();
    clear CL;
    MS.serialClose_minispect();
    clear MS;
end


end