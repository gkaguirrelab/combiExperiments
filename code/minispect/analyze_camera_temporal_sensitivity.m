function analyze_camera_temporal_sensitivty(frequency)
    
    % Step 1: Open a remote connection to the raspiberry pi 
    %host = 'eds@10.103.10.181'; % 'eds@zk' might also need to try this if the previous does not work 
    password = '1234';

    ssh2_conn = ssh2_config('10.103.10.181', 'eds' ,password);
    ssh2_conn = ssh2_command(ssh2_conn, 'ls');


    return ;

    
    % Step 1: Load in the calibration file for the CombiLED
    calDir = fullfile(tbLocateProjectSilent('combiExperiments'),'cal'); % Which Cal file to use (currently hard-coded)
    calFileName = 'CombiLED_shortLLG_testSphere_ND0x2.mat';

    cal_path = fullfile(calDir,calFileName);

    load(cal_path,'cals'); % Load the cal file
    cal = cals{end};
    
    % Step 2: Initialize the combiLED
    CL = CombiLEDcontrol(); % Initialize CombiLED Object
    CL.setGamma(cal.processedData.gammaTable);  % Update the combiLED's gamma table

    % Step 3: Collect information to compose flicker profile
    observerAgeInYears = str2double(GetWithDefault('Age in years','30'));
    pupilDiameterMm = str2double(GetWithDefault('Pupil diameter in mm','3'));
    photoreceptors = photoreceptorDictionaryHuman('observerAgeInYears',observerAgeInYears,'pupilDiameterMm',pupilDiameterMm);

    % Step 4: Compose flicker profile
    modResult = designModulation('LightFlux',photoreceptors,cal);
    CL.setSettings(modResult);
    CL.setWaveformIndex(1);
    CL.setContrast(0.8);
    CL.setFrequency(frequency);

    % Step 5: Start flickering 
    CL.startModulation();

    % Step 6: Have camera record for ~ 10 seconds 
    % (5 second buffer to start the camera)
    pause(15)

    % Step 7: Stop the flicker 
    CL.stopModulation(); 

    % Step 8: Close the connection to the CombiLED
    CL.serialClose(); 

    % Step 9: Save the flicker information
    drop_box_dir = [getpref('combiExperiments','dropboxBaseDir'), '/FLIC_admin/Equipment/SpectacleCamera/calibration/graphs/'];
    save(sprintf('%s%s_TemporalSensitivityFlicker.mat', drop_box_dir, 'camera'), 'modResult');



end