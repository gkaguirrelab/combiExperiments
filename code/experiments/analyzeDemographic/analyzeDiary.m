function [weeklyMigraineSummary, ...
    migrainePainSummary, ...
    percentMigraineMissingSummary, ...
    baselineWeeklyMigraineSummary,...
    baselinePainSummary,...
    baselinePercentMissingSummary, ...
    taskWeeklyMigraineSummary,...
    taskPainSummary,...
    taskPercentMissingSummary, ...
    subjectDiaryT] = analyzeDiary(participantList, dataDir, subjSummaryDataDir)

% Load FLIC sessions data
sessionsFile = fullfile(subjSummaryDataDir, 'FLIC_Sessions.xlsx');
% Load headache diary data
diaryFile = fullfile(dataDir, 'FLIC Headache Diary (Responses).xlsx');

% Detect the default options for these files
optsDiary = detectImportOptions(diaryFile);
optsSessions = detectImportOptions(sessionsFile);

% Set where the Variable Names (titles) and Data start
% Headers are in Row 1 and data starts in Row 2:
optsDiary.VariableNamesRange = 'A1';
optsDiary.DataRange = 'A2';
optsSessions.VariableNamesRange = 'A1';
optsSessions.DataRange = 'A2';

% Read the Excel file into a table
diaryT = readtable(diaryFile, optsDiary);
sessionsT = readtable(sessionsFile, optsSessions);

% Extract the diary columns by position. This avoids depending on the long
% Google Forms question text after MATLAB sanitizes variable names.
subjectID = normalizeSubjectID(diaryT{:,2});
timestampDate = convertDiaryDate(diaryT{:,1});
diaryDate = repairDiaryDate(convertDiaryDate(diaryT{:,3}), timestampDate);
migraineResponse = lower(strtrim(string(diaryT{:,5})));
isMigraineDay = startsWith(migraineResponse, "yes");
isMigraineDay(ismissing(migraineResponse)) = false;
painRating = convertNumeric(diaryT{:,6});
% Filter to completed subjects only
participantList = normalizeSubjectID(participantList);
idx_keep = ismember(subjectID, participantList);
subjectID = subjectID(idx_keep);
diaryDate = diaryDate(idx_keep);
isMigraineDay = isMigraineDay(idx_keep);
painRating = painRating(idx_keep);
% Build a subject-level table in participantList order
nSubjects = numel(participantList);
idNum = str2double(extractAfter(participantList(:), "FLIC_"));
isMigraineGroup = idNum >= 1000;

subjectDiaryT = table( ...
    participantList(:), ...
    isMigraineGroup(:), ...
    nan(nSubjects,1), ... % ExpectedDiaryDays
    nan(nSubjects,1), ... % CompletedDiaryDays
    nan(nSubjects,1), ... % MissingDiaryDays
    nan(nSubjects,1), ... % PercentMissingDays
    nan(nSubjects,1), ... % MigraineDays
    nan(nSubjects,1), ... % MigrainesPerWeek
    nan(nSubjects,1), ... % MeanMigrainePain
    nan(nSubjects,1), ... % BaselineMigraineDays
    nan(nSubjects,1), ... % BaselinePercentMissingDays
    nan(nSubjects,1), ... % BaselineMigrainesPerWeek
    nan(nSubjects,1), ... % BaselineMeanMigrainePain
    nan(nSubjects,1), ... % TaskMigraineDays
    nan(nSubjects,1), ... % TaskPercentMissingDays
    nan(nSubjects,1), ... % TaskMigrainesPerWeek
    nan(nSubjects,1), ... % TaskMeanMigrainePain
    'VariableNames', { ...
    'SubjectID', ...
    'IsMigraineGroup', ...
    'ExpectedDiaryDays', ...
    'CompletedDiaryDays', ...
    'MissingDiaryDays', ...
    'PercentMissingDays', ...
    'MigraineDays', ...
    'MigrainesPerWeek', ...
    'MeanMigrainePain', ...
    'BaselineMigraineDays', ...
    'BaselinePercentMissingDays', ...
    'BaselineMigrainesPerWeek', ...
    'BaselineMeanMigrainePain', ...
    'TaskMigraineDays', ...
    'TaskPercentMissingDays', ...
    'TaskMigrainesPerWeek', ...
    'TaskMeanMigrainePain'});

