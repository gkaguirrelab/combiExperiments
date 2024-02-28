% Shifted background human melanopsin modulation that maximizes the
% modulation of primaries that are close to 481 nm.
cal = loadCalByName('CombiLED_shortLLG_classicEyePiece_ND2x5');
observerAgeInYears = 53;
pupilDiameterMm = 3;
photoreceptors = photoreceptorDictionaryHuman('observerAgeInYears',observerAgeInYears,'pupilDiameterMm',pupilDiameterMm);
modResultMel = designModulation('Mel',photoreceptors,cal,'searchBackground',true,'primariesToMaximize',[3,4],'primaryHeadRoom',0.05);
plotModResult(modResultMel);

% A wide field S-cone directed modulation that silences Mel
modResultS = designModulation('SnoMel',photoreceptors,cal,'searchBackground',true,'primariesToMaximize',[1,2],'contrastMatchConstraint',0,'primaryHeadRoom',0.05);
plotModResult(modResultS);

% Open a CombiLEDcontrol object
combiObj = CombiLEDcontrol('verbose',false);

% Update the gamma table
combiObj.setGamma(cal.processedData.gammaTable);

% Create a psychObject for the melanopsin measurement for S directed and
% collect some trials
psychObj = IncrementPupil(combiObj,'HERO_gka1',modResultS);
save(fullfile(psychObj.dataOutDir,'modResult.mat'),'modResultS');
for ii = 1:15
    pause
    psychObj.collectTrial
    save(fullfile(psychObj.dataOutDir,'psychObj.mat'),'psychObj');
end
delete(psychObj)

% Create a psychObject for the melanopsin measurement for Mel directed and
% collect some trials
psychObj = IncrementPupil(combiObj,'HERO_gka1',modResultMel);
save(fullfile(psychObj.dataOutDir,'modResult.mat'),'modResultMel');
for ii = 1:15
    pause
    psychObj.collectTrial
    save(fullfile(psychObj.dataOutDir,'psychObj.mat'),'psychObj');
end
delete(psychObj)

