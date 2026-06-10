function morningnessSummary = analyzeMEQ(participantList, dataDir)

% Load MEQ data
meqFile = fullfile(dataDir, 'FLIC Morningness-Eveningness Questionnaire (MEQ) (Responses).xlsx');

% Load the data
opts = detectImportOptions(meqFile);
opts.VariableNamingRule = 'preserve';
rawTable = readtable(meqFile, opts);

% Clean participant names (removing any leading/trailing whitespace)
participantCol = rawTable.Properties.VariableNames{2};
rawTable.(participantCol) = strtrim(rawTable.(participantCol));
participantList = strtrim(participantList);

% Extract the 19 question columns (assumes they follow the participant ID)
qData = rawTable(:, 3:21);

numParticipants = length(participantList);
totalScores = nan(numParticipants, 1);

% Scoring Loop
for i = 1:numParticipants
    % Find the row for this participant
    pRow = rawTable(strcmp(rawTable.(participantCol), participantList{i}), :);

    if ~isempty(pRow)
        currentScore = 0;
        % Score each of the 19 questions
        for q = 1:19
            respText = pRow{1, q+2}{1}; % Extract string from cell
            currentScore = currentScore + calculateItemScore(respText, q);
        end
        totalScores(i) = currentScore;
    end
end

% Classification
types = cell(numParticipants, 1);
for jj = 1:numParticipants
    ss = totalScores(jj);
    if isnan(ss), types{jj} = 'Missing';
    elseif ss >= 70, types{jj} = 'Definitely Morning';
    elseif ss >= 59, types{jj} = 'Moderately Morning';
    elseif ss >= 42, types{jj} = 'Intermediate';
    elseif ss >= 31, types{jj} = 'Moderately Evening';
    else, types{jj} = 'Definitely Evening';
    end
end

morningnessScores = table(participantList(:), totalScores, types, ...
    'VariableNames', {'Participant', 'MEQ_Score', 'Chronotype'});

% Determine control vs migrainer
% Extract numeric part after "FLIC_"
idNum = str2double(extractAfter(string(participantList(:)), "FLIC_"));
% Define groups
isMigrainer = idNum >= 1000;   % e.g., 1016 → migrainer
isControl   = idNum < 1000;    % e.g., 0013 → control

% Summarize chronotype categories
% Using 3 categories instead of the 5 above for simplicity
morningnessSummary = strings(2,1);

groupIdx = {isControl, isMigrainer};

for gg = 1:2

    scores = totalScores(groupIdx{gg});
    scores = scores(~isnan(scores));

    n = numel(scores);

    evening = sum(scores <= 41);
    intermediate = sum(scores >= 42 & scores <= 58);
    morning = sum(scores >= 59);

    morningnessSummary(gg) = sprintf( ...
        'Evening: %d (%.0f%%), Intermediate: %d (%.0f%%), Morning: %d (%.0f%%)', ...
        evening, 100*evening/n, ...
        intermediate, 100*intermediate/n, ...
        morning, 100*morning/n);
end

end

function pts = calculateItemScore(txt, qNum)
% Standard MEQ Scoring Logic for Text Responses
txt = lower(txt);
pts = 0;