% Get task start dates
[intakeDates, taskStartDates, taskEndDates] = getTaskStartDates(participantList, sessionsT);

for ss = 1:nSubjects
    idx = subjectID == participantList(ss);

    if ~any(idx)
        continue
    end

    subjDates = diaryDate(idx);
    subjMigraine = isMigraineDay(idx);
    subjPain = painRating(idx);

    % Remove duplicate days, keep first occurrence
    [~, keepIdx] = unique(dateshift(subjDates,'start','day'), 'stable');

    subjDates = subjDates(keepIdx);
    subjMigraine = subjMigraine(keepIdx);
    subjPain = subjPain(keepIdx);

    if isempty(subjDates)
        continue
    end

    %% Overall diary analysis
    % Expected study days between first and last diary entry
    expectedDays = days(max(subjDates) - min(subjDates)) + 1;

    % Number of unique dates actually completed
    completedDays = numel(unique(dateshift(subjDates,'start','day')));

    % Missing days
    missingDays = expectedDays - completedDays;

    % Percent missing
    percentMissing = 100 * missingDays / expectedDays;

    % Migraine days
    migraineDays = sum(subjMigraine);

    subjectDiaryT.ExpectedDiaryDays(ss) = expectedDays;
    subjectDiaryT.CompletedDiaryDays(ss) = completedDays;
    subjectDiaryT.MissingDiaryDays(ss) = missingDays;
    subjectDiaryT.PercentMissingDays(ss) = percentMissing;
    subjectDiaryT.MigraineDays(ss) = migraineDays;

    % Normalize to completed days only
    subjectDiaryT.MigrainesPerWeek(ss) = migraineDays / completedDays * 7;

    % Calculate mean migraine pain across migraine days per subject
    subjectDiaryT.MeanMigrainePain(ss) = mean(subjPain(subjMigraine), 'omitnan');

    %% Baseline and task-period analyses

    taskStart = taskStartDates(ss);
    baselineStart = intakeDates(ss); 
    endDate = taskEndDates(ss); 

    if ~isnat(taskStart) && ~isnat(baselineStart)

        baselineIdx = ...
            subjDates >= baselineStart & ...
            subjDates < taskStart;

        taskIdx = subjDates >= taskStart;

        % Baseline
        baselineDaysCompleted = ...
            numel(unique(dateshift(subjDates(baselineIdx), ...
            'start','day')));

        baselineMigraineDays = ...
            sum(subjMigraine(baselineIdx));

        subjectDiaryT.BaselineMigraineDays(ss) = ...
            baselineMigraineDays;

        if baselineDaysCompleted > 0

            subjectDiaryT.BaselineMigrainesPerWeek(ss) = ...
                baselineMigraineDays / baselineDaysCompleted * 7;

        end

        subjectDiaryT.BaselineMeanMigrainePain(ss) = ...
            mean(subjPain(baselineIdx & subjMigraine), ...
            'omitnan');

        % Finding percentage of missing days
        baselineExpectedDays = ...
            days(taskStart - baselineStart);

        baselineMissingDays = ...
            baselineExpectedDays - baselineDaysCompleted;

        baselinePercentMissing = ...
            100 * baselineMissingDays / baselineExpectedDays;

        subjectDiaryT.BaselinePercentMissingDays(ss) = ...
            baselinePercentMissing;

        % Task period
        taskDaysCompleted = ...
            numel(unique(dateshift(subjDates(taskIdx), ...
            'start','day')));

        taskMigraineDays = ...
            sum(subjMigraine(taskIdx));

        subjectDiaryT.TaskMigraineDays(ss) = ...
            taskMigraineDays;

        if taskDaysCompleted > 0

            subjectDiaryT.TaskMigrainesPerWeek(ss) = ...
                taskMigraineDays / taskDaysCompleted * 7;

        end

        subjectDiaryT.TaskMeanMigrainePain(ss) = ...
            mean(subjPain(taskIdx & subjMigraine), ...
            'omitnan');

        % Finding percentage of missing days
        taskExpectedDays = ...
            days(endDate - taskStart) + 1;

        taskMissingDays = ...
            taskExpectedDays - taskDaysCompleted;

        taskPercentMissing = ...
            100 * taskMissingDays / taskExpectedDays;

        subjectDiaryT.TaskPercentMissingDays(ss) = ...
            taskPercentMissing;

    end

