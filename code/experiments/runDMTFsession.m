% Run one session of the Delayed Match to Frequency experiment at a chosen
% background light level.
%
% A single session is composed of 10, alternating, 20 trial blocks of the
% L-M and LightFlux flicker modulations.
%

% Ask the operator what light level we will be using
NDlabelsAll = {'0x5','3x5'};
charSet = [97:97+25, 65:65+25];
fprintf('\nSelect the light level:\n')
for pp=1:length(NDlabelsAll)
    optionName=['\t' char(charSet(pp)) '. ' NDlabelsAll{pp} '\n'];
    fprintf(optionName);
end
choice = input('\nYour choice (return for done): ','s');
choice = int32(choice);
idx = find(charSet == choice);
NDlabel = NDlabelsAll{idx};

% Get the subject ID
subjectID = GetWithDefault('Subject ID','FLIC_xxxx');

% Define where the experimental files are saved
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
projectName = 'combiLED';
dropBoxSubDir = 'FLIC_data';
subjectDir = fullfile(...
    dropBoxBaseDir,...
    dropBoxSubDir,...,
    projectName,...
    subjectID);

% Generate the modResult files if they do not exist. We just look to see if
% the L-M direction has been created, as both the L-M and LightFlux are
% made at the same time.
if ~isfile(fullfile(subjectDir,['LightFlux' '_ND' NDlabel],'modResult.mat'))
    % Get the subject age
    observerAgeInYears = str2double(GetWithDefault('Age in years','22'));
    fprintf('Generating modulations for this subject...')
    generateModResulstForDMTF(subjectID,observerAgeInYears,NDlabel);
    fprintf('done.\n')
end

% Conduct the session
runDelayedMatchToFreq(subjectID,NDlabel);
