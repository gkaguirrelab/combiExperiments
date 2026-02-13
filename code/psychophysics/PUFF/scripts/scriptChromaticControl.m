function scriptChromaticControl(subjectID)
% Script to run a chromatic control squint modulate session.
% Each session presents 16 trials, following a 2 minute adaptation period.
% There are four unique stimulus conditions: S-cone directed, L-M directed,
% (each at a near-maximum contrast) in forward and reverse phases.

runPuffLightModulate(subjectID,...
    'directions',{'S_peripheral','LminusM_MelSilent_peripheral'},...
    'photoreceptorContrasts',{[0.7,0.1]},...
    'nTrialsPerObj',4);
