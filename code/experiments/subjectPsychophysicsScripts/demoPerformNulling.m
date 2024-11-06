
nn=1;

% Open a CombiLEDcontrol object
CombiLEDObj = CombiLEDcontrol('verbose',false);

% Update the gamma table
CombiLEDObj.setGamma(cal{nn}.processedData.gammaTable);

% This is an asymmetric adjustment of the high settings arm of the
% L–M modulation in an attempt to null any luminance component
sourceModResult = modResult{nn,1};
silencingModResult = modResult{nn,2};
stimFreqHz = 30;
stimContrast = 1.0;
stimWaveform = 1; % 1 = sinusoid, 2 = square wave;
asymmetricAdjustFlag = true;

psychObjNullLum = PsychFlickerNull(CombiLEDObj,sourceModResult,silencingModResult,...
    'stimFreqHz',stimFreqHz,'stimContrast',stimContrast,...
    'stimWaveform',stimWaveform,'asymmetricAdjustFlag',asymmetricAdjustFlag);

while ~strcmp(psychObjNullLum.lastResponse,'done')
    psychObjNullLum.presentTrial
end

% This is a symmetric adjustment of of a light flux modulation
% in an attempt to null any L-M component
sourceModResult = modResult{nn,2};
silencingModResult = modResult{nn,1};
stimFreqHz = 0.5;
stimContrast = 1.0;
stimWaveform = 2; % 1 = sinusoid, 2 = square wave;
asymmetricAdjustFlag = false;

psychObjNullChrom = PsychFlickerNull(CombiLEDObj,sourceModResult,silencingModResult,...
    'stimFreqHz',stimFreqHz,'stimContrast',stimContrast,...
    'stimWaveform',stimWaveform,'asymmetricAdjustFlag',asymmetricAdjustFlag);

while ~strcmp(psychObjNullChrom.lastResponse,'done')
    psychObjNullChrom.presentTrial
end

% Clean up
CombiLEDObj.goDark
CombiLEDObj.serialClose
