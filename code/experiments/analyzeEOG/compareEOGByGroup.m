%% compareEOGByGroup.m
%
% Compare EOG measures between Control and Migraine participants.
%
% CALIBRATION:
%   1. Model-derived EOG amplitude / degree
%   2. Detected calibration saccade amplitude
%
% DCPT-SDT TRIAL DATA:
%   1. Pooled comparison within Low vs High light
%   2. Separate group comparison for every experimental condition
%   3. Single-trial diagnostic plot showing detected saccades
%
% Trial EOG amplitudes are converted to degrees using the participant's
% calibration factor from the calibration session closest in time to that
% trial.
%
% Small dots    = individual participants
% Large diamond = group mean
% Error bars    = +/- SEM
%
% Controls: FLIC_0XXX
% Migraine: FLIC_1XXX

clear; close all; clc

tbUseProject('combiExperiments')


%% ================================================================
%  CHOOSE WHAT TO RUN
%  ================================================================

% Options:
%   "calibration"
%   "trial"
%   "both"

analysisMode = "both";

% Make the overall Low vs High pooled trial plot
plotPooledTrialData = true;

% Make plots separated by:
% light level x contrast x frequency x hi/low
plotTrialConditions = true;

% Make a single-trial diagnostic plot
plotSingleTrialExample = true;


%% ================================================================
%  SINGLE-TRIAL EXAMPLE TO INSPECT
%  ================================================================
%
% Change these values to inspect a suspicious trial.
%
% The script finds the matching source file automatically.

example.subjectID = "FLIC_0018";
example.lightCondition = "High light";
example.testPhotoContrast = 0.1;
example.refFreqHz = 10;
example.stimParamSide = "hi";
example.trialNumber = 1;


%% ================================================================
%  SETUP
%  ================================================================

dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');

dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';

baseDir = fullfile( ...
    dropBoxBaseDir, ...
    dropBoxSubDir, ...
    projectName);

EOGCalibrationDir = 'EOGCalibration';

nSessions = 4;

sessionLabels = { ...
    'Session 1', ...
    'Session 2', ...
    'Session 3', ...
    'Session 4'};


%% Trial light conditions
%
% NOTE:
% These are the overall LIGHT LEVELS.
%
% They are different from the "_hi" and "_low" labels at the end of the
% individual DCPT_SDT filenames.

lightFolders = { ...
    'LightFlux_ND3x0_shifted', ...
    'LightFlux_ND0x5_shifted'};

lightLabels = { ...
    'Low light', ...
    'High light'};

nLightLevels = length(lightFolders);

experimentName = 'DCPT_SDT';


%% Calibration target geometry

degreesOfSaccade = 27.5 / 2;     % 13.75 degrees


%% Calibration model settings

fc = 0.12;

reactionTimeList = 0.20:0.05:0.80;

% Calibration-session QC:
% If fewer than this many saccades are detected in a calibration session,
% that entire calibration session is excluded from the analysis. Because
% the result matrices are preallocated with NaNs, all calibration-derived
% values for that participant/session remain NaN.
minCalibrationSaccades = 3;


%% Trial saccade detector settings
%
% These are the liberal parameters previously used for DCPT-SDT data.

trialParams = struct;

trialParams.velocityThresholdFactor = 5;
trialParams.onsetThresholdFactor = 2;
trialParams.minAmplitude = 0.3;
trialParams.minSaccadeSeparationSec = 0.12;
trialParams.smoothWindowSec = 0.015;
trialParams.minDurationSec = 0.010;
trialParams.maxDurationSec = 0.150;
trialParams.quietWindowSec = 0.015;


%% ================================================================
%  GET CALIBRATION AUDIO COMMAND TIMES
%  ================================================================

audioFile = 'EOGCalInstructions.mp3';

if ~exist(audioFile, 'file')
    error('Could not find %s.', audioFile)
end

[onsets, offsets] = extractCommandOnsets(audioFile);

% center -> left -> center -> right
% repeated three times

cmdValues = repmat([0 -1 0 1], 1, 3);


%% ================================================================
%  FIND ALL PARTICIPANTS
%  ================================================================

folderInfo = dir(fullfile(baseDir, 'FLIC_*'));

folderInfo = folderInfo([folderInfo.isdir]);

subjectID = string({folderInfo.name})';

isControl = startsWith(subjectID, "FLIC_0");
isMigraine = startsWith(subjectID, "FLIC_1");

subjectID = subjectID(isControl | isMigraine);

nSubj = length(subjectID);

fprintf('\nFound %d participants.\n', nSubj)

fprintf('Controls: %d\n', ...
    sum(startsWith(subjectID, "FLIC_0")))

fprintf('Migraine: %d\n\n', ...
    sum(startsWith(subjectID, "FLIC_1")))


%% ================================================================
%  PREALLOCATE CALIBRATION RESULTS
%  ================================================================

betaMatrix = nan(nSubj, nSessions);

eogPerDegMatrix = nan(nSubj, nSessions);

RMSEMatrix = nan(nSubj, nSessions);

reactionTimeMatrix = nan(nSubj, nSessions);

rawEOGAmplitude = nan(nSubj, nSessions);

% Recording time of each calibration
calibrationStartTime = NaT(nSubj, nSessions);


%% ================================================================
%  PROCESS CALIBRATION DATA
%
%  This runs even in "trial" mode because the trial data need these
%  calibration factors to convert EOG amplitude into degrees.
%  ================================================================

fprintf('\n----- PROCESSING EOG CALIBRATIONS -----\n\n')

