% Modulation demo with two combiLEDs

combiLEDObjArray = cell(1, 2);

for ii = 1:length(combiLEDObjArray)

    % Open a CombiLEDcontrol object
    combiLEDObjArray{ii} = CombiLEDcontrol('verbose',false);

    % Identify which combi obj is which
    if combiLEDObjArray{ii}.identifierString == "AG0K94J8"
        disp('Identified combiLED A.')
    elseif combiLEDObjArray{ii}.identifierString == "B000JA8P"
        disp('Identified combiLED B.')
    end

    % Select a calibration file
    cals{ii} = selectCal();

    % Update the gamma table
    combiLEDObjArray{ii}.setGamma(cals{ii}.processedData.gammaTable);
    
end

% Get observer properties
observerAgeInYears = str2double(GetWithDefault('Age in years','30'));
pupilDiameterMm = str2double(GetWithDefault('Pupil diameter in mm','3'));

% Get the photoreceptors for this observer
photoreceptors = photoreceptorDictionaryHuman('observerAgeInYears',observerAgeInYears,'pupilDiameterMm',pupilDiameterMm);

% Modulation demos
modDemos = {...
    'melPulsesShiftedBackground', ...
    'riderStockmanDistortion', ...
    'fastLightFluxFlicker', ...
    'slowSFlicker' ...
    'slowLminusMFlicker' ...
    };

notDone = true;

while notDone
    for ii = 1:length(combiLEDObjArray)
        % Identify the combiLED
        if combiLEDObjArray{ii}.identifierString == "AG0K94J8"
            combiLED = 'A';
        elseif combiLEDObjArray{ii}.identifierString == "B000JA8P"
            combiLED = 'B';
        end

        % Present the options
        charSet = [97:97+25, 65:65+25];
        fprintf('\nSelect a modulation for combiLED %c (return to quit):\n', ...
            combiLED)
        for pp=1:length(modDemos)
            optionName=['\t' char(charSet(pp)) '. ' modDemos{pp} '\n'];
            fprintf(optionName);
        end

        choice{ii} = input('\nYour choice (return for done): ','s');

        if isempty(choice{ii})
            notDone = false;
            break
   
        else
            % Obtain the mod result
            choice{ii} = int32(choice{ii});
            idx{ii} = find(charSet == choice{ii});
            modResult{ii} = feval(modDemos{idx{ii}},combiLEDObjArray{ii},photoreceptors,cals{ii});

            % Plot the modulation
            plotModResult(modResult{ii});

        end
    end
   
    if notDone
        % Pause then present the modulation. Continue until key press
        fprintf('Press any key to start, and then stop, the modulation...')
        pause
        combiLEDObjArray{1}.setFrequency(1);
        combiLEDObjArray{2}.setFrequency(10);
        combiLEDObjArray{1}.startModulation;
        combiLEDObjArray{2}.startModulation;
        fprintf('modulating...')
        pause
        fprintf('done\n')
        combiLEDObjArray{1}.stopModulation;
        combiLEDObjArray{1}.goDark;
        combiLEDObjArray{2}.stopModulation;
        combiLEDObjArray{2}.goDark;
    end
end

% Clean up
combiLEDObjArray{1}.serialClose;
combiLEDObjArray{2}.serialClose;
close all
clear

function modResult = melPulsesShiftedBackground(obj,photoreceptors,cal)
modResult = designModulation('Mel',photoreceptors,cal,'searchBackground',true,'primariesToMaximize',[3,4],'primaryHeadRoom',0.05);
obj.setSettings(modResult);
obj.setUnimodal();
obj.setWaveformIndex(2); % square-wave
obj.setFrequency(0.1);
obj.setPhaseOffset(pi);
obj.setAMIndex(2); % half-cosine windowing
obj.setAMFrequency(0.1);
obj.setAMValues([0.5,0]); % 0.5 second half-cosine on; second value unused
end

function modResult = fastLightFluxFlicker(obj,photoreceptors,cal)
modResult = designModulation('LightFlux',photoreceptors,cal);
obj.setSettings(modResult);
obj.setWaveformIndex(1);
obj.setFrequency(16);
obj.setContrast(1);
obj.setAMIndex(1);
obj.setAMFrequency(0.1);
end

function modResult = riderStockmanDistortion(obj,photoreceptors,cal)
% A compound L-cone modulation described in Rider & Stockman 2018 PNAS
modResult = designModulation('L_foveal',photoreceptors,cal);
obj.setSettings(modResult);
obj.setWaveformIndex(5);
obj.setFrequency(5);
obj.setAMIndex(1);
obj.setAMFrequency(1);
compoundHarmonics=[1,3,4,0,0];
compoundAmplitudes=[0.5,1,1,0,0];
compoundPhases=deg2rad([0,333,226,0,0]); % Should look red
%{
    compoundPhases=deg2rad([0,333,46,0,0]); % Should look green
%}
obj.setCompoundModulation(compoundHarmonics,compoundAmplitudes,compoundPhases);
end

function modResult = slowLminusMFlicker(obj,photoreceptors,cal)
modResult = designModulation('LminusM_wide',photoreceptors,cal);
obj.setSettings(modResult);
obj.setWaveformIndex(1);
obj.setFrequency(2);
obj.setAMIndex(0);
end

function modResult = slowSFlicker(obj,photoreceptors,cal)
modResult = designModulation('S_wide',photoreceptors,cal);
obj.setSettings(modResult);
obj.setWaveformIndex(1);
obj.setFrequency(0.5);
obj.setAMIndex(0);
end