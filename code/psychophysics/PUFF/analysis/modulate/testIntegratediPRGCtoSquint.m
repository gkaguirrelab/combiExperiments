% obtain the fits from the light level data
processLightLevelVideos;
% BLNK_1001 is at index 2.
pSig = p(2,:);
backgroundLL = 4273.2; %cd/m2, from pdf

% extract fourierFits for modulation data
load("/Users/samanthamontoya/Aguirre-Brainard Lab Dropbox/Sam Montoya/BLNK_analysis/PuffLight/modulate/FitData/fourierFitResultsSessions1and2.mat")
[p,fVals] = fitWeightModel(fourierFitResults);
% BLNK_1001 is at index 1.
participantIdx = 1;
pModel = p(participantIdx,:);
backgroundMod = 2225.3; %cd/m2, from Mel pdf

targetDirs = {'Mel', 'LMS', 'S', 'LF'};
ampsVector = zeros(1, 4);

for dd = 1:length(targetDirs)
    dirName = targetDirs{dd};
    % Extract the first participant's amplitude for the "High" frequency
    ampsVector(dd) = fourierFitResults.(dirName).High.amplitude(participantIdx);
end

results = estimateAbsoluteClosure(pModel, pSig, 'sigLuminance', backgroundLL, 'modLuminance', backgroundMod, 'amplitudes', ampsVector);