for subjIdx = 1:nSubj

    thisSubj = subjectID(subjIdx);

    fprintf('%s\n', thisSubj)

    for sessionIdx = 1:nSessions

        fileName = fullfile( ...
            baseDir, ...
            thisSubj, ...
            EOGCalibrationDir, ...
            sprintf('EOGSession%dCal.mat', sessionIdx));


        %% Missing calibration

        if ~exist(fileName, 'file')

            fprintf('  Session %d: MISSING\n', sessionIdx)

            continue

        end


        %% Load calibration

        S = load(fileName, 'sessionData');

        sessionData = S.sessionData;

        EOGSignal = sessionData.EOGData.response(1,:);

        timebase = sessionData.EOGData.timebase;


        %% Save calibration recording time

        if isfield(sessionData.EOGData, 'startTime')

            calibrationStartTime(subjIdx, sessionIdx) = ...
                sessionData.EOGData.startTime;

        elseif isfield(sessionData, 'startTime')

            calibrationStartTime(subjIdx, sessionIdx) = ...
                sessionData.startTime;

        end


        %% --------------------------------------------------------
        %  DETECTED SACCADE AMPLITUDE FROM CALIBRATION
        %  --------------------------------------------------------

        [events, ~] = detectEOGSaccades( ...
            timebase, ...
            EOGSignal, ...
            struct);

        % ---------------------------------------------------------
        % Calibration-session QC
        %
        % Require at least 3 detected saccades. If fewer than 3 are
        % detected, exclude the ENTIRE calibration session.
        %
        % betaMatrix, eogPerDegMatrix, RMSEMatrix,
        % reactionTimeMatrix, and rawEOGAmplitude were all
        % preallocated as NaN, so using "continue" here leaves this
        % participant/session as NaN throughout the analysis.
        %
        % This also prevents trial data from being converted using
        % this calibration session, because findClosestCalibrationSession
        % only considers sessions with a non-NaN calibration factor.
        % ---------------------------------------------------------

        if length(events) < minCalibrationSaccades

            fprintf(['  Session %d: only %d calibration saccades ' ...
                'detected -- EXCLUDED (set to NaN)\n'], ...
                sessionIdx, ...
                length(events));

            continue

        end

        rawEOGAmplitude(subjIdx, sessionIdx) = ...
            mean(abs([events.amplitude]), 'omitnan');


        %% --------------------------------------------------------
        %  MODEL-DERIVED CALIBRATION FACTOR
        %  --------------------------------------------------------

        EOGSignal = EOGSignal(:);
        timebase = timebase(:);

        bestRMSE = inf;
        bestBeta = nan;
        bestReactionTime = nan;


        for rtIdx = 1:length(reactionTimeList)

            reactionTime = reactionTimeList(rtIdx);


            % Expected EOG model

            [~, modelSignal] = generateEOGModel( ...
                timebase, ...
                onsets, ...
                cmdValues, ...
                reactionTime, ...
                fc);

            modelSignal = modelSignal(:);


            % Calibration period

            tStart = onsets(1) + reactionTime;
            tEnd = offsets(end) + reactionTime;

            validIdx = ...
                timebase >= tStart & ...
                timebase <= tEnd;

            if ~any(validIdx)
                continue
            end


            thisEOG = EOGSignal(validIdx);
            thisModel = modelSignal(validIdx);


            %% Fit scale factor

            beta = thisModel \ thisEOG;

            fittedModel = beta * thisModel;

            RMSE = sqrt(mean( ...
                (thisEOG - fittedModel).^2, ...
                'omitnan'));


            %% Keep best fit

            if RMSE < bestRMSE

                bestRMSE = RMSE;
                bestBeta = beta;
                bestReactionTime = reactionTime;

            end

        end


        %% Store results

        betaMatrix(subjIdx, sessionIdx) = bestBeta;

        eogPerDegMatrix(subjIdx, sessionIdx) = ...
            abs(bestBeta) / degreesOfSaccade;

        RMSEMatrix(subjIdx, sessionIdx) = ...
            bestRMSE;

        reactionTimeMatrix(subjIdx, sessionIdx) = ...
            bestReactionTime;


        fprintf(['  Session %d: EOG/deg = %.4f, ' ...
            'RT = %.2f s, RMSE = %.4f\n'], ...
            sessionIdx, ...
            eogPerDegMatrix(subjIdx,sessionIdx), ...
            bestReactionTime, ...
            bestRMSE)

    end

end


%% ================================================================
%  DEFINE GROUPS
%  ================================================================

controlIdx = startsWith(subjectID, "FLIC_0");

migraineIdx = startsWith(subjectID, "FLIC_1");

group = strings(nSubj,1);

group(controlIdx) = "Control";

group(migraineIdx) = "Migraine";


%% ================================================================
%  SAVE CALIBRATION FACTORS
%  ================================================================

calibrationFactorTable = table;

for subjIdx = 1:nSubj

    for sessionIdx = 1:nSessions

        newRow = table( ...
            subjectID(subjIdx), ...
            group(subjIdx), ...
            sessionIdx, ...
            calibrationStartTime(subjIdx,sessionIdx), ...
            eogPerDegMatrix(subjIdx,sessionIdx), ...
            rawEOGAmplitude(subjIdx,sessionIdx), ...
            RMSEMatrix(subjIdx,sessionIdx), ...
            reactionTimeMatrix(subjIdx,sessionIdx), ...
            'VariableNames', { ...
            'SubjectID', ...
            'Group', ...
            'Session', ...
            'CalibrationStartTime', ...
            'EOGPerDegree', ...
            'MeanDetectedCalibrationAmplitude', ...
            'RMSE', ...
            'ReactionTime'});

        calibrationFactorTable = ...
            [calibrationFactorTable; newRow];

    end

end

