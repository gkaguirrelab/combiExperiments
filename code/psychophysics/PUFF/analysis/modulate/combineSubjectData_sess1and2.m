
clear

% Define the list of subjects. Data from subject BLNK_1010 was excluded
% post-hoc due to constant movement during recordings, which caused more
% than 50% loss of measurements in the majority of trials.
subjects = {'BLNK_1001','BLNK_1002','BLNK_1003','BLNK_1005','BLNK_1006',...
    'BLNK_1007','BLNK_1008','BLNK_1009','BLNK_1011','BLNK_1012'};

% Define the stimulus properties
directions = {'LightFlux','Mel','LMS','S_peripheral'};
directionLabels = {'LF','Mel','LMS','S'};
phaseLabels = {'OnOff','OffOn'};
contrastLabels = {'High','Low'};
phases = [0,pi];
phaseFileNames = {'0.00','3.14'};
contrasts =  {[0.4,0.4,0.4,0.4],[0.2,0.2,0.2,0.2]};
nTrials = 4;

% Define plot properties
directionColors = {[0 0 0],[0 1 1],[1 0.75 0],[0 0 1]};
directionLineColors = {'k','c',[1 0.75 0],'b'};

% Obtain the behavioral performance. We exclude BLINK_1011, as there seems
% to have been some technical error that resulted in zero detected trials.
goodSubs = ~strcmp(subjects,'BLNK_1011');
[nDetectTrials,proportionDetect,trialIdxWithMissedDetections] = ...
    reportModulateBehavPerformance(subjects(goodSubs),directions,contrasts,phases);
nMisses = sum(cell2mat(cellfun(@(x) sum(x),trialIdxWithMissedDetections(:),'UniformOutput',false)));
fprintf('On average, each participant was presented with a total of %2.0f trials across all conditions.\n',sum(nDetectTrials(:),'omitmissing')/sum(goodSubs));
fprintf('Out of the total of %d trials across all subjects, only %d trials were missed.\n',sum(nDetectTrials(:),'omitmissing'),nMisses);

% Get the results from disk
% To check the results for each subject, set makePlotFlag to true, and
% then uncomment the pause and close all steps below
for ss = 1:length(subjects)
    results{ss} = processModulateVideos(subjects{ss},...
        'directions',directions,...
        'directionLabels',directionLabels,...
        'phaseLabels',phaseLabels,...
        'phases',phases,...
        'contrastLabels',contrastLabels,...
        'contrasts',contrasts,...
        'nTrials',nTrials,...
        'directionColors',directionColors,...
        'makePlotFlag',false);
    %{
    pause
    close all
    %}
end


% Get the across-subject average results
avgResults = acrossSubjectAverage(results);

% Report the ipRGC photoreceptor weights for the high-contrast stimulus set


% Plot the across-subject average responses
plotAvgResponses(avgResults,...
    'directionColors',directionColors)

% Get the individual subject fourier fits
fourierFitResults = obtainFourierResults(results);

% Plot a summary of the Fourier fits
plotSummaryPolar(fourierFitResults,...
    'directionColors',directionColors,...
    'directionLineColors',directionLineColors);

% Plot correlated individual variation in photoreceptor responses
plotIndividVariation(fourierFitResults,...
    'dirSets',{directionLabels([4,2]),directionLabels([4,3])},...
    'contrastLabel',contrastLabels{1});

% Get the photoreceptor integration model fits (and create a figure)
[p,fVals] = fitWeightModel(fourierFitResults);

% Save results
dropboxBaseDir = getpref('combiExperiments','dropboxBaseDir');
projectName = 'PuffLight';
experimentName = 'modulate';
saveDir = fullfile(dropboxBaseDir,'BLNK_analysis',projectName,experimentName,'FitData');

save([saveDir, '/fourierFitResultsSessions1and2.mat'], 'fourierFitResults', 'p', 'fVals', 'subjects');


%%%%%%%%%%%%%%%%%%%%%%%%%
%% STATISTICAL SUMMARY %%
%%%%%%%%%%%%%%%%%%%%%%%%%

% 1. Extract group-average amplitudes, phases, and SEMs from avgResults
lf_high_amp   = avgResults.LF.High.amplitude;
lf_high_phase = avgResults.LF.High.phase;
lf_high_sem   = avgResults.LF.High.amplitudeSEM;

lf_low_amp    = avgResults.LF.Low.amplitude;
lf_low_phase  = avgResults.LF.Low.phase;
lf_low_sem    = avgResults.LF.Low.amplitudeSEM;

mel_high_amp   = avgResults.Mel.High.amplitude;
mel_high_phase = avgResults.Mel.High.phase;
mel_high_sem   = avgResults.Mel.High.amplitudeSEM;

mel_low_amp    = avgResults.Mel.Low.amplitude;
mel_low_phase  = avgResults.Mel.Low.phase;
mel_low_sem    = avgResults.Mel.Low.amplitudeSEM;

lms_high_amp   = avgResults.LMS.High.amplitude;
lms_high_phase = avgResults.LMS.High.phase;
lms_high_sem   = avgResults.LMS.High.amplitudeSEM;

