function fit_calibration(MSCalDataFiles)
% Fits measured counts from the minispect to predicted counts
%
% Syntax:
%   fit_calibration(MSCalDataFiles)
%
% Description:
%   Given a cell array of paths to MSCalData files 
%   over different NDF levels, load them in 
%   and fit the measured counts to predicted 
%   counts in those conditions. Graphs the results. 
%
% Inputs:
%   MSCalDataFiles        - Cell Array. Array of paths to MSCalData files
%
% Outputs:
%   NONE                  
%
% Examples:
%{
    MSCalDataFiles = {'./calibration1.mat','./calibration2.mat'};
    fit_calibration(MSCalDataFiles);
%}

% Example call
%{
MSCalDataFiles = {...
'calibration4.mat',...
'calibration3.mat',...
'calibration2.mat',...
'calibration1.mat',...
'calibration0x2.mat'};

fit_calibration(MSCalDataFiles)
%}


referenceNDF = 0.2;

% Load the first MSCalDataFile, get the S, as we need this to resample the
% detector spectral sensitivity functions
MSCalData = load(MSCalDataFiles{1}).MSCalData;
sourceS = MSCalData.meta.source_cal.rawData.S;
clear MSCalData

% Load the minispect SPDs
miniSpectSPDPath = fullfile(tbLocateProjectSilent('combiExperiments'),'data','ASM7341_spectralSensitivity.mat');
load(miniSpectSPDPath,'T');
minispectS = WlsToS(T.wl);
minispectP_rel = T{:,2:end};

% Reformat that minispect SPDs to be in the space of the sourceSPDs
detectorP_rel = [];
for ii = 1:size(minispectP_rel,2)
    detectorP_rel(:,ii) = interp1(SToWls(minispectS),minispectP_rel(:,ii),SToWls(sourceS));
end

% For each MSCalDataFile calibration
for ii = 1:numel(MSCalDataFiles)

    % Load this MSCalFile
    MSCalData = load(MSCalDataFiles{ii}).MSCalData;

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
    nDetectorChannels = MSCalData.meta.nDetectorChannels;

    % Iterate over repetitions
    for jj = 1:nReps

        % Grab the minispect counts from this rep
        detectorCounts = MSCalData.raw.counts{jj};

        % Take the mean across the nSamplesPerStep made at each
        % setting. We may later be interested in the variability across
        % the set of measures
        detectorCounts = squeeze(mean(detectorCounts,1));

        % Get the sorted setting values for this rep
        settings_sorted = sort(MSCalData.raw.settings_scalars{jj});

        % Get the background
        background = MSCalData.raw.background;

        % Initialize some variables to hold loop results
        sphereSPDs = nan(nPrimarySteps,sourceS(3));
        predictedCounts = nan(nPrimarySteps,nDetectorChannels);

        % Iterate over the source primary setting values
        for kk = 1:nPrimarySteps
            
            % Get the source settings by multiplying background 
            % by the scalar value at primaryStep kk
            source_settings = background * settings_sorted(kk);

            % Derive the sphereSPD for this step in units of W/m2/sr/nm. We divide
            % by the nanometer sampling given in S to cast the units as nm, as
            % opposed to (e.g.) per 2 nm.
            sphereSPDs(kk,:) = (sourceP_abs*source_settings')/sourceS(2);

            % Derive the prediction of the relative counts based upon the sphereSPD
            % and the minispectP_rel.
            predictedCounts(kk,:) = sphereSPDs(kk,:)*detectorP_rel;

            %% KLUDGE HERE TO HANDLE THE NDF EFFECT UNTIL WE START PRODUCING
            %% separate sphere calibration files for each NDF level
            predictedCounts(kk,:) = predictedCounts(kk,:) * (1/10^(NDF-referenceNDF));

        end % nPrimarySteps

        % For now, let's just save the data from the first rep
        if jj == 1
            measured{ii} = detectorCounts;
            predicted{ii} = predictedCounts;
        end

    end % nReps

end % nCalibrations

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
    xlabel('predicted counts [log]')
    ylabel('measured counts [log]')
    title(sprintf('channel %d, [slope intercept] = %2.2f, %2.2f',cc,p));
end

end % function
