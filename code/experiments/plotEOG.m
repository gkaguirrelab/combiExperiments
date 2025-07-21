function  plotEOG(subjectID, refFreqSetHz, modDirections, targetPhotoContrast, NDLabel)
% % Function to plot the data for EOG during trials  
% % e.g.,
%{

    subjectID = 'FLIC_0005';
    refFreqSetHz = [3.0000, 4.8206, 7.746, 12.4467, 20.0000];
    modDirections = {'LminusM_wide' 'LightFlux'};
    targetPhotoContrast = [0.025, 0.10; 0.075, 0.30];  % [Low contrast levels; high contrast levels] 
            % L minus M is [0.025, 0.075] and Light Flux is [0.10, 0.30]
    NDLabel = {'0x5'};
    plotEOG(subjectID, refFreqSetHz, modDirections, targetPhotoContrast, NDLabel);
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
                nTrials = size(questData.trialData,1);
                figure 
                hold on

                cols = ceil(sqrt(nTrials));
                rows = ceil(nTrials / cols);

                %Create tiled layout
                tiled = tiledlayout(rows, cols);
                title(tiled, ['EOG ' modDirectionsLabels{directionIdx} ' ' num2str(refFreqSetHz(freqIdx)) ' ' num2str(targetPhotoContrast(contrastIdx, directionIdx)) ' ' stimParamLabels{sideIdx}])
                for trialIdx = 1:nTrials
                    nexttile;
                    plot(psychObj.questData.trialData(trialIdx).EOGdata1.timebase, psychObj.questData.trialData(trialIdx).EOGdata1.response)
                title(['Trial ' num2str(trialIdx)])
                end

            end % sides
        end % contrast
    end %frequencies
end % mod direction


end