writetable( ...
    calibrationFactorTable, ...
    'EOGCalibrationFactorsByParticipantSession.csv');

save( ...
    'EOGCalibrationFactorsByParticipantSession.mat', ...
    'calibrationFactorTable', ...
    'eogPerDegMatrix', ...
    'calibrationStartTime', ...
    'RMSEMatrix', ...
    'reactionTimeMatrix');


%% ================================================================
%  CALIBRATION PLOTS
%  ================================================================

if analysisMode == "calibration" || analysisMode == "both"

    % Model-derived calibration gain

    plotGroupComparison( ...
        eogPerDegMatrix, ...
        controlIdx, ...
        migraineIdx, ...
        sessionLabels, ...
        'EOG amplitude / degree', ...
        'EOG Calibration Response by Group');


    % Detected calibration saccade amplitude

    plotGroupComparison( ...
        rawEOGAmplitude, ...
        controlIdx, ...
        migraineIdx, ...
        sessionLabels, ...
        'Mean absolute EOG saccade amplitude', ...
        'Detected Calibration EOG Saccade Amplitude by Group');

end


%% ================================================================
%  CALIBRATION GROUP SUMMARY
%  ================================================================

calibrationSummaryTable = table;

for sessionIdx = 1:nSessions

    controlData = ...
        eogPerDegMatrix(controlIdx, sessionIdx);

    migraineData = ...
        eogPerDegMatrix(migraineIdx, sessionIdx);

    controlData = ...
        controlData(~isnan(controlData));

    migraineData = ...
        migraineData(~isnan(migraineData));

    nControl = length(controlData);
    nMigraine = length(migraineData);

    controlMean = mean(controlData);
    migraineMean = mean(migraineData);

    controlSEM = ...
        std(controlData) / sqrt(nControl);

    migraineSEM = ...
        std(migraineData) / sqrt(nMigraine);

    pValue = nan;

    if nControl >= 2 && nMigraine >= 2

        [~, pValue] = ttest2( ...
            controlData, ...
            migraineData, ...
            'Vartype','unequal');

    end

    newRow = table( ...
        sessionIdx, ...
        nControl, ...
        controlMean, ...
        controlSEM, ...
        nMigraine, ...
        migraineMean, ...
        migraineSEM, ...
        pValue, ...
        'VariableNames', { ...
        'Session', ...
        'NControl', ...
        'ControlMean', ...
        'ControlSEM', ...
        'NMigraine', ...
        'MigraineMean', ...
        'MigraineSEM', ...
        'pValue'});

    calibrationSummaryTable = ...
        [calibrationSummaryTable; newRow];

end

disp(' ')
disp('CALIBRATION GROUP SUMMARY')
disp(calibrationSummaryTable)


%% ================================================================
%  TRIAL DATA
%  ================================================================

