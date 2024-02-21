% Shifted background human melanopsin modulation
cal = loadCalByName('CombiLED_shortLLG_classicEyePiece_ND2x5');
observerAgeInYears = 53;
pupilDiameterMm = 3;
photoreceptors = photoreceptorDictionaryHuman('observerAgeInYears',observerAgeInYears,'pupilDiameterMm',pupilDiameterMm);
whichDirection = 'SminusMel';
backgroundPrimary = [
    0.2150
    0
    0
    0.0302
    0.0068
    0.5006
    0.2998
    0.0147];
modResult = designModulation(whichDirection,photoreceptors,cal,'searchBackground',true,'contrastMatchConstraint',-10,'backgroundPrimary',backgroundPrimary);
plotModResult(modResult);

% Open a CombiLEDcontrol object
obj = CombiLEDcontrol('verbose',false);

% Update the gamma table
obj.setGamma(cal.processedData.gammaTable);


psychObj = IncrementDecrementPupil(obj,'test',modResult);


psychObj.stimContrast = 1;
for ii = 1:10
    pause
psychObj.collectTrial
end

psychObj.stimContrast = -1;

for ii = 1:10
    pause
psychObj.collectTrial
end
