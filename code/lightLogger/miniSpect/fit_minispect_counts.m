function fit_minispect_counts(MSCalDataFiles)
% Fits measured counts from the minispect to predicted counts
%
% Syntax:
%   fit_minispect_counts(MSCalDataFiles, calFiles)
%
% Description:
%   Given a cell array of paths to MSCalData files over different NDF
%   levels, load them in and fit the measured counts to predicted counts in
%   those conditions (and with equivalent source calibration files). Graphs the results.
%
% Inputs:
%   MSCalDataFiles        - Cell Array. Array of paths to MSCalData files
%
%   calFiles              - Cell Array. Array of paths to light source cal files
%
% Outputs:
%   NONE
%
% Examples:
%{
    dropboxBaseDir = getpref('combiExperiments','dropboxBaseDir');
    calDir = fullfile(dropboxBaseDir,'FLIC_admin','Equipment','MiniSpect','calibration','FBF0EF4C301382EA');
    d = dir(fullfile(calDir,'*mat'));
    MSCalDataFiles = cellfun(@(x) fullfile(calDir, x), {d.name}, 'UniformOutput', false);

    fit_minispect_counts(MSCalDataFiles);
%}

% Change printing format to be able to see long counts
format long g;

% Parse the arguments
parser = inputParser; 

% Validate the arguments' type and size > 0 
parser.addRequired('MSCalDataFiles', @(x) iscell(x) && numel(x) ~= 0);

% Parse the arguments
parser.parse(MSCalDataFiles); 

% Retrieve the validated arguments
MSCalDataFiles = parser.Results.MSCalDataFiles;  

% Load the first MSCalDataFile, get the S, as we need this to resample the
% detector spectral sensitivity functions
MSCalData = load(MSCalDataFiles{1}).MSCalData;
sourceS = MSCalData.meta.source_cal.rawData.S;

% Retrieve the wavelengths
wls = SToWls(sourceS); 

% Determine the number of settings examined for each ND level
nSettingsLevels = size(MSCalData.raw.background_scalars{1},2);

% Assume there is a max spectrum file with the same name as the source_cal file with max spectrum appended
source_max_spectrum_path = strrep(MSCalData.meta.source_calpath, '.mat', '_maxSpectrum.mat');

% Currently, the code is using a hard-coded path to these cal files,
% instead of building the relative path for this user. This step is needed
% for Geoff to run the routine
%{
    source_max_spectrum_path = strrep(source_max_spectrum_path,'zacharykelly','aguirre');
%}

% Find the NDF used for the source max spectrum
source_max_spectrum_ndf = regexp(source_max_spectrum_path, 'ND\d', 'match');  
source_max_spectrum_ndf = source_max_spectrum_ndf{1};

% Smoothing parameter for transmittance function, found by hand by Geoff via manual testing
smoothParam = 0.0025;

% How many of the minispect cal data files to plot (we do not have a calibration for 6 NDF, so just 0-5)
nMeasToPlot = numel(MSCalDataFiles)-1;

% Load the source spectrum
load(source_max_spectrum_path, 'cals'); 
source_max_spectrum = cals{end}.rawData.gammaCurveMeanMeasurements; 

clear MSCalData;

% Load the minispect SPDs
spectral_sensitivity_map = containers.Map({'AMS7341'},...%'TSL2591'},...%"TSL2591"},...
    {fullfile(tbLocateProjectSilent('combiExperiments'),'data','ASM7341_spectralSensitivity.mat')});
    %fullfile(tbLocateProjectSilent('combiExperiments'),'data','TSL2591_spectralSensitivity.mat')});

% For each chip, reformat the minispect SPDs to be in the space of the
% sourceSPDs
chips = ["AMS7341"];%"TSL2591"];%"TSL2591"];
minipspectP_rels_map = containers.Map();

for ii = 1:numel(chips)
    miniSpectSPDPath = spectral_sensitivity_map(chips(ii));
    load(miniSpectSPDPath,'T');
    minispectS = WlsToS(T.wl);
    minispectP_rel = T{:,2:end};

    detectorP_rel = [];
    for jj = 1:size(minispectP_rel,2)
        detectorP_rel(:,jj) = interp1(SToWls(minispectS),minispectP_rel(:,jj),SToWls(sourceS));
    end

    minipspectP_rels_map(chips(ii)) = detectorP_rel;

end

% Establish containers to hold the measurements 
% and predicted values for the chips across 
% the different calibrations
measured_map = containers.Map({'AMS7341','TSL2591'},...
    {   {}    ,   {}    });
predicted_map = containers.Map({'AMS7341','TSL2591'},...
    {   {}    ,   {}    });

% Prepare a figure to show the transmittance functions
figure

