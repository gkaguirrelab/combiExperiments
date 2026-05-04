function [weeklyMigraineSummary, migrainePainSummary, subjectDiaryT] = analyzeDiary(participantList, dataDir)

% Load headache diary data
diaryFile = fullfile(dataDir, 'FLIC Headache Diary (Responses).xlsx');

% Detect the default options for this file
opts = detectImportOptions(diaryFile);

% Set where the Variable Names (titles) and Data start
% Headers are in Row 1 and data starts in Row 2:
opts.VariableNamesRange = 'A1';
opts.DataRange = 'A2';

% Read the Excel file into a table
diaryT = readtable(diaryFile, opts);

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
    nan(nSubjects,1), ...
    nan(nSubjects,1), ...
    nan(nSubjects,1), ...
    nan(nSubjects,1), ...
    'VariableNames', { ...
        'SubjectID', ...
        'IsMigraineGroup', ...
        'DiaryDays', ...
        'MigraineDays', ...
        'MigrainesPerWeek', ...
        'MeanMigrainePain'});

for ss = 1:nSubjects
    idx = subjectID == participantList(ss);

    if ~any(idx)
        continue
    end

    subjDates = diaryDate(idx);
    subjMigraine = isMigraineDay(idx);
    subjPain = painRating(idx);

    validDate = ~isnat(subjDates);
    subjDates = subjDates(validDate);
    subjMigraine = subjMigraine(validDate);
    subjPain = subjPain(validDate);

    if isempty(subjDates)
        continue
    end

    subjectDiaryT.DiaryDays(ss) = days(max(subjDates) - min(subjDates)) + 1;
    subjectDiaryT.MigraineDays(ss) = sum(subjMigraine);
    subjectDiaryT.MigrainesPerWeek(ss) = subjectDiaryT.MigraineDays(ss) ./ subjectDiaryT.DiaryDays(ss) .* 7;
    subjectDiaryT.MeanMigrainePain(ss) = mean(subjPain(subjMigraine), 'omitnan');
end

% Summarize by group. Rows are 1 = Control, 2 = Migraine with aura.
weeklyMigraineSummary = strings(2,1);
migrainePainSummary = strings(2,1);

groupIdx = {~subjectDiaryT.IsMigraineGroup, subjectDiaryT.IsMigraineGroup};
for gg = 1:2
    weeklyRates = subjectDiaryT.MigrainesPerWeek(groupIdx{gg});
    meanPain = subjectDiaryT.MeanMigrainePain(groupIdx{gg});

    weeklyMigraineSummary(gg) = formatMeanSD(weeklyRates);
    migrainePainSummary(gg) = formatMeanSD(meanPain);
end

end

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
        idx = isnat(diaryDate) & ~ismissing(dateStrings);

        if ~any(idx)
            break
        end

        try
            diaryDate(idx) = datetime(dateStrings(idx), 'InputFormat', dateFormats(ff));
        catch
        end
    end

    idx = isnat(diaryDate) & ~ismissing(dateStrings);
    if any(idx)
        try
            diaryDate(idx) = datetime(dateStrings(idx));
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