if analysisMode == "trial" || analysisMode == "both"

    fprintf('\n')
    fprintf('----- PROCESSING DCPT_SDT TRIAL DATA -----\n\n')


    %% Participant-level pooled light results

    trialSaccadeDegrees = nan( ...
        nSubj, ...
        nLightLevels);


    %% Full trial-level results

    trialResultsTable = table;


    %% ------------------------------------------------------------
    %  LOOP OVER PARTICIPANTS
    %  ------------------------------------------------------------

    for subjIdx = 1:nSubj

        thisSubj = subjectID(subjIdx);

        fprintf('%s\n', thisSubj)


        %% --------------------------------------------------------
        %  LOOP OVER LIGHT LEVELS
        %  --------------------------------------------------------

        for lightIdx = 1:nLightLevels

            dataDir = fullfile( ...
                baseDir, ...
                thisSubj, ...
                lightFolders{lightIdx}, ...
                experimentName);


            if ~exist(dataDir, 'dir')

                fprintf('  %s: folder missing\n', ...
                    lightLabels{lightIdx});

                continue

            end


            %% Find every DCPT-SDT file

            trialFiles = dir(fullfile( ...
                dataDir, ...
                '*.mat'));


            if isempty(trialFiles)

                fprintf('  %s: no MAT files\n', ...
                    lightLabels{lightIdx});

                continue

            end


            participantTrialMeans = [];


            %% ----------------------------------------------------
            %  LOOP OVER CONDITION FILES
            %  ----------------------------------------------------

            for fileIdx = 1:length(trialFiles)

                thisFileName = fullfile( ...
                    trialFiles(fileIdx).folder, ...
                    trialFiles(fileIdx).name);


                %% Load psychObj

                S = load(thisFileName, 'psychObj');

                if ~isfield(S, 'psychObj')
                    continue
                end

                psychObj = S.psychObj;


                %% Experimental condition metadata

                refFreqHz = nan;
                stimParamSide = "";
                testPhotoContrast = nan;

                if isprop(psychObj, 'refFreqHz')

                    refFreqHz = psychObj.refFreqHz;

                end

                if isprop(psychObj, 'stimParamSide')

                    stimParamSide = ...
                        string(psychObj.stimParamSide);

                end

                if isprop(psychObj, 'testPhotoContrast')

                    testPhotoContrast = ...
                        psychObj.testPhotoContrast;

                end


                %% Trial array

                if ~isfield(psychObj.questData, 'trialData')
                    continue
                end

                trialData = ...
                    psychObj.questData.trialData;


                %% ------------------------------------------------
                %  LOOP OVER INDIVIDUAL TRIALS
                %  ------------------------------------------------

                for trialIdx = 1:length(trialData)

                    thisTrial = trialData(trialIdx);


                    %% Check EOG exists

                    if ~isfield(thisTrial, 'EOGdata') || ...
                            isempty(thisTrial.EOGdata)

                        continue

                    end

                    trialEOG = thisTrial.EOGdata;


                    if ~isfield(trialEOG, 'response') || ...
                            isempty(trialEOG.response) || ...
                            size(trialEOG.response,1) < 1

                        continue

                    end


                    %% EOG signal

                    EOGSignal = ...
                        trialEOG.response(1,:);

                    timebase = ...
                        trialEOG.timebase;


                    %% Detect saccades

                    [events, ~] = detectEOGSaccades( ...
                        timebase, ...
                        EOGSignal, ...
                        trialParams);


                    if isempty(events)
                        continue
                    end


                    %% Trial recording time

                    if isfield(trialEOG, 'startTime')

                        trialStartTime = ...
                            trialEOG.startTime;

                    else

                        trialStartTime = NaT;

                    end


                    %% ------------------------------------------------
                    %  MATCH TRIAL TO CALIBRATION SESSION
                    %  ------------------------------------------------

                    [matchedSession, timeFromCalibrationHours] = ...
                        findClosestCalibrationSession( ...
                        trialStartTime, ...
                        calibrationStartTime(subjIdx,:), ...
                        eogPerDegMatrix(subjIdx,:));


                    if isnan(matchedSession)

                        warning([ ...
                            'Could not find calibration for %s, ' ...
                            '%s, trial %d.'], ...
                            thisSubj, ...
                            trialFiles(fileIdx).name, ...
                            trialIdx);

                        continue

                    end


                    %% ------------------------------------------------
                    %  CONVERT DETECTED SACCADES TO DEGREES
                    %  ------------------------------------------------

                    eogPerDegree = ...
                        eogPerDegMatrix( ...
                        subjIdx, ...
                        matchedSession);


                    amplitudesEOG = ...
                        abs([events.amplitude]);


                    amplitudesDegrees = ...
                        amplitudesEOG ./ eogPerDegree;


                    %% Mean for this trial

                    meanTrialAmplitudeDeg = ...
                        mean(amplitudesDegrees, 'omitnan');

                    maxTrialAmplitudeDeg = ...
                        max(amplitudesDegrees, [], 'omitnan');

                    nSaccades = ...
                        length(amplitudesDegrees);


                    participantTrialMeans(end+1,1) = ...
                        meanTrialAmplitudeDeg;


                    %% ------------------------------------------------
                    %  SAVE TRIAL-LEVEL RESULT
                    %  ------------------------------------------------

                    newRow = table( ...
                        thisSubj, ...
                        group(subjIdx), ...
                        string(lightLabels{lightIdx}), ...
                        string(trialFiles(fileIdx).name), ...
                        trialIdx, ...
                        refFreqHz, ...
                        stimParamSide, ...
                        testPhotoContrast, ...
                        matchedSession, ...
                        trialStartTime, ...
                        timeFromCalibrationHours, ...
                        eogPerDegree, ...
                        nSaccades, ...
                        meanTrialAmplitudeDeg, ...
                        maxTrialAmplitudeDeg, ...
                        'VariableNames', { ...
                        'SubjectID', ...
                        'Group', ...
                        'LightCondition', ...
                        'SourceFile', ...
                        'TrialNumber', ...
                        'RefFreqHz', ...
                        'StimParamSide', ...
                        'TestPhotoContrast', ...
                        'CalibrationSession', ...
                        'TrialStartTime', ...
                        'HoursFromCalibration', ...
                        'EOGPerDegreeUsed', ...
                        'NDetectedSaccades', ...
                        'MeanSaccadeAmplitudeDeg', ...
                        'MaxSaccadeAmplitudeDeg'});

                    trialResultsTable = ...
                        [trialResultsTable; newRow];

                end

            end


            %% ----------------------------------------------------
            %  POOLED PARTICIPANT VALUE WITHIN LIGHT LEVEL
            %  ----------------------------------------------------

            if ~isempty(participantTrialMeans)

                trialSaccadeDegrees( ...
                    subjIdx, ...
                    lightIdx) = ...
                    mean(participantTrialMeans, 'omitnan');

            end


            fprintf( ...
                '  %s: %d usable trials, mean = %.3f deg\n', ...
                lightLabels{lightIdx}, ...
                length(participantTrialMeans), ...
                trialSaccadeDegrees(subjIdx,lightIdx));

        end

    end


    %% ============================================================
    %  POOLED LOW / HIGH LIGHT PLOT
    %  ============================================================

    if plotPooledTrialData

        plotGroupComparison( ...
            trialSaccadeDegrees, ...
            controlIdx, ...
            migraineIdx, ...
            lightLabels, ...
            'Mean detected saccade amplitude (deg)', ...
            'DCPT-SDT Eye Movement Amplitude by Group');

    end


    %% ============================================================
    %  PARTICIPANT-LEVEL CONDITION MEANS
    %
    %  Each participant gets ONE mean for each exact condition:
    %
    %       Light level
    %       Photo contrast
    %       Reference frequency
    %       StimParamSide = hi / low
    %
    %  These are the values used for the condition-specific plots
    %  and can later be used for statistical modeling.
    %  ============================================================

    conditionParticipantTable = table;


    uniqueLights = unique( ...
        trialResultsTable.LightCondition, ...
        'stable');

    uniqueContrasts = sort( ...
        unique(trialResultsTable.TestPhotoContrast));

    uniqueFreqs = sort( ...
        unique(trialResultsTable.RefFreqHz));

    uniqueSides = unique( ...
        trialResultsTable.StimParamSide, ...
        'stable');


    for subjIdx = 1:nSubj

        thisSubj = subjectID(subjIdx);


        for lightIdx = 1:length(uniqueLights)

            thisLight = uniqueLights(lightIdx);


            for contrastIdx = 1:length(uniqueContrasts)

                thisContrast = ...
                    uniqueContrasts(contrastIdx);


                for freqIdx = 1:length(uniqueFreqs)

                    thisFreq = ...
                        uniqueFreqs(freqIdx);


                    for sideIdx = 1:length(uniqueSides)

                        thisSide = ...
                            uniqueSides(sideIdx);


                        idx = ...
                            trialResultsTable.SubjectID == thisSubj & ...
                            trialResultsTable.LightCondition == thisLight & ...
                            abs(trialResultsTable.TestPhotoContrast - thisContrast) < 1e-8 & ...
                            abs(trialResultsTable.RefFreqHz - thisFreq) < 1e-6 & ...
                            trialResultsTable.StimParamSide == thisSide;


                        if ~any(idx)
                            continue
                        end


                        thisTrialValues = ...
                            trialResultsTable.MeanSaccadeAmplitudeDeg(idx);


                        participantMean = ...
                            mean(thisTrialValues, 'omitnan');


                        participantMedian = ...
                            median(thisTrialValues, 'omitnan');


                        nUsableTrials = ...
                            sum(~isnan(thisTrialValues));


                        participantMaxTrialMean = ...
                            max(thisTrialValues, [], 'omitnan');


                        newRow = table( ...
                            thisSubj, ...
                            group(subjIdx), ...
                            thisLight, ...
                            thisContrast, ...
                            thisFreq, ...
                            thisSide, ...
                            nUsableTrials, ...
                            participantMean, ...
                            participantMedian, ...
                            participantMaxTrialMean, ...
                            'VariableNames', { ...
                            'SubjectID', ...
                            'Group', ...
                            'LightCondition', ...
                            'TestPhotoContrast', ...
                            'RefFreqHz', ...
                            'StimParamSide', ...
                            'NUsableTrials', ...
                            'MeanSaccadeAmplitudeDeg', ...
                            'MedianSaccadeAmplitudeDeg', ...
                            'MaxTrialMeanSaccadeAmplitudeDeg'});


                        conditionParticipantTable = ...
                            [conditionParticipantTable; newRow];

                    end

                end

            end

        end

    end


    %% ============================================================
    %  CONDITION-SPECIFIC CONTROL VS MIGRAINE PLOTS
    %
    %  One figure for each LIGHT x CONTRAST combination.
    %
    %  Rows    = stimParamSide (hi / low)
    %  Columns = reference frequency
    %
    %  Every subplot:
    %       small dots = participant condition means
    %       diamond    = group mean
    %       error bar  = SEM
    %  ============================================================

    if plotTrialConditions

        plotConditionComparisons( ...
            conditionParticipantTable);

    end


    %% ============================================================
    %  CONDITION-SPECIFIC GROUP SUMMARY
    %
    %  This gives the group means / SEM for every individual
    %  experimental condition.
    %  ============================================================

    conditionSummaryTable = table;


    for lightIdx = 1:length(uniqueLights)

        thisLight = uniqueLights(lightIdx);


        for contrastIdx = 1:length(uniqueContrasts)

            thisContrast = ...
                uniqueContrasts(contrastIdx);


            for freqIdx = 1:length(uniqueFreqs)

                thisFreq = ...
                    uniqueFreqs(freqIdx);


                for sideIdx = 1:length(uniqueSides)

                    thisSide = ...
                        uniqueSides(sideIdx);


                    idxCondition = ...
                        conditionParticipantTable.LightCondition == thisLight & ...
                        abs(conditionParticipantTable.TestPhotoContrast - thisContrast) < 1e-8 & ...
                        abs(conditionParticipantTable.RefFreqHz - thisFreq) < 1e-6 & ...
                        conditionParticipantTable.StimParamSide == thisSide;


                    controlData = ...
                        conditionParticipantTable.MeanSaccadeAmplitudeDeg( ...
                        idxCondition & ...
                        conditionParticipantTable.Group == "Control");


                    migraineData = ...
                        conditionParticipantTable.MeanSaccadeAmplitudeDeg( ...
                        idxCondition & ...
                        conditionParticipantTable.Group == "Migraine");


                    controlData = ...
                        controlData(~isnan(controlData));

                    migraineData = ...
                        migraineData(~isnan(migraineData));


                    nControl = length(controlData);
                    nMigraine = length(migraineData);


                    controlMean = mean(controlData, 'omitnan');
                    migraineMean = mean(migraineData, 'omitnan');


                    if nControl > 0
                        controlSEM = ...
                            std(controlData) / sqrt(nControl);
                    else
                        controlSEM = nan;
                    end


                    if nMigraine > 0
                        migraineSEM = ...
                            std(migraineData) / sqrt(nMigraine);
                    else
                        migraineSEM = nan;
                    end


                    % Welch t-test, saved for convenience.
                    %
                    % This does NOT replace whatever final statistical model
                    % is appropriate for the full factorial/repeated design.

                    pValue = nan;

                    if nControl >= 2 && nMigraine >= 2

                        [~, pValue] = ttest2( ...
                            controlData, ...
                            migraineData, ...
                            'Vartype','unequal');

                    end


                    newRow = table( ...
                        thisLight, ...
                        thisContrast, ...
                        thisFreq, ...
                        thisSide, ...
                        nControl, ...
                        controlMean, ...
                        controlSEM, ...
                        nMigraine, ...
                        migraineMean, ...
                        migraineSEM, ...
                        pValue, ...
                        'VariableNames', { ...
                        'LightCondition', ...
                        'TestPhotoContrast', ...
                        'RefFreqHz', ...
                        'StimParamSide', ...
                        'NControl', ...
                        'ControlMeanDeg', ...
                        'ControlSEM', ...
                        'NMigraine', ...
                        'MigraineMeanDeg', ...
                        'MigraineSEM', ...
                        'WelchPValue'});


                    conditionSummaryTable = ...
                        [conditionSummaryTable; newRow];

                end

            end

        end

    end


    %% ============================================================
    %  OUTLIER / ERROR INSPECTION
    %
    %  IMPORTANT:
    %  Nothing is excluded here.
    %
    %  This simply shows the largest values so that suspicious data
    %  can be traced back to the original trial and calibration.
    %  ============================================================

    sortedTrials = sortrows( ...
        trialResultsTable, ...
        'MeanSaccadeAmplitudeDeg', ...
        'descend');


    nToShow = min(25, height(sortedTrials));


    fprintf('\n')
    fprintf('----- LARGEST TRIAL MEAN SACCADE AMPLITUDES -----\n\n')


    disp(sortedTrials(1:nToShow, { ...
        'SubjectID', ...
        'Group', ...
        'LightCondition', ...
        'TestPhotoContrast', ...
        'RefFreqHz', ...
        'StimParamSide', ...
        'SourceFile', ...
        'TrialNumber', ...
        'CalibrationSession', ...
        'EOGPerDegreeUsed', ...
        'NDetectedSaccades', ...
        'MeanSaccadeAmplitudeDeg', ...
        'MaxSaccadeAmplitudeDeg'}))


    %% ============================================================
    %  SINGLE-TRIAL DIAGNOSTIC PLOT
    %  ============================================================

    if plotSingleTrialExample

        plotTrialSaccadeExample( ...
            example, ...
            trialResultsTable, ...
            baseDir, ...
            lightFolders, ...
            lightLabels, ...
            experimentName, ...
            trialParams);

    end


    %% ============================================================
    %  SAVE TRIAL OUTPUTS
    %  ============================================================

    trialParticipantTable = table( ...
        subjectID, ...
        group, ...
        trialSaccadeDegrees(:,1), ...
        trialSaccadeDegrees(:,2), ...
        'VariableNames', { ...
        'SubjectID', ...
        'Group', ...
        'LowLightMeanSaccadeAmplitudeDeg', ...
        'HighLightMeanSaccadeAmplitudeDeg'});


    writetable( ...
        trialParticipantTable, ...
        'EOGTrialAmplitudeByParticipant.csv');


    writetable( ...
        trialResultsTable, ...
        'EOGTrialAmplitudeTrialLevel.csv');


    writetable( ...
        conditionParticipantTable, ...
        'EOGTrialAmplitudeByParticipantAndCondition.csv');


    writetable( ...
        conditionSummaryTable, ...
        'EOGTrialConditionGroupSummary.csv');


    save( ...
        'EOGTrialAmplitudeResults.mat', ...
        'trialSaccadeDegrees', ...
        'trialParticipantTable', ...
        'trialResultsTable', ...
        'conditionParticipantTable', ...
        'conditionSummaryTable');


    %% Display condition summary

    disp(' ')
    disp('CONDITION-SPECIFIC GROUP SUMMARY')
    disp(conditionSummaryTable)

