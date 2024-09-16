function fit_minispect_counts(MSCalDataFiles, calFiles)
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

    lightSourceCalDir = '~/Documents/MATLAB/projects/combiExperiments/cal'
    d_l = dir(fullfile(calDir,'*maxSpectrum*'));
    MSCalDataFiles = cellfun(@(x) fullfile(calDir, x), {d.name}, 'UniformOutput', false);

    fit_minispect_counts(MSCalDataFiles);
%}

% Parse the arguments
parser = inputParser; 

% Validate the arguments' type and size > 0 
parser.addRequired('MSCalDataFiles', @(x) iscell(x) && numel(x) ~= 0);
parser.addRequired('calFiles', @(x) iscell(x) && numel(x) ~= 0); 

% Parse the arguments
parser.parse(MSCalDataFiles, calFiles); 

% Retrieve the validated arguments
MSCalDataFiles = parser.Results.MSCalDataFiles;  
calFiles = parser.Results.calFiles;  

% Assert there is a source cal file for every MSCalDataFile
assert(numel(MSCalDataFiles) == numel(calFiles))

% This is a kludge. Eventually we will pass in a set of cal files
% corresponding to the CombiLEDSphere calibrations at each NDF level.
%referenceNDF = 0.2;

% Load the first MSCalDataFile, get the S, as we need this to resample the
% detector spectral sensitivity functions
MSCalData = load(MSCalDataFiles{1}).MSCalData;

sourceS = MSCalData.meta.source_cal.rawData.S;
clear MSCalData

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

% For each MSCalDataFile calibration
for ii = 1:numel(MSCalDataFiles)
    % Load this MSCalFile
    MSCalData = load(MSCalDataFiles{ii}).MSCalData;

    % Load its associated NDF calibration
    cals = load(calFiles{ii}, 'cals');
    cal = cals{end};

    chip_struct_map = containers.Map({'AMS7341','TSL2591'},...
        {MSCalData.ASChip,MSCalData.TSChip});

    % Extract NDF and the source calibration struct
    NDF = MSCalData.meta.params.NDF;
    source_cal = MSCalData.meta.source_cal;

    % Check that the sourceS associated with the current MSCalDataFile
    % matches that we extracted at the top of the routine
    assert(all(source_cal.rawData.S == sourceS));

    % Extract information regarding the light source that was used to
    % calibrate the minispect
    sourceP_abs = source_cal.processedData.P_device;

    % Extract some params from the MSCalData.meta.params
    nPrimarySteps = MSCalData.meta.params.nPrimarySteps;
    nSamplesPerStep = MSCalData.meta.params.nSamplesPerStep;
    nReps = MSCalData.meta.params.nReps;
    randomizeOrder = MSCalData.meta.params.randomizeOrder;

    % Iterate over repetitions
    for jj = 1:nReps
        % For each chip on this repetition
        for cc = 1:numel(chips)

            % Find the corresponding MSCalData info
            % and detectorP_rel for this chip
            chip_struct = chip_struct_map(chips(cc));
            detectorP_rel = minipspectP_rels_map(chips(cc));

            % Grab the channels of the chip we are fitting
            nDetectorChannels = chip_struct.meta.nDetectorChannels;

            % Grab the minispect counts from this rep
            detectorCounts = chip_struct.raw.counts{jj};

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
                sphereSPDs(kk,:) = (sourceP_abs*source_settings')/sourceS(2);

                % Derive the prediction of the relative counts based upon the sphereSPD
                % and the minispectP_rel.
                predictedCounts(kk,:) = sphereSPDs(kk,:)*detectorP_rel;

                %% KLUDGE HERE TO HANDLE THE NDF EFFECT UNTIL WE START PRODUCING
                %% separate sphere calibration files for each NDF level
                predictedCounts(kk,:) = predictedCounts(kk,:) % What operation do we do here with cals again?*   %(1/10^(NDF-referenceNDF));

            end % nPrimarySteps

            % For now, let's just save the data from the first rep
            if jj > 1
                continue ; 
            end

            measured = measured_map(chips(cc));
            predicted = predicted_map(chips(cc));

            measured{ii} = detectorCounts;

            predicted{ii} = predictedCounts;

            disp(measured{1})

            measured_map(chips(cc)) = measured;
            predicted_map(chips(cc)) = predicted;
        end

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
        goodIdx = and(~isinf(y),~isinf(x));
        x = x(goodIdx); y = y(goodIdx);
        plot(x,y,'o');
        hold on
        p = polyfit(x,y,1);
        fitY = polyval(p,x);
        plot(x,fitY,'-k')
        refline(1,0)
        ylim([-2 5]); xlim([-2 5]);
        axis square
        xlabel(sprintf('%s predicted counts [log]', chips(kk)));
        ylabel(sprintf('%s measured counts [log]', chips(kk)));
        title(sprintf('channel %d, [slope intercept] = %2.2f, %2.2f',cc,p));
    end
end

end % function
