function analyze_camera_temporal_sensitivty(frequency)
    
    % Step 1: Open a remote connection to the raspiberry pi 
    host = '10.103.10.181'; % IP/Hostname
    username = 'eds'; % Username to log into
    password = '1234'; % Password for this user

    disp('Opening remote connection to RP...')
    ssh2_conn = ssh2_config('10.103.10.181','eds',password); % open the connection
    
    % Step 2: Navigate the PI to the directory where the recording is done 
    recording_dir = '/home/eds/combiExperiments/code/minispect/raspberry_pi_firmware';
    ssh2_conn = ssh2_command(ssh2_conn, sprintf('cd %s', recording_dir)); % navigate to the dir with the recording script
    
    % Step 3: Define parameters for the recording 
    output_filename = 'test.h264';
    duration = 10; 
    
    disp('Begin recording...')
    % Step  : Begin recording to the desired output path for the desired duration
    ssh2_conn = ssh2_command(ssh2_conn, sprintf('python3 Camera_com.py %s %d', output_filename, duration));

    pause(2*duration) % Pause for duration plus a buffer to allow for recording, saving, error checking, etc

    % Step : Retrieve the file from the raspberry pi
    disp('Retrieving the file...')
    ssh2_conn = scp_get(ssh2_conn, output_filename, './raspberry_pi_firmware/recordings/', recording_dir); 

    % Step : Close the remote connection to the raspberry pi
    disp('Closing connection to RP...')
    ssh2_conn = ssh2_close(ssh2_conn);

    return ; 


    
    ssh2_conn = ssh2_command(ssh2_conn, 'ls');

    command_response = ssh2_command_response(ssh2_conn);
    % to access the first response, one can use:
    command_response{1};

    ssh2_conn = ssh2_close(ssh2_conn);

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



%{

I had to use the following dicussion found in the MATLAB library discussion by Quan Chen
to enable the ssh module to work. Note I also had to add the + in front of ssh-rsa to get it 
to work AND have regular password-based SSH work. 

I got the same error as Gernot after I upgrade my server to Ubuntu 20.04.  The dreadful "SSH2 could not connect to the ssh2 host - "ip"".  A quick check of the /var/log/auth.log showed "no matching key exchange method found. Their offer: diffie-hellman-group-exchange-sha1,diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 [preauth]"
The following is my fix:
On the ssh server side, sudo vi /etc/ssh/sshd_config  (you can use your favorite editor)
append the following two lines 
KexAlgorithms diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group14-sha256,diffie-hellman-group14-sha1
HostKeyAlgorithms +ssh-rsa,ssh-dss
Save.  run the command: sudo systemctl restart ssh
Now the ssh from matlab side works.
If you don't have sudo rights on the server you are attempt to connect, there are ways to modify the ~/.ssh/config under your account to get it work.  However, I didn't test that route.


%}