end


%% ================================================================
%  LOCAL FUNCTIONS
%  ================================================================


function [x, y] = generateEOGModel( ...
    timebase, ...
    onsets, ...
    cmdValues, ...
    reactionTime, ...
    fc)

    Neog = length(timebase);

    nCmd = length(cmdValues);

    x = zeros(Neog,1);


    for k = 1:nCmd

        if k < nCmd

            idx = ...
                timebase >= (onsets(k) + reactionTime) & ...
                timebase < (onsets(k+1) + reactionTime);

        else

            idx = ...
                timebase >= ...
                (onsets(k) + reactionTime);

        end

        x(idx) = cmdValues(k);

    end


    s = tf('s');

    omega_c = 2 * pi * fc;

    H = s / (s + omega_c);

    y = lsim(H, x, timebase);

end


function [onsets, offsets] = extractCommandOnsets(audioFile)

    [y, fs] = audioread(audioFile);


    if size(y,2) > 1
        y = mean(y,2);
    end


    a = abs(y);

    a = movmean( ...
        a, ...
        round(0.02 * fs));

    a = a / max(a);

    speech = a > 0.08;

    minGap = 0.15;

    speech = imclose( ...
        speech, ...
        ones(round(minGap * fs),1));

    d = diff([0; speech; 0]);

    onsets = ...
        find(d == 1) / fs;

    offsets = ...
        find(d == -1) / fs;

