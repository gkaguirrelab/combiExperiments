function fit_calibration(obj,MSCalDataFiles)
    
    % For each NDF calibration 
    for ii = 1:numel(MSCalDataFiles)
        % Load each NDF's MSCalFile
        MSCalData = load(MSCalDataFiles{ii}).MSCalData;
        
        % Extract NDF and the source calibration struct
        NDF = MSCalData.meta.params.NDF;
        cal = MSCalData.meta.source_cal;

        % Extract some further information regarding the light source that is being used to
        % calibrate the minispect
        sourceS = cal.rawData.S;
        sourceP_abs = cal.processedData.P_device;
        nSourcePrimaries = cal.describe.displayPrimariesNum;

        % Load the minispect SPDs
        miniSpectSPDPath = fullfile(tbLocateProjectSilent('combiExperiments'),'data','ASM7341_spectralSensitivity.mat');
        load(miniSpectSPDPath,'T');
        minispectS = WlsToS(T.wl);
        minispectP_rel = T{:,2:end};
        %minispectP_rel = minispectP_rel ./ max(minispectP_rel);

        % Reformat that minispect SPDs to be in the space of the sourceSPDs
        detectorP_rel = [];
        for jj = 1:size(minispectP_rel,2)
            detectorP_rel(:,ii) = interp1(SToWls(minispectS),minispectP_rel(:,ii),SToWls(sourceS));
        end

        sphereSPDs = nan(MSCalData.meta.params.nPrimarySteps,sourceS(3));
        predictedCounts = nan(MSCalData.meta.params.nPrimarySteps,10); % this should be nChannels
        measurements = MSCalData.raw.counts;

        % Iterate over the settings 
        for jj = 1:size(MSCalData.raw.settings)
            CL_settings = ones(1,8) * MSCalData.raw.settings(jj);

            % Derive the sphereSPD for this step in units of W/m2/sr/nm. We divide
            % by the nanometer sampling given in S to cast the units as nm, as
            % opposed to (e.g.) per 2 nm.

            %disp(size((sourceP_abs*CL_settings')/sourceS(2)));
                
            sphereSPDs(ii,:) = (sourceP_abs*CL_settings')/sourceS(2);

            % Derive the prediction of the relative counts based upon the sphereSPD
            % and the minispectP_rel.
            predictedCounts(ii,:) = sphereSPDs(ii,:)*detectorP_rel*(1/10^(NDF-0.2));
        
        end

            % THESE SHAPES ARE NOT GOING TO BE EQUAL 
        
        disp(size(measurements(1,:,:,:)));
        disp(size(mean(measurements(1,:,:,:))));
        
        return 
        ratio_matrix = predictedCounts ./ sphereSPDs; 
        
        % Go over all of the individual channels
        for jj = 1:size(measurements,4)

            % Find the mean ratio between the predicted counts and the measurements 
            % (as there is slight variation in the numbers)
            K = mean(ratio_matrix(:,ii));
            
            % Fit the measured values to the predicted values
            fitted = measurements(:,ii)*K; 
        end
    end

   


    % move this to object oriented 
    % pass in cell array of paths to the minispect
    % result of MSCalData files
    % fitting routine loads each of these 
    % also loads spectral sensitivity functions for the minispect 
    % from each of the MSCalData files, extract the sphere (source) calibration file
    % now we have the raw materials to do the fit


    % do 3 reps of calibration and save mat file


end