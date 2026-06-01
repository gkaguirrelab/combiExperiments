function [medSummary] = analyzeMeds(participantList, dataDir)

% Load subj summary excel sheet
% Analyzing meds in this file as this requires a more detailed analysis
% than other subjSummary items
subjSummaryFile = fullfile(dataDir,'/FLIC_SubjectSummary.xlsx'); 

% Detect the default options for this file
opts = detectImportOptions(subjSummaryFile);

% Set where the Variable Names (titles) and Data start
% Headers are in Row 1 and data starts in Row 2:
opts.VariableNamesRange = 'A1'; 
opts.DataRange = 'A2';

% Read the Excel file into a table
subjSummaryT = readtable(subjSummaryFile, opts);

% Rename variables to clean names
subjSummaryT = renamevars(subjSummaryT, {'SubjectID__'},{'SubjectID'});

% Last subject is FLIC_0051, want the table to end here
idx_end = find(strcmp(subjSummaryT.SubjectID, 'FLIC_0051'));
subjSummaryT = subjSummaryT(1:idx_end, :);

% Keep only subjects in participantList
subjSummaryT = subjSummaryT(ismember(subjSummaryT.SubjectID, participantList), :);

% Convert text columns to string arrays
subjSummaryT.MigraineOrControl_ = string(subjSummaryT.MigraineOrControl_);
% Extract prescription medications column
subjSummaryT = renamevars(subjSummaryT, ...
    'PrescriptionMedications__including_asNeeded_MedicationsTakenWit', ...
    'medList');
subjSummaryT.medList = string(subjSummaryT.medList);

% Sort order to be migrainers -> control subjects in increasing order
subjSummaryT.idNum = str2double(extractAfter(subjSummaryT.SubjectID,"FLIC_"));
subjSummaryT = sortrows(subjSummaryT, {'MigraineOrControl_','idNum'});
subjSummaryT.idNum = []; % remove temp variable

groups = {'Control','Migraine'};
tableGroups = {'Control', 'Migraine with aura'}; % longer names for table

cats = ["NSAID","Acetaminophen","Excedrin", ...
    "Triptan","Gepant","Preventive", ...
    "NonMigraine"];

countsMigraine = zeros(length(cats),1);
countsControl  = zeros(length(cats),1);

for i = 1:height(subjSummaryT)

    med = lower(string(subjSummaryT.medList(i)));

    hasNSAID = contains(med,["celecoxib","ibuprofen","naproxen","aspirin"]);

    hasAcetaminophen = contains(med,["acetaminophen","tylenol"]);

    hasExcedrin = contains(med,"excedrin");

    hasTriptan = contains(med,["sumatriptan","rizatriptan", ...
        "zolmitriptan","eletriptan", ...
        "almotriptan","naratriptan", ...
        "frovatriptan"]);

    hasGepant = contains(med,["ubrelvy","ubrogepant", ...
        "rimegepant","nurtec"]);

    hasPreventive = contains(med,["propranolol", ...
        "metoprolol", ...
        "venlafaxine", ...
        "duloxetine", ...
        "erenumab", ...
        "aimovig", ...
        "topiramate", ...
        "topamax", ...
        "amitriptyline", ...
        "nortriptyline"]);

    % Count as having a non-migraine medication if there are
    % medications present that are not simply "none"
    hasNonMigraine = ~(strcmp(strtrim(med),"none"));

    rowCounts = [hasNSAID ...
        hasAcetaminophen ...
        hasExcedrin ...
        hasTriptan ...
        hasGepant ...
        hasPreventive ...
        hasNonMigraine];

    if strcmpi(subjSummaryT.MigraineOrControl_(i),"migraine")
        countsMigraine = countsMigraine + rowCounts';
    elseif strcmpi(subjSummaryT.MigraineOrControl_(i),"control")
        countsControl = countsControl + rowCounts';
    end

end

summaryT = table(cats', ...
    countsMigraine, ...
    countsControl, ...
    'VariableNames', ...
    {'Category','Migraine','Control'});

medSummary = 2;

end