% For each MSCalDataFile calibration
for ii = 1:nMeasToPlot
    % Load this MSCalFile
    MSCalData = load(MSCalDataFiles{ii}).MSCalData;

    chip_struct_map = containers.Map({'AMS7341','TSL2591'},...
        {MSCalData.ASChip,MSCalData.TSChip});

    % Extract NDF and the source calibration struct
    NDF = MSCalData.meta.params.NDF;
    source_cal = MSCalData.meta.source_cal;

    % Check that the sourceS associated with the current MSCalDataFile
    % matches that we extracted at the top of the routine
    assert(all(source_cal.rawData.S == sourceS));

    % Find the path to the max spectrum file for this NDF
    local_max_spectrum_path = strrep(source_max_spectrum_path, source_max_spectrum_ndf, sprintf('ND%d', NDF)); 

    % Load the source spectrum
    load(local_max_spectrum_path, 'cals'); 
    local_max_spectrum = cals{end}.rawData.gammaCurveMeanMeasurements; 

    % Calculate the transmittance function
    transmittance_function_raw = local_max_spectrum ./ source_max_spectrum;
    
    % Find non-inf values in the transmittance function (as local spectrum could have 0 when dividing)
    goodIdx = isfinite(transmittance_function_raw);
    badIdx = ~isfinite(transmittance_function_raw); 

    % Calculate the transmittance function. Smooth the function using csaps
    % if this function is available
    transmittance_function = transmittance_function_raw; 
    if exist('csaps','file')
        transmittance_function(goodIdx) = csaps(wls(goodIdx), transmittance_function_raw(goodIdx), smoothParam, wls(goodIdx));
    end
    transmittance_function(badIdx) = 0; 
    transmittance_function(transmittance_function<0) = 0; 

    % Plot this transmittance function
    plot(wls,log10(transmittance_function_raw),'.');
    hold on
    plot(wls,log10(transmittance_function),'-k');

    % Extract information regarding the light source that was used to
    % calibrate the minispect
    sourceP_abs = source_cal.processedData.P_device;

    % Extract some params from the MSCalData.meta.params
    nPrimarySteps = MSCalData.meta.params.nPrimarySteps;
    nSamplesPerStep = MSCalData.meta.params.nSamplesPerStep;
    nReps = MSCalData.meta.params.nReps;
    randomizeOrder = MSCalData.meta.params.randomizeOrder;

    % For each chip 
    for cc = 1:numel(chips)
        % Initialize a summation variable for the detector counts
        % as we are going to average them over the reps
        sum_detector_counts = 0; 

        % Initialize the predictedCounts variable to some value. 
        % this is to have it in scope for use later. 
        predictedCounts = 0; 

        % Iterate over repetitions
        for jj = 1:nReps
            % Find the corresponding MSCalData info
            % and detectorP_rel for this chip
            chip_struct = chip_struct_map(chips(cc));
            detectorP_rel = minipspectP_rels_map(chips(cc));

            % Grab the channels of the chip we are fitting
            nDetectorChannels = chip_struct.meta.nDetectorChannels;

            % Grab the minispect counts from this rep
            detectorCounts = chip_struct.raw.counts{jj};

            % Ensure we did not get any weird floating point numbers (as counts should be entirely integers)
            assert(all(mod(detectorCounts(:), 1) == 0));

            % Take the mean across the nSamplesPerStep made at each
            % setting. We may later be interested in the variability across
            % the set of measures
            detectorCounts = squeeze(mean(detectorCounts,1));

            % Get the sorted background_scalar values for this rep
            background_scalars_sorted = sort(MSCalData.raw.background_scalars{jj});

            % Get the background
            background = MSCalData.raw.background;

            % Initialize some variables to hold loop results
            sphereSPDs = nan(nPrimarySteps,sourceS(3));
            predictedCounts = nan(nPrimarySteps,nDetectorChannels);

            % Iterate over the source primary setting values
            for kk = 1:nPrimarySteps
                % Get the source settings by multiplying background
                % by the scalar value at primaryStep kk
                source_settings = background * background_scalars_sorted(kk);

                % Derive the sphereSPD for this step in units of W/m2/sr/nm. We divide
                % by the nanometer sampling given in S to cast the units as nm, as
                % opposed to (e.g.) per 2 nm.
                sphereSPDs(kk,:) = ( (sourceP_abs*source_settings')/sourceS(2) ) .* transmittance_function;

                % Apply the transmittance function

                % Derive the prediction of the relative counts based upon the sphereSPD
                % and the minispectP_rel.
                predictedCounts(kk,:) = sphereSPDs(kk,:)*detectorP_rel;

            end % nPrimarySteps
         
            % Sum the counts from this repetition
            sum_detector_counts = sum_detector_counts + detectorCounts;

        end

       % Retrieve the containers holding the results per measure
        measured = measured_map(chips(cc));
        predicted = predicted_map(chips(cc));

        % Append the newest measurement results
        measured{ii} = sum_detector_counts / nReps; 
        predicted{ii} = predictedCounts; 

        % Resave the containers
        measured_map(chips(cc)) = measured;
        predicted_map(chips(cc)) = predicted;
        
    end % nReps

end % nCalibrations

% Plot each chip's measured vs predicted counts
for kk = 1:numel(chips)

    % Retrieve the measured/predicted counts for this chip
    measured = measured_map(chips(kk));
    predicted = predicted_map(chips(kk));

    % Concatenate the measured and predicted matrices across the multiple
    % calibrations
    measured=cat(1,measured{:});
    predicted=cat(1,predicted{:});


    % Loop across the channels and show the predicted vs.
    figure
    tiledlayout(2,5);
    for cc = 1:nDetectorChannels
        nexttile
        x = log10(predicted(:,cc));
        y = log10(measured(:,cc));
        for mm = 1:nMeasToPlot
            thisIdx = (mm-1)*nSettingsLevels+1:mm*nSettingsLevels;
            plot(x(thisIdx),y(thisIdx),'o');
            hold on
        end
        goodIdx = and(~isinf(y),~isinf(x));
        x = x(goodIdx); y = y(goodIdx);
        p = polyfit(x,y,1);
        fitY = polyval(p,x);
        plot(x,fitY,'-k')
        refline(1,0)
        ylim([-3 5]); xlim([-3 5]);
        axis square
        xlabel(sprintf('%s predicted counts [log]', chips(kk)));
        ylabel(sprintf('%s measured counts [log]', chips(kk)));
        title(sprintf('channel %d, [slope intercept] = %2.2f, %2.2f',cc,p));
    end
end

end % function
