
% Housekeeping
clear
close all

% Whole brain or one voxel?
fitOneVoxel = false;

% The smoothing kernel for the fMRI data in space
smoothSD = 0;

% The polynomial degree used for high-pass filtering of the timeseries
polyDeg = 1;

% Set the typicalGain, which is about 0.1 as we have converted the data to
% proportion change
typicalGain = 0.1;

% Basic properties of the data
dirNames = {'65da1a5ee843c3c62f739bdf','65da4a256da124f01b739bf1'};%,'65da51a06da124f01b739bf4'};
subIDs = {'001','001','001'};
sesIDs = {'20240222','20240213','20231114'};
trVals = [2140,2140,2040];
nRuns = [5,2,5];
nAcqs = sum(nRuns);

% Define the top-level data directory
rawDataPath = fullfile(filesep,'Users','aguirre','Downloads');

% Define a place to save the results
saveDir = rawDataPath;

% Create the list of filenames and the vector of trs
tr = 2140;
dataFileNames = {};
for ii=1:length(dirNames)
    for jj = 1:nRuns(ii)
        nameStemFunc = ['sub-',subIDs{ii},'_ses-',sesIDs{ii},'_task-trigem_acq-me_run-'];
        dataFileNames{end+1} = fullfile(...
            dirNames{ii},...
            ['sub-',subIDs{ii}],['ses-',sesIDs{ii}],'tdna',...
            sprintf('run-%d',jj),sprintf([nameStemFunc '%d_space-MNI152NLin2009cAsym_desc-optcomDenoised_bold.nii.gz'],jj));
    end
end

% Load the data
[data,templateImage] = parseDataFiles(rawDataPath,dataFileNames,smoothSD);

% Create the stimulus description
[stimulus,stimTime,stimLabels] = makeStimMatrix(nAcqs);

% Pick the voxels to analyze
xyz = templateImage.volsize;
if fitOneVoxel
    % A single voxel
    vxs = 4532740;
    averageVoxels = false;
    for ii = 1:nAcqs
        subData{ii} = data{ii}(4532740,:);
    end
    vxs = 1;
else
    % Create a mask of brain voxels
    brainThresh = 2000;
    vxs = find(reshape(templateImage.vol, [prod(xyz), 1]) > brainThresh);
    averageVoxels = false;
end

% Create the model opts, which includes stimLabels and typicalGain. The
% paraSD key-value controls how varied the HRF solutions can be. A value of
% 3 is fairly conservative and will keep the HRFs close to a canonical
% shape. This is necessary for the current experiment as the stimulus
% sequence does not uniquely constrain the temporal delay in the HRF.
modelOpts = {'stimLabels',stimLabels,'typicalGain',typicalGain,'paraSD',3,'polyDeg',polyDeg};

% Define the modelClass
modelClass = 'glm';

% Call the forwardModel
results = forwardModel(subData,stimulus,tr,...
    'stimTime',stimTime,...
    'vxs',vxs,...
    'averageVoxels',averageVoxels,...
    'verbose',true,...
    'modelClass',modelClass,...
    'modelOpts',modelOpts);

% Show the results figures
figFields = fieldnames(results.figures);
if ~isempty(figFields)
    for ii = 1:length(figFields)
        figHandle = struct2handle(results.figures.(figFields{ii}).hgS_070000,0,'convert');
        figHandle.Visible = 'on';
    end
end

% Save some files if we processed the whole brain
if ~fitOneVoxel

    % Save the results
    fileName = fullfile(saveDir,[subjectID '_trigemResults.mat']);
    save(fileName,'results');

    % Save the template image
    fileName = fullfile(saveDir,[subjectID '_epiTemplate.nii']);
    MRIwrite(templateImage, fileName);

    % Save a map of R2 values
    newImage = templateImage;
    volVec = results.R2;
    volVec(isnan(volVec)) = 0;
    newImage.vol = reshape(volVec,xyz(1),xyz(2),xyz(3));
    fileName = fullfile(saveDir,[subjectID '_trigem_R2.nii']);
    MRIwrite(newImage, fileName);

end