% Specific mappings based on MEQ Google form
switch qNum
    case {1, 2, 10} % 5-point items (e.g., Wake/Sleep times)
        if contains(txt, '5:00') || contains(txt, '8:00'), pts = 5;
        elseif contains(txt, '6:30') || contains(txt, '9:00'), pts = 4;
        elseif contains(txt, '7:45') || contains(txt, '10:15'), pts = 3;
        elseif contains(txt, '9:45') || contains(txt, '12:30') || contains(txt, '12:45'), pts = 2;
        elseif contains(txt, '11:00') || contains(txt, '1:45') || contains(txt, '2:00'), pts = 1;
        end

    case {3} % 4-point item
        if contains(txt, 'not at all'), pts = 4;
        elseif contains(txt, 'slightly'), pts = 3;
        elseif contains(txt, 'fairly'), pts = 2;
        elseif contains(txt, 'very'), pts = 1;
        else error('Question 3 response not coded.');
        end

    case {4} % 4-point item
        if contains(txt, 'very easy'), pts = 4;
        elseif contains(txt, 'fairly easy'), pts = 3;
        elseif contains(txt, 'not very easy'), pts = 2;
        elseif contains(txt, 'not at all easy'), pts = 1;
        else error('Question 4 response not coded.');
        end

    case {5, 6} % 4-point item
        if contains(txt, 'very'), pts = 4;
        elseif contains(txt, 'fairly'), pts = 3;
        elseif contains(txt, 'slightly'), pts = 2;
        elseif contains(txt, 'not at all'), pts = 1;
        else error('Question 5 or 6 response not coded.');
        end

    case {7} % 4-point item
        if contains(txt, 'very refreshed'), pts = 4;
        elseif contains(txt, 'fairly refreshed'), pts = 3;
        elseif contains(txt, 'fairly tired'), pts = 2;
        elseif contains(txt, 'very tired'), pts = 1;
        else error('Question 7 response not coded.');
        end

    case {8} % 4-point item
        if contains(txt, 'seldom'), pts = 4;
        elseif contains(txt, 'less'), pts = 3;
        elseif contains(txt, '1-2'), pts = 2;
        elseif contains(txt, 'more than'), pts = 1;
        else error('Question 8 response not coded.');
        end

    case {9} % 4-point item
        if contains(txt, 'good form'), pts = 4;
        elseif contains(txt, 'reasonable form'), pts = 3;
        elseif contains(txt, 'would find it difficult'), pts = 2;
        elseif contains(txt, 'would find it very difficult'), pts = 1;
        else error('Question 9 response not coded.');
        end

    case {11} % 4-point item
        if contains(txt, '8:00'), pts = 6;
        elseif contains(txt, '11:00'), pts = 4;
        elseif contains(txt, '3:00'), pts = 2;
        elseif contains(txt, '7:00'), pts = 0;
        else error('Question 11 response not coded.');
        end

    case {12} % 4-point item
        if contains(txt, 'not at all'), pts = 0;
        elseif contains(txt, 'a little'), pts = 2;
        elseif contains(txt, 'fairly'), pts = 3;
        elseif contains(txt, 'very'), pts = 5;
        else error('Question 12 response not coded.');
        end

    case {13} % 4-point item
        if contains(txt, 'not fall back asleep'), pts = 4;
        elseif contains(txt, 'doze thereafter'), pts = 3;
        elseif contains(txt, 'fall asleep again'), pts = 2;
        elseif contains(txt, 'later than usual'), pts = 1;
        else error('Question 13 response not coded.');
        end

    case {14} % 4-point item
        if contains(txt, 'not go to bed'), pts = 1;
        elseif contains(txt, 'take a nap'), pts = 2;
        elseif contains(txt, 'take a good sleep'), pts = 3;
        elseif contains(txt, 'before watch'), pts = 4;
        else error('Question 14 response not coded.');
        end

    case {15} % 4-point item
        if contains(txt, '8:00'), pts = 4;
        elseif contains(txt, '11:00'), pts = 3;
        elseif contains(txt, '3:00'), pts = 2;
        elseif contains(txt, '7:00'), pts = 1;
        else error('Question 15 response not coded.');
        end

    case {16} % 4-point item
        if contains(txt, 'would find it very difficult'), pts = 4;
        elseif contains(txt, 'would find it difficult'), pts = 3;
        elseif contains(txt, 'reasonable form'), pts = 2;
        elseif contains(txt, 'good form'), pts = 1;
        else error('Question 16 response not coded.');
        end

    case {17} % Specific 5-point Peak items
        if contains(txt, '4:00 am and 8:00'), pts = 5;
        elseif contains(txt, '8:00 am and 9:00'), pts = 4;
        elseif contains(txt, '9:00 am and 2:00'), pts = 3;
        elseif contains(txt, '2:00 pm and 5:00'), pts = 2;
        elseif contains(txt, '5:00 pm and 4:00'), pts = 1;
        else error('Question 17 response not coded.');
        end

    case {18} % Specific 5-point Peak items
        if contains(txt, '5:00 – 8:00 am'), pts = 5;
        elseif contains(txt, '8:00 – 10:00 am'), pts = 4;
        elseif contains(txt, '10:00 am – 5:00 pm'), pts = 3;
        elseif contains(txt, '5:00 – 10:00 pm'), pts = 2;
        elseif contains(txt, '10:00 pm – 5:00 am'), pts = 1;
        else error('Question 18 response not coded.');
        end

    case 19 % The "Morning or Evening Type" self-assessment
        if contains(txt, 'definitely a “morning” type'), pts = 6;
        elseif contains(txt, 'rather more a “morning” than'), pts = 4;
        elseif contains(txt, 'rather more an “evening” than'), pts = 2;
        elseif contains(txt, 'definitely an “evening” type'), pts = 1;
        else error('Question 19 response not coded.');
        end
end
end



