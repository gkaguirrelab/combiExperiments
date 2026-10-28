% Make the modulation spectrum figures for all directions
% Load preferences for combiLEDToolbox to use the plotModulation function
dropBoxBaseDir = getpref('combiLEDToolbox', 'dropboxBaseDir'); 

% Define modulation directions to loop through
modDirections = {'LightFlux', 'LMS', 'Mel', 'S_peripheral', 'LminusM_MelSilent_peripheral'};

% Define and create output directory for vector PDFs (dropBoxBaseDir already includes 'Sam Montoya')
figOutputDir = fullfile(dropBoxBaseDir, 'Montoya_2026_MelSquint', 'Figures', 'raw', 'ModulateSpectra');
if ~isfolder(figOutputDir)
    mkdir(figOutputDir);
end

% Loop through each modulation direction
for i = 1:length(modDirections)
    currentMod = modDirections{i};
    
    % Load the corresponding modResult file
    filePath = fullfile(dropBoxBaseDir, 'BLNK_data', 'PuffLight', 'modulate', 'BLNK_1001', ['modResult_', currentMod, '.mat']);
    loadedData = load(filePath);
    modResult = loadedData.modResult;
    
    % Figure out the max contrast achieved to accurately scale down to 40% of that
    photoContrast = modResult.contrastReceptorsBipolar(modResult.meta.whichReceptorsToTarget(1));
    modContrast = 0.4 / photoContrast;
    
    % Generate the plot
    plotModResult(modResult, true, false, modContrast);
    
    % Save as a vector PDF
    figFileName = fullfile(figOutputDir, ['ModulateSpectrum_', currentMod, '.pdf']);
    exportgraphics(gcf, figFileName, 'ContentType', 'vector');
    
    % Print confirmation of the saved path to the Command Window
    fprintf('Saved: %s\n', figFileName);
    
    % Close the figure window to free memory
    close(gcf);
end