end

% Summarize by group so that controls are blank. Rows are 1 = Control, 2 = Migraine with aura.
% Initialize outputs
weeklyMigraineSummary = strings(2,1);
migrainePainSummary = strings(2,1);
percentMigraineMissingSummary = strings(2,1);

baselineWeeklyMigraineSummary = strings(2,1);
baselinePainSummary = strings(2,1);
baselinePercentMissingSummary = strings(2,1);

taskWeeklyMigraineSummary = strings(2,1);
taskPainSummary = strings(2,1);
taskPercentMissingSummary = strings(2,1);

groupIdx = {~subjectDiaryT.IsMigraineGroup, subjectDiaryT.IsMigraineGroup};

for gg = 1:2

    % Overall analysis
    weeklyMigraineSummary(gg) = formatMeanSD( ...
        subjectDiaryT.MigrainesPerWeek(groupIdx{gg}));

    migrainePainSummary(gg) = formatMeanSD( ...
        subjectDiaryT.MeanMigrainePain(groupIdx{gg}));

    percentMigraineMissingSummary(gg) = formatMeanSD( ...
        subjectDiaryT.PercentMissingDays(groupIdx{gg}));

    % Baseline period
    baselineWeeklyMigraineSummary(gg) = formatMeanSD( ...
        subjectDiaryT.BaselineMigrainesPerWeek(groupIdx{gg}));

    baselinePainSummary(gg) = formatMeanSD( ...
        subjectDiaryT.BaselineMeanMigrainePain(groupIdx{gg}));

    baselinePercentMissingSummary(gg) = formatMeanSD( ...
        subjectDiaryT.BaselinePercentMissingDays(groupIdx{gg}));

    % Task period
    taskWeeklyMigraineSummary(gg) = formatMeanSD( ...
        subjectDiaryT.TaskMigrainesPerWeek(groupIdx{gg}));

    taskPainSummary(gg) = formatMeanSD( ...
        subjectDiaryT.TaskMeanMigrainePain(groupIdx{gg}));

    taskPercentMissingSummary(gg) = formatMeanSD( ...
        subjectDiaryT.TaskPercentMissingDays(groupIdx{gg}));

end

% Functions for extracting & organizing subject IDs, dates, and summary vals from diary

function subjectID = normalizeSubjectID(subjectID)

subjectID = upper(strtrim(string(subjectID)));
subjectID = replace(subjectID, "-", "_");

end

function diaryDate = convertDiaryDate(dateValues)

if isdatetime(dateValues)
    diaryDate = dateValues;
elseif isnumeric(dateValues)
    diaryDate = datetime(dateValues, 'ConvertFrom', 'excel');
else
    dateStrings = string(dateValues);
    diaryDate = NaT(size(dateStrings));
    dateFormats = ["MM/dd/uuuu", "M/d/uuuu", "MM/dd/yyyy", "M/d/yyyy", ...
        "yyyy-MM-dd HH:mm:ss.SSSSSS", "yyyy-MM-dd HH:mm:ss.SSS", ...
        "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd", "dd-MMM-uuuu", "dd-MMM-yyyy"];

    for ff = 1:numel(dateFormats)
        dateIdx = isnat(diaryDate) & ~ismissing(dateStrings);

        if ~any(dateIdx)
            break
        end

        try
            diaryDate(dateIdx) = datetime(dateStrings(dateIdx), 'InputFormat', dateFormats(ff));
        catch
        end
    end

    dateIdx = isnat(diaryDate) & ~ismissing(dateStrings);
    if any(dateIdx)
        try
            diaryDate(dateIdx) = datetime(dateStrings(dateIdx));
        catch
        end
    end
