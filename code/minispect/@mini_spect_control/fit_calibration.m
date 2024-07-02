function fit_calibration(obj,MSCalDataFiles)
    figure; 
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
        predictedCounts = nan(MSCalData.meta.params.nPrimarySteps,MSCalData.meta.nChannels); % this should be nChannels
        measuredCounts = MSCalData.raw.counts;

        % Iterate over the settings 
        for jj = 1:size(MSCalData.raw.settings,2)
            CL_settings = ones(1,8) * MSCalData.raw.settings(jj);

            % Derive the sphereSPD for this step in units of W/m2/sr/nm. We divide
            % by the nanometer sampling given in S to cast the units as nm, as
            % opposed to (e.g.) per 2 nm.

            %disp(size((sourceP_abs*CL_settings')/sourceS(2)));
                
            sphereSPDs(jj,:) = (sourceP_abs*CL_settings')/sourceS(2);

            % Derive the prediction of the relative counts based upon the sphereSPD
            % and the minispectP_rel.
            predictedCounts(jj,:) = sphereSPDs(jj,:)*detectorP_rel*(1/10^(NDF-0.2));
        end
        
                                        % just use avg of all samples per channels for 1st rep for now 
        values = squeeze(mean(measuredCounts,2));
        values = squeeze(mean(values,1));
        


        return 
        ratio_matrix = predictedCounts ./ values; 

        % Go over all of the individual channels    % change to nChannels here
        for jj = 1:MSCalData.meta.nChannels
            % Find the mean ratio between the predicted counts and the measurements 
            % (as there is slight variation in the numbers)
            K = mean(ratio_matrix(:,ii));

            % Fit the measured values to the predicted values
            fitted = values(:,ii)*K; 

            % Plot the fitted against the measured
            loglog(fitted,values(:,ii))
            hold on; 
        
        end
    end
    axis equal; 
        
    legend();
    xlabel('Fitted');
    ylabel('Measured');
    title('Ratio of Channel Measurements by Predictions');
    
    xlim([0, 2^16]);

    % Get current axes handle
    ax = gca;

    % Change the background color of the axes
    ax.Color = [0.9, 0.9, 0.9];  % Light blue background

    hold off; 
   


    % move this to object oriented 
    % pass in cell array of paths to the minispect
    % result of MSCalData files
    % fitting routine loads each of these 
    % also loads spectral sensitivity functions for the minispect 
    % from each of the MSCalData files, extract the sphere (source) calibration file
    % now we have the raw materials to do the fit


    % do 3 reps of calibration and save mat file


end