end


function [matchedSession, hoursApart] = ...
    findClosestCalibrationSession( ...
    trialStartTime, ...
    calibrationTimes, ...
    calibrationFactors)

    matchedSession = nan;

    hoursApart = nan;


    if isnat(trialStartTime)
        return
    end


    validIdx = ...
        ~isnat(calibrationTimes) & ...
        ~isnan(calibrationFactors) & ...
        calibrationFactors > 0;


    if ~any(validIdx)
        return
    end


    validSessions = find(validIdx);


    timeDifference = ...
        abs(calibrationTimes(validIdx) - trialStartTime);


    [smallestDifference, closestIdx] = ...
        min(timeDifference);


    matchedSession = ...
        validSessions(closestIdx);


    hoursApart = ...
        hours(smallestDifference);

end


function plotGroupComparison( ...
    dataMatrix, ...
    controlIdx, ...
    migraineIdx, ...
    conditionLabels, ...
    yLabelText, ...
    figureTitle)

    nConditions = size(dataMatrix,2);


    figure('Position', [100 100 1000 750]);


    if nConditions == 4

        tiledlayout(2,2, ...
            'TileSpacing','compact', ...
            'Padding','compact');

    elseif nConditions == 2

        tiledlayout(1,2, ...
            'TileSpacing','compact', ...
            'Padding','compact');

    else

        tiledlayout(1,nConditions, ...
            'TileSpacing','compact', ...
            'Padding','compact');

    end


    for conditionIdx = 1:nConditions

        nexttile

        hold on


        controlData = ...
            dataMatrix(controlIdx, conditionIdx);

        migraineData = ...
            dataMatrix(migraineIdx, conditionIdx);


        controlData = ...
            controlData(~isnan(controlData));

        migraineData = ...
            migraineData(~isnan(migraineData));


        controlMean = ...
            mean(controlData);

        migraineMean = ...
            mean(migraineData);


        controlSEM = ...
            std(controlData) / sqrt(length(controlData));

        migraineSEM = ...
            std(migraineData) / sqrt(length(migraineData));


        controlX = ...
            1 + 0.08 * ...
            (rand(size(controlData)) - 0.5);

        migraineX = ...
            2 + 0.08 * ...
            (rand(size(migraineData)) - 0.5);


        scatter( ...
            controlX, ...
            controlData, ...
            35, ...
            'filled', ...
            'MarkerFaceAlpha',0.55);


        scatter( ...
            migraineX, ...
            migraineData, ...
            35, ...
            'filled', ...
            'MarkerFaceAlpha',0.55);


        errorbar( ...
            1, ...
            controlMean, ...
            controlSEM, ...
            'k', ...
            'LineStyle','none', ...
            'LineWidth',1.8, ...
            'CapSize',12);


        errorbar( ...
            2, ...
            migraineMean, ...
            migraineSEM, ...
            'k', ...
            'LineStyle','none', ...
            'LineWidth',1.8, ...
            'CapSize',12);


        plot( ...
            1, ...
            controlMean, ...
            'kd', ...
            'MarkerSize',11, ...
            'MarkerFaceColor','k');


        plot( ...
            2, ...
            migraineMean, ...
            'kd', ...
            'MarkerSize',11, ...
            'MarkerFaceColor','k');


        xlim([0.5 2.5])

        xticks([1 2])

        xticklabels({ ...
            'Control', ...
            'Migraine'})

        ylabel(yLabelText)

        title(conditionLabels{conditionIdx})

        set(gca, ...
            'FontSize',13, ...
            'LineWidth',1)

        box off

    end


    sgtitle( ...
        figureTitle, ...
        'FontSize',16, ...
        'FontWeight','bold');

