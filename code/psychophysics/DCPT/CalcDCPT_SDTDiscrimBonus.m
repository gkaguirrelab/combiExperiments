function CalcDCPT_SDTDiscrimBonus(subjectID, refFreqSetHz, modDirections, targetPhotoContrast, NDLabel)
% % Function to calculate the bonus for the most recent session (200 trials)  
% % e.g.,
%{

    subjectID = 'FLIC_0017';
    refFreqSetHz = logspace(log10(10),log10(30),5);
    modDirections = {'LightFlux'};
    targetPhotoContrast = [0.10; 0.30];  % [Low contrast levels; high contrast levels] 
    NDLabel = {'0x5'};
    CalcDCPT_SDTDiscrimBonus(subjectID, refFreqSetHz, modDirections, targetPhotoContrast, NDLabel);
%}

dropBoxBaseDir=getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir='FLIC_data';
projectName='combiLED';
experimentName = 'DCPT_SDT';

% Set the labels for the high and low stimulus ranges
stimParamLabels = {'low', 'hi'};
modDirectionsLabels = {'LightFlux'}; % to be used only for the title

% Set number of contrast levels and sides
nContrasts = 2;
nSides = 2;

% Define the modulation and data directories
subjectDir = fullfile(...
    dropBoxBaseDir,...
    dropBoxSubDir,...
    projectName,...
    subjectID);

%% calculate percent correct and bonus in a series of nested loops
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
                % sessionn (20 trials of each condition per session)
                correct = [questData.trialData(end-19:end).correct];
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

