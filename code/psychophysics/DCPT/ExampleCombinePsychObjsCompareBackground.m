
close all
clear

dataDir =  '/Users/samanthamontoya/Aguirre-Brainard Lab Dropbox/Sam Montoya/FLIC_data/combiLED';
subjectList = {'FLIC_0015','FLIC_0017','FLIC_0018','FLIC_0021'};
contrastLabels = {'cont-0x1','cont-0x3'};
backgroundLabels = {'LightFlux_ND0x5_shifted','LightFlux_ND3x0_shifted'};

for bb = 1:length(backgroundLabels)
    objFileCellArray = {};
    for ss = 1:length(subjectList)
        % Get the list of objects at high and low light levels, at the high and
        % low sides of the discrimination function, for this contrast level
        mList = dir(fullfile(dataDir,subjectList{ss},backgroundLabels{bb},'DCPT_SDT',[subjectList{ss} '*mat']));
        tmp = arrayfun(@(x) fullfile(x.folder,x.name),mList,'UniformOutput',false);
        objFileCellArray = [objFileCellArray; tmp];
    end
    % Load the first psychometric object so we have a method to call
    load(objFileCellArray{1},"psychObj");

    % Make the combination plot
    psychObj.plotOutcomeCombined(objFileCellArray);

end