end


function plotConditionComparisons(conditionParticipantTable)
%
% Make separate control-vs-migraine subplot for every exact trial
% condition.
%
% One figure = one LightCondition x TestPhotoContrast.
%
% Rows    = stimParamSide
% Columns = refFreqHz

    lights = unique( ...
        conditionParticipantTable.LightCondition, ...
        'stable');

    contrasts = sort( ...
        unique(conditionParticipantTable.TestPhotoContrast));

    freqs = sort( ...
        unique(conditionParticipantTable.RefFreqHz));

    sides = unique( ...
        conditionParticipantTable.StimParamSide, ...
        'stable');


    for lightIdx = 1:length(lights)

        thisLight = lights(lightIdx);


        for contrastIdx = 1:length(contrasts)

            thisContrast = ...
                contrasts(contrastIdx);


            figure( ...
                'Position', ...
                [50 100 1500 650]);


            tiledlayout( ...
                length(sides), ...
                length(freqs), ...
                'TileSpacing','compact', ...
                'Padding','compact');


            for sideIdx = 1:length(sides)

                thisSide = ...
                    sides(sideIdx);


                for freqIdx = 1:length(freqs)

                    thisFreq = ...
                        freqs(freqIdx);


                    nexttile

                    hold on


                    idx = ...
                        conditionParticipantTable.LightCondition == thisLight & ...
                        abs(conditionParticipantTable.TestPhotoContrast - thisContrast) < 1e-8 & ...
                        abs(conditionParticipantTable.RefFreqHz - thisFreq) < 1e-6 & ...
                        conditionParticipantTable.StimParamSide == thisSide;


                    controlData = ...
                        conditionParticipantTable.MeanSaccadeAmplitudeDeg( ...
                        idx & ...
                        conditionParticipantTable.Group == "Control");


                    migraineData = ...
                        conditionParticipantTable.MeanSaccadeAmplitudeDeg( ...
                        idx & ...
                        conditionParticipantTable.Group == "Migraine");


                    controlData = ...
                        controlData(~isnan(controlData));

                    migraineData = ...
                        migraineData(~isnan(migraineData));


                    %% Individual participant dots

                    controlX = ...
                        1 + 0.08 * ...
                        (rand(size(controlData)) - 0.5);

                    migraineX = ...
                        2 + 0.08 * ...
                        (rand(size(migraineData)) - 0.5);


                    scatter( ...
                        controlX, ...
                        controlData, ...
                        28, ...
                        'filled', ...
                        'MarkerFaceAlpha',0.55);


                    scatter( ...
                        migraineX, ...
                        migraineData, ...
                        28, ...
                        'filled', ...
                        'MarkerFaceAlpha',0.55);


                    %% Group means / SEM

                    if ~isempty(controlData)

                        controlMean = ...
                            mean(controlData);

                        controlSEM = ...
                            std(controlData) / sqrt(length(controlData));


                        errorbar( ...
                            1, ...
                            controlMean, ...
                            controlSEM, ...
                            'k', ...
                            'LineStyle','none', ...
                            'LineWidth',1.5, ...
                            'CapSize',9);


                        plot( ...
                            1, ...
                            controlMean, ...
                            'kd', ...
                            'MarkerSize',9, ...
                            'MarkerFaceColor','k');

                    end


                    if ~isempty(migraineData)

                        migraineMean = ...
                            mean(migraineData);

                        migraineSEM = ...
                            std(migraineData) / sqrt(length(migraineData));


                        errorbar( ...
                            2, ...
                            migraineMean, ...
                            migraineSEM, ...
                            'k', ...
                            'LineStyle','none', ...
                            'LineWidth',1.5, ...
                            'CapSize',9);


                        plot( ...
                            2, ...
                            migraineMean, ...
                            'kd', ...
                            'MarkerSize',9, ...
                            'MarkerFaceColor','k');

                    end


                    %% Formatting

                    xlim([0.5 2.5])

                    xticks([1 2])

                    xticklabels({ ...
                        'Control', ...
                        'Migraine'})


                    ylabel('Mean saccade amplitude (deg)')


                    title(sprintf( ...
                        '%g Hz | %s', ...
                        thisFreq, ...
                        thisSide))


                    set(gca, ...
                        'FontSize',10, ...
                        'LineWidth',1)

                    box off

                end

            end


            sgtitle(sprintf( ...
                '%s | Photo contrast %.1f', ...
                thisLight, ...
                thisContrast), ...
                'FontSize',16, ...
                'FontWeight','bold');

        end

    end

