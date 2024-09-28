function [data,templateImage,W] = parseDataFiles(dataFileNames,smoothSD,maskFiles)
% Loads data files produced by fmriprep
%

% Load the maskVols
for ii = 1:length(maskFiles)
    thisMask = MRIread(maskFiles{ii});
    thisVol = thisMask.vol;
    if ii == 1
        W = thisVol;
    else
        W = W + thisVol;
    end
end
W(W>1)=1;
W(W<0.5)=0;

% Loop over datafiles and load them
data = [];
for nn = 1:length(dataFileNames)

    fprintf(['preparing ' dataFileNames{nn} '...']);

    % Load the data
    fileName = escapeFileCharacters(dataFileNames{nn});
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

    % This is the simple Gaussian smoothing
    %{
    smoothSize = round((smoothSD*3)/2)*2+1;
    if smoothSD > 0
        for ii = 1:size(thisAcqData,4)
            vol = squeeze(thisAcqData(:,:,:,ii));
            vol = smooth3(vol,'gaussian',smoothSize,smoothSD);
            thisAcqData(:,:,:,ii) = vol;
        end
    end
    %}

    % Smooth the data in space. This is the fancy smoothing that does not
    % blend in points that are not within the mask.
    if smoothSD > 0
        % Identify the voxels that at any point have an intensity value of
        % zero, and remove them from the mask
        noDataIdx = any(thisAcqData==0,4);
        thisW = W;
        thisW(noDataIdx) = 0;
        parfor ii = 1:size(thisAcqData,4)
            vol = squeeze(thisAcqData(:,:,:,ii));
            vol(thisW==0) = nan;
            vol = smoothn(vol,thisW,smoothSD);
            vol(thisW==0) = 0;
            thisAcqData(:,:,:,ii) = vol;
        end
    end

    % Convert from 3D to vector
    thisAcqData = single(thisAcqData);
    thisAcqData = reshape(thisAcqData, [size(thisAcqData,1)*size(thisAcqData,2)*size(thisAcqData,3), size(thisAcqData,4)]);
    thisAcqData(isnan(thisAcqData)) = 0;

    % Convert to proportion change
    meanVec = mean(thisAcqData,2);
    thisAcqData = 100.*((thisAcqData-meanVec)./meanVec);
    thisAcqData(isnan(thisAcqData)) = 0;
    thisAcqData(isinf(thisAcqData)) = 0;

    % Store the acquisition data in a cell array
    data{nn} = thisAcqData;

    fprintf('\n');

end


end