end

idxLowYear = ~isnat(diaryDate) & year(diaryDate) < 100;
diaryDate(idxLowYear) = diaryDate(idxLowYear) + calyears(2000);

end

function diaryDate = repairDiaryDate(diaryDate, timestampDate)

% If the diary-date field is missing or implausibly far from the submission
% timestamp, use the timestamp date as a conservative fallback.
idxUseTimestamp = ~isnat(timestampDate) & ...
    (isnat(diaryDate) | abs(days(diaryDate - timestampDate)) > 366);
diaryDate(idxUseTimestamp) = dateshift(timestampDate(idxUseTimestamp), 'start', 'day');

end

function numericValues = convertNumeric(values)

if isnumeric(values)
    numericValues = double(values);
else
    numericValues = str2double(string(values));
end

end

function summaryString = formatMeanSD(values)

values = values(~isnan(values));

if isempty(values)
    summaryString = "";
else
    summaryString = sprintf('%.2f ± %.2f', mean(values, 'omitnan'), std(values, 'omitnan'));
end

end

function [intakeDates, taskStartDates, taskEndDates] = ...
    getTaskStartDates(participantList, sessionsT)

nSubjs = numel(participantList);

intakeDates = NaT(nSubjs,1);
taskStartDates = NaT(nSubjs,1);
taskEndDates = NaT(nSubjs,1);

% Extract subject ID
sessionSubjectID = normalizeSubjectID(sessionsT.SubjectID);
sessionNumber = sessionsT.SessionNumber;
studyDate = convertDiaryDate(sessionsT.DateOfStudy);

for sub = 1:nSubjs

    % Skip controls (IDs < 1000)
    idNumSkip = str2double(extractAfter(participantList(sub),"FLIC_"));
    if idNumSkip < 1000
        continue
    end

    intakeIdx = sessionSubjectID == participantList(sub) & ...
        sessionNumber == 0;

    taskStartIdx = sessionSubjectID == participantList(sub) & ...
        sessionNumber == 1;

    lastSessionIdx = sessionSubjectID == participantList(sub) & ...
        sessionNumber == 4;

    % Intake date (Session 0)

    if sum(intakeIdx) == 1

        intakeDates(sub) = studyDate(intakeIdx);

    elseif sum(intakeIdx) > 1

        warning('Multiple Session 0 rows found for %s', ...
            participantList(sub));

        intakeDates(sub) = ...
            studyDate(find(intakeIdx,1,'first'));

    else

        warning('No Session 0 row found for %s', ...
            participantList(sub));

    end

    % Task start date (Session 1)

    if sum(taskStartIdx) == 1

        taskStartDates(sub) = studyDate(taskStartIdx);

    elseif sum(taskStartIdx) > 1

        warning('Multiple Session 1 rows found for %s', ...
            participantList(sub));

        taskStartDates(sub) = ...
            studyDate(find(taskStartIdx,1,'first'));

    else

        warning('No Session 1 row found for %s', ...
            participantList(sub));

    end

    % Task end date (Session 4)

    if sum(lastSessionIdx) == 1

        taskEndDates(sub) = studyDate(lastSessionIdx);

    elseif sum(lastSessionIdx) > 1

        warning('Multiple Session 4 rows found for %s', ...
            participantList(sub));

        taskEndDates(sub) = ...
            studyDate(find(lastSessionIdx,1,'first'));

    else

        warning('No Session 4 row found for %s', ...
            participantList(sub));

    end

end

end

end