end


function plotTrialSaccadeExample( ...
    example, ...
    trialResultsTable, ...
    baseDir, ...
    lightFolders, ...
    lightLabels, ...
    experimentName, ...
    trialParams)
%
% Plot one DCPT-SDT trial exactly like the saccade-detection QC plots:
%
%   black line  = smoothed EOG
%   green line  = detected onset
%   red line    = velocity peak
%   blue line   = detected offset

    %% Find selected trial in results table

    idx = ...
        trialResultsTable.SubjectID == example.subjectID & ...
        trialResultsTable.LightCondition == example.lightCondition & ...
        abs(trialResultsTable.TestPhotoContrast - example.testPhotoContrast) < 1e-8 & ...
        abs(trialResultsTable.RefFreqHz - example.refFreqHz) < 1e-6 & ...
        trialResultsTable.StimParamSide == example.stimParamSide & ...
        trialResultsTable.TrialNumber == example.trialNumber;


    matchRows = find(idx);


    if isempty(matchRows)

        warning('Could not find requested example trial.')
        return

    end


    % There should normally be one row.
    % If there are multiple rows, use the first.

    rowIdx = matchRows(1);

    sourceFile = ...
        trialResultsTable.SourceFile(rowIdx);


    %% Determine light folder

    lightIdx = find( ...
        string(lightLabels) == example.lightCondition, ...
        1);


    if isempty(lightIdx)

        warning('Could not determine light-level folder.')
        return

    end


    fileName = fullfile( ...
        baseDir, ...
        example.subjectID, ...
        lightFolders{lightIdx}, ...
        experimentName, ...
        sourceFile);


    if ~exist(fileName, 'file')

        warning('Could not find example file: %s', fileName)
        return

    end


    %% Load trial

    S = load(fileName, 'psychObj');

    psychObj = S.psychObj;

    trialData = ...
        psychObj.questData.trialData;

    thisTrial = ...
        trialData(example.trialNumber);

    trialEOG = ...
        thisTrial.EOGdata;

    EOGSignal = ...
        trialEOG.response(1,:);

    timebase = ...
        trialEOG.timebase;


    %% Detect saccades

    [events, debug] = detectEOGSaccades( ...
        timebase, ...
        EOGSignal, ...
        trialParams);


    %% Calibration information already used for this trial

    calibrationSession = ...
        trialResultsTable.CalibrationSession(rowIdx);

    eogPerDegree = ...
        trialResultsTable.EOGPerDegreeUsed(rowIdx);


    %% Convert detected amplitudes for display

    if ~isempty(events)

        amplitudesDegrees = ...
            abs([events.amplitude]) ./ ...
            eogPerDegree;

        meanAmplitudeDeg = ...
            mean(amplitudesDegrees, 'omitnan');

    else

        amplitudesDegrees = [];

        meanAmplitudeDeg = nan;

    end


    %% Plot

    figure('Position',[100 100 1100 500]);

    plot( ...
        debug.timebase, ...
        debug.EOGSmooth, ...
        'k', ...
        'LineWidth',1.2);

    hold on


    for eventIdx = 1:length(events)

        xline( ...
            events(eventIdx).onsetTime, ...
            'g--', ...
            'LineWidth',1);

        xline( ...
            events(eventIdx).peakTime, ...
            'r:', ...
            'LineWidth',1);

        xline( ...
            events(eventIdx).offsetTime, ...
            'b--', ...
            'LineWidth',1);

    end


    xlabel('Time (s)')

    ylabel('EOG amplitude')


    title(sprintf([ ...
        '%s | %s | contrast %.1f | %g Hz | %s | Trial %d\n' ...
        'Calibration session %d | %d saccades | mean amplitude %.2f deg'], ...
        example.subjectID, ...
        example.lightCondition, ...
        example.testPhotoContrast, ...
        example.refFreqHz, ...
        example.stimParamSide, ...
        example.trialNumber, ...
        calibrationSession, ...
        length(events), ...
        meanAmplitudeDeg));


    if isempty(events)

        legend('Smoothed EOG')

    else

        legend( ...
            'Smoothed EOG', ...
            'Onset', ...
            'Peak', ...
            'Offset', ...
            'Location','best')

    end


    box off

end