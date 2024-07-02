function fit_calibration_nonObjTest(MSCalDataFiles)

% Example call
%{
MSCalDataFiles = {...
'calibration4.mat',...
'calibration3.mat',...
'calibration2.mat',...
'calibration1.mat',...
'calibration0x2.mat'};

fit_calibration_nonObjTest(MSCalDataFiles)
%}


referenceNDF = 0.2;
% We need to add to the calibration code the ability to specify a
% "background" for the source device. Currently, our code implicitly
% assumes a column background of [1;1;1;1;1;1;1;1]. We might use other
% backgrounds in the future (e.g., to simulate the SPD of daylight). We
% The particular source device settings that we use are obtained by
% multiplying the setting value [0.05 --> 0.95] by the background.
% The background will be the same across reps, so it can be stored as a
% vector in:
% MSCalData.raw.background

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

    %% KLUDGE TO CONVERT THE PILOT MSCALDATAFILES into cell arrays
    %% DELETE ME AS SOON AS YOU CAN
    c1 = squeeze(MSCalData.raw.counts(1,:,:,:));
    c2 = squeeze(MSCalData.raw.counts(2,:,:,:));
    c3 = squeeze(MSCalData.raw.counts(3,:,:,:));
    MSCalData.raw.counts = {c1,c2,c3};

    % Extract NDF and the source calibration struct
    %% This is a kludge to be replace by creating a different
    %% source cal for each NDF filter level.
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
    %% RENAME THE FIELD to nREPS
    nReps = MSCalData.meta.params.reps;
    randomizeOrder = MSCalData.meta.params.randomizeOrder;

    %% MIGHT WANT TO CHANGE THE MS SPECT CALIBRATION CODE TO NAME THIS
    %% FIELD nDetectorChannels
    nDetectorChannels = MSCalData.meta.nChannels;

    % Iterate over repetitions
    %% CHANGE THE MSCALDATA FILE TO SAVE REPS AS ELEMENTS IN A CELL ARRAY
    for jj = 1:nReps

        % Grab the minispect counts from this rep
        detectorCounts = MSCalData.raw.counts{jj};

        % Take the mean across the nSamplesPerStep made at each
        % setting. We may later be interested in the variability across
        % the set of measures
        detectorCounts = squeeze(mean(detectorCounts,1));

        % Get the sorted setting values for this rep
        %% NEED TO MAKE THAT A CELL EXTRACTION ONCE THE CAL FILES ARE UPDATED

        %% Also, we should save the sorted settings
        settings_sorted = sort(MSCalData.raw.settings(jj,:));

        % Get the background (right now we assume unity vector)
        background = ones(1,8);

        % Initialize some variables to hold loop results
        sphereSPDs = nan(nPrimarySteps,sourceS(3));
        predictedCounts = nan(nPrimarySteps,nDetectorChannels);

        % Iterate over the source primary setting values
        for kk = 1:nPrimarySteps

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
