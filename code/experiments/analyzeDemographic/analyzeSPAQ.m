% Define your file path
meqFile = '/Users/rubybouh/Aguirre-Brainard Lab Dropbox/Ruby Bouhassira/FLIC_analysis/dichopticFlicker/surveyData/FLIC Morningness-Eveningness Questionnaire (MEQ) (Responses).xlsx';

% Your list of participants from your main summary table
subjects = {'FLIC_0013', 'FLIC_0002', 'FLIC_0003'}; 

% Get the scores
meqResults = getMEQScores(meqFile, subjects);

% Display results
disp(meqResults);

%% Functions for scoring 

function scoresTable = getMEQScores(filePath, participantList)
    % Load the data
    opts = detectImportOptions(filePath);
    opts.VariableNamingRule = 'preserve';
    rawTable = readtable(filePath, opts);
    
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
    for j = 1:numParticipants
        s = totalScores(j);
        if isnan(s), types{j} = 'Missing';
        elseif s >= 70, types{j} = 'Definitely Morning';
        elseif s >= 59, types{j} = 'Moderately Morning';
        elseif s >= 42, types{j} = 'Intermediate';
        elseif s >= 31, types{j} = 'Moderately Evening';
        else, types{j} = 'Definitely Evening';
        end
    end
    
    scoresTable = table(participantList(:), totalScores, types, ...
        'VariableNames', {'Participant', 'MEQ_Score', 'Chronotype'});
end

function pts = calculateItemScore(txt, qNum)
    % Standard MEQ Scoring Logic for Text Responses
    txt = lower(txt);
    pts = 0; 
    
    % Examples of specific mappings based on standard MEQ text:
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