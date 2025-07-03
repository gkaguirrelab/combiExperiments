function CalcDCPTDiscrimBonus(subjectID, refFreqSetHz, modDirections, targetPhotoContrast, NDLabel)
% % Function to plot a single psychometric curve, combining the high and low side data.  
% % e.g.,
%{

    subjectID = 'HERO_kik';
    refFreqSetHz = [3.0000, 4.8206, 7.746, 12.4467, 20.0000];
    modDirections = {'LminusM_wide' 'LightFlux'};
    targetPhotoContrast = [0.025, 0.10; 0.075, 0.30];  % [Low contrast levels; high contrast levels] 
            % L minus M is [0.025, 0.075] and Light Flux is [0.10, 0.30]
    NDLabel = {'0x5'};
    CalcDCPTDiscrimBonus(subjectID, refFreqSetHz, modDirections, targetPhotoContrast, NDLabel);
%}

dropBoxBaseDir=getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir='FLIC_data';
projectName='combiLED';
experimentName = 'DCPT';

% Set the labels for the high and low stimulus ranges
stimParamLabels = {'low', 'hi'};
modDirectionsLabels = {'LminusM', 'LightFlux'}; % to be used only for the title

% Set number of contrast levels and sides
nContrasts = 2;
nSides = 2;

% Define the modulation and data directories
subjectDir = fullfile(...
    dropBoxBaseDir,...
    dropBoxSubDir,...
    projectName,...
    subjectID);

%% Plot the full psychometric functions
totalCorrect = 0;

for directionIdx = 1:length(modDirections)
    for freqIdx = 1:length(refFreqSetHz)
        dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDLabel{1} '_shifted'],experimentName);
        for contrastIdx = 1:nContrasts
            psychObjArray = {};
            for sideIdx = 1:nSides

                % Load this measure
                psychFileStem = [subjectID '_' modDirections{directionIdx} ...
                    '_' experimentName...
                    '_cont-' strrep(num2str(targetPhotoContrast(contrastIdx, directionIdx)),'.','x') ...
                    '_refFreq-' num2str(refFreqSetHz(freqIdx)) 'Hz' ...
                    '_' stimParamLabels{sideIdx}];
                filename = fullfile(dataDir,psychFileStem);
                load(filename,'psychObj');

                % Store some of these parameters
                questData = psychObj.questData;
                stimParamsDomainList = psychObj.stimParamsDomainList;
                psiParamsDomainList = psychObj.psiParamsDomainList;
                nTrials = length(psychObj.questData.trialData);

                % Get the proportion selected "test" the most recent
                % sessionn (5 trials of each condition per session)
                %correct = [questData.trialData(end-4:end).correct];
                correct = [questData.trialData(1:5).correct];
                nCorrect = sum(correct);
                totalCorrect = totalCorrect + nCorrect;
            end
        end
    end
end

pCorrect = totalCorrect/(length(correct)*length(modDirections)*length(refFreqSetHz)*nContrasts*nSides);
bonusDollars = totalCorrect*.05;

fprintf('You achieved %d percent correct on this session. Your bonus is $ %.2f !', round(pCorrect*100), bonusDollars)

end

