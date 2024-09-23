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
    calDir = fullfile(dropboxBaseDir,'FLIC_admin','Equipment','MiniSpect','calibration','5FA5D4668ADCF1FB');
    d = dir(fullfile(calDir,'*mat'));
    MSCalDataFiles = cellfun(@(x) fullfile(calDir, x), {d.name}, 'UniformOutput', false);

    fit_minispect_counts(MSCalDataFiles);
%}

% Define where we should save the plots
dropboxBaseDir = getpref('combiExperiments','dropboxBaseDir');
figSavePath = fullfile(dropboxBaseDir,'FLIC_admin','Equipment','MiniSpect','calibration','graphs');

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

% Create a map for the filters used to select good indices from the resulting curves for each chip
as_chip_point_filter = @(x, y) and(and(~isinf(y), ~isinf(x)), y >= 0.25); % AS chip we want to exclude points in the mud
ts_chip_point_filter= @(x, y) and(and(~isinf(y), ~isinf(x)), y < max(y)); % TS chip we want to exclude points that are saturated
goodIdxFilterMap = containers.Map({'AMS7341', 'TSL2591'},...
                                  {as_chip_point_filter, ts_chip_point_filter});

% Create a map for the limits for the chips' associated curves 
lim_map = containers.Map({'AMS7341', 'TSL2591'},...
                          {[-1, 5], [-1, 6]});
                       
% The number of minispect cal data files to plot, which is the number of
% different ND filter levels that were measured
nMeasToPlot = numel(MSCalDataFiles);

% Create some distinct colors to be used to plot each of these levels
plotColors = distinguishable_colors(nMeasToPlot);

% Load the source spectrum
load(source_max_spectrum_path, 'cals');
source_max_spectrum = cals{end}.rawData.gammaCurveMeanMeasurements;

clear MSCalData;

% Load the minispect SPDs
spectral_sensitivity_map = containers.Map({'AMS7341', 'TSL2591'},...
                                          {fullfile(tbLocateProjectSilent('combiExperiments'),'data','ASM7341_spectralSensitivity.mat');
                                          fullfile(tbLocateProjectSilent('combiExperiments'),'data','TSL2591_spectralSensitivity.mat')});

% For each chip, reformat the minispect SPDs to be in the space of the
% sourceSPDs
chips = ["AMS7341", "TSL2591"];%"TSL2591"];
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
figHandle = figure;

% For each MSCalDataFile calibration
for ii = 1:nMeasToPlot

    % Load this MSCalFile
    MSCalData = load(MSCalDataFiles{ii}).MSCalData;

    chip_struct_map = containers.Map({'AMS7341','TSL2591'},...
        {MSCalData.ASChip,MSCalData.TSChip});

    % Extract NDF and the source calibration struct
    NDF = MSCalData.meta.params.NDF;
    source_cal = MSCalData.meta.source_cal;

    % Save the NDF identities for later plotting
    ndfUsedForEachMeasure(ii) = NDF;

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
    plot(wls,log10(transmittance_function_raw),'.','Color',plotColors(ii,:));
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
        % Retrieve the chip to use
        chip = chips(cc);

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
            chip_struct = chip_struct_map(chip);
            detectorP_rel = minipspectP_rels_map(chip);

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

                % Derive the prediction of the relative counts based upon the sphereSPD
                % and the minispectP_rel.
                predictedCounts(kk,:) = sphereSPDs(kk,:)*detectorP_rel;

            end % nPrimarySteps

            % Sum the counts from this repetition
            sum_detector_counts = sum_detector_counts + detectorCounts;

        end

        % Retrieve the containers holding the results per measure
        measured = measured_map(chip);
        predicted = predicted_map(chip);

        % Append the newest measurement results
        measured{ii} = sum_detector_counts / nReps;
        predicted{ii} = predictedCounts;

        % Resave the containers
        measured_map(chips(cc)) = measured;
        predicted_map(chips(cc)) = predicted;

    end % nReps

end % nCalibrations

% Save the transmittance plot
ylabel('Transmittance'); xlabel('wavelength [nm]');
box off
a = gca();
a.TickDir = 'out';
a.FontSize = 20;
figName = fullfile(figSavePath,'ndfTransmittanceFunctions.pdf');
saveas(figHandle,figName);

% Plot each chip's measured vs predicted counts
for kk = 1:numel(chips)
    % Retrieve the chip whose results we will plot
    chip = chips(kk);

    % Retrieve the number of channels for this chip
    chip_struct = chip_struct_map(chip);
    nDetectorChannels = chip_struct.meta.nDetectorChannels;

    fprintf('Plotting chip: %s\n', chip);

    % Retrieve the limits for this chip's graph 
    limits = lim_map(chip); 

    % Retrieve the filter function used to exclude points
    % from fitting LBF
    goodIdxFilter = goodIdxFilterMap(chip);

    % Retrieve the measured/predicted counts for this chip
    measured = measured_map(chip);
    predicted = predicted_map(chip);

    % Concatenate the measured and predicted matrices across the multiple
    % calibrations
    measured=cat(1,measured{:});
    predicted=cat(1,predicted{:});

    % Loop across the channels and show the predicted vs. measured
    figure
    tg = uitabgroup();
    for cc = 1:nDetectorChannels
        tabSet{cc} = uitab(tg);
        ax1 = axes('Parent', tabSet{cc});

        % Draw a reference line
        plot([limits(1),limits(2)],[limits(1),limits(2)],':k');
        hold on

        % Log transform the measured and predicted counts
        vec = predicted(:,cc);
        x = log10(vec);
        vec = measured(:,cc); vec(vec<0.25) = 0.24;
        y = log10(vec);

        % Fit a linear model, but only to the "good" points (i.e., those
        % that are finite and not at the ceiling or floor. We also exclude
        % the points measured using the ND6 filter, as we do not have an
        % independent measure of the spectral transmittance of these.
        thisIdx = 1:(nMeasToPlot-1)*nSettingsLevels;
        goodIdx = goodIdxFilter(x(thisIdx), y(thisIdx));
        p = polyfit(x(goodIdx),y(goodIdx),1);
        fitY = polyval(p,x(goodIdx));

        % Plot the fit line
        plot(x(goodIdx)+p(2),fitY,'-k','LineWidth',1.5)

        % Now plot the data from each ND filter in a different color
        for mm = 1:nMeasToPlot
            thisIdx = (mm-1)*nSettingsLevels+1:mm*nSettingsLevels;
            scatHand(mm) = scatter(x(thisIdx)+p(2),y(thisIdx),100,'o',...
                'MarkerEdgeColor','none','MarkerFaceColor',plotColors(mm,:),...
                'MarkerFaceAlpha',.2);
        end

        % Clean up
        ylim(limits);
        xlim(limits);
        axis square
        xlabel(sprintf('%s predicted counts [log]', chip));
        ylabel(sprintf('%s measured counts [log]', chip));
        title(sprintf('channel %d, [slope intercept] = %2.2f, %2.2f',cc,p));
        legendLabels = arrayfun(@(x) sprintf('ND%d',x),ndfUsedForEachMeasure,'UniformOutput',false);
        legend(scatHand,legendLabels,'Location','northwest')

        % Save this tab to a file
        figName = fullfile(figSavePath,sprintf(strcat(chip,"_channel-%d_measuredVsPredicted.pdf"),cc));
        exportgraphics(tabSet{cc},figName);

    end

    hold off; 
end

end % function
