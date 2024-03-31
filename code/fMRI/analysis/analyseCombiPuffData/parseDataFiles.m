function [data,templateImage,W] = parseDataFiles(rawDataPath,dataFileNames,smoothSD,gmMaskFile,wmMaskFile)
% Loads data files produced by fmriprep
%

voxelMeanThresh = 1000;

% Load the maskVol
gmMask = MRIread(gmMaskFile);
gmMask = gmMask.vol;
wmMask = MRIread(wmMaskFile);
wmMask = wmMask.vol;
W = gmMask+wmMask;

% Loop over datafiles and load them
data = [];
for nn = 1:length(dataFileNames)

    % Load the data
    fileName = fullfile(rawDataPath,dataFileNames{nn});
    fileName = escapeFileCharacters(fileName);
    thisAcqData = MRIread(fileName);

    % Check if this is the first acquisition. If so, retain an
    % example of the source data to be used as a template to format
    % the output files.
    if nn == 1
        templateImage = thisAcqData;
        templateImage.vol = squeeze(templateImage.vol(:,:,:,1));
        templateImage.nframes = 1;
    end
    thisAcqData = thisAcqData.vol;

    % Smooth the data in space
    if smoothSD > 0
        parfor ii = 1:size(thisAcqData,4)
            vol = squeeze(thisAcqData(:,:,:,ii));
            vol(W==0)=nan;
            vol = smoothn(vol,W,smoothSD);
            vol(W==0)= 0;
            thisAcqData(:,:,:,ii) = vol;
        end
    end

    % Convert to proportion change
    voxelMean = mean(thisAcqData,4);
    voxelMean(voxelMean < voxelMeanThresh) = 0;
    thisAcqData = (thisAcqData - voxelMean)./voxelMean;
    thisAcqData(isnan(thisAcqData)) = 0;
    thisAcqData(isinf(thisAcqData)) = 0;

    % Convert from 3D to vector
    thisAcqData = single(thisAcqData);
    thisAcqData = reshape(thisAcqData, [size(thisAcqData,1)*size(thisAcqData,2)*size(thisAcqData,3), size(thisAcqData,4)]);

    % Store the acquisition data in a cell array
    data{nn} = thisAcqData;

end

end