lms_low_amp    = avgResults.LMS.Low.amplitude;
lms_low_phase  = avgResults.LMS.Low.phase;
lms_low_sem    = avgResults.LMS.Low.amplitudeSEM;

s_high_amp     = avgResults.S.High.amplitude;
s_high_phase   = avgResults.S.High.phase;
s_high_sem     = avgResults.S.High.amplitudeSEM;

s_low_amp      = avgResults.S.Low.amplitude;
s_low_phase    = avgResults.S.Low.phase;
s_low_sem      = avgResults.S.Low.amplitudeSEM;

% 2. Automatically sign the group bars using the cosine of the group phase
lf_high_signed  = lf_high_amp  * sign(cos(lf_high_phase));
lf_low_signed   = lf_low_amp   * sign(cos(lf_low_phase));
mel_high_signed = mel_high_amp * sign(cos(mel_high_phase));
mel_low_signed  = mel_low_amp  * sign(cos(mel_low_phase));
lms_high_signed = lms_high_amp * sign(cos(lms_high_phase));
lms_low_signed  = lms_low_amp  * sign(cos(lms_low_phase));
s_high_signed   = s_high_amp   * sign(cos(s_high_phase));
s_low_signed    = s_low_amp    * sign(cos(s_low_phase));

% 3. Normalize all signed values to the absolute magnitude of the LF High baseline
baseline_mag    = abs(lf_high_signed);

lf_high_pct     = (lf_high_signed / baseline_mag) * 100;
lf_high_sem_pct = (lf_high_sem / baseline_mag) * 100;

lf_low_pct      = (lf_low_signed / baseline_mag) * 100;
lf_low_sem_pct  = (lf_low_sem / baseline_mag) * 100;

mel_high_pct    = (mel_high_signed / baseline_mag) * 100;
mel_high_sem_pct= (mel_high_sem / baseline_mag) * 100;

mel_low_pct     = (mel_low_signed / baseline_mag) * 100;
mel_low_sem_pct = (mel_low_sem / baseline_mag) * 100;

lms_high_pct    = (lms_high_signed / baseline_mag) * 100;
lms_high_sem_pct= (lms_high_sem / baseline_mag) * 100;

lms_low_pct     = (lms_low_signed / baseline_mag) * 100;
lms_low_sem_pct = (lms_low_sem / baseline_mag) * 100;

s_high_pct      = (s_high_signed / baseline_mag) * 100;
s_high_sem_pct  = (s_high_sem / baseline_mag) * 100;

s_low_pct       = (s_low_signed / baseline_mag) * 100;
s_low_sem_pct   = (s_low_sem / baseline_mag) * 100;

% 4. Convert phases from radians to degrees
lf_high_deg  = rad2deg(lf_high_phase);
lf_low_deg   = rad2deg(lf_low_phase);
mel_high_deg = rad2deg(mel_high_phase);
mel_low_deg  = rad2deg(mel_low_phase);
lms_high_deg = rad2deg(lms_high_phase);
lms_low_deg  = rad2deg(lms_low_phase);
s_high_deg   = rad2deg(s_high_phase);
s_low_deg    = rad2deg(s_low_phase);

% Print out the table
fprintf('\n========================================================================================\n');
fprintf('                EXPERIMENT 2 MODULATION DATA (Normalized to LF High)\n');
fprintf('========================================================================================\n');
fprintf('%-28s | %-22s | %-14s\n', 'Condition / Stimulus', 'Relative Amplitude ± SEM', 'Phase (deg)');
fprintf('----------------------------------------------------------------------------------------\n');
fprintf('%-28s | %6.1f%% ± %5.1f%%        | %6.1f°\n', 'LF High Baseline', lf_high_pct, lf_high_sem_pct, lf_high_deg);
fprintf('%-28s | %6.1f%% ± %5.1f%%        | %6.1f°\n', 'LF Low Contrast', lf_low_pct, lf_low_sem_pct, lf_low_deg);
fprintf('%-28s | %6.1f%% ± %5.1f%%        | %6.1f°\n', 'Mel High Contrast', mel_high_pct, mel_high_sem_pct, mel_high_deg);
fprintf('%-28s | %6.1f%% ± %5.1f%%        | %6.1f°\n', 'Mel Low Contrast', mel_low_pct, mel_low_sem_pct, mel_low_deg);
fprintf('%-28s | %6.1f%% ± %5.1f%%        | %6.1f°\n', 'LMS High Contrast', lms_high_pct, lms_high_sem_pct, lms_high_deg);
fprintf('%-28s | %6.1f%% ± %5.1f%%        | %6.1f°\n', 'LMS Low Contrast', lms_low_pct, lms_low_sem_pct, lms_low_deg);
fprintf('%-28s | %6.1f%% ± %5.1f%%        | %6.1f°\n', 'S High Contrast', s_high_pct, s_high_sem_pct, s_high_deg);
fprintf('%-28s | %6.1f%% ± %5.1f%%        | %6.1f°\n', 'S Low Contrast', s_low_pct, s_low_sem_pct, s_low_deg);
fprintf('========================================================================================\n\n');