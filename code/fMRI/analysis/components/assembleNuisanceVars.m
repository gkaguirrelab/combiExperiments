function nuissanceVars = assembleNuisanceVars(rawDataPath,subID,sesID,acqSet,tr,nNoiseEPIs,covarFileNames,covarSet,stimulus,stimTime)

% Obtain the physio matrices for these runs
if ~isempty(rawDataPath)
    physioMatrix = returnPhysioMatrix(rawDataPath,subID,sesID,acqSet,tr,nNoiseEPIs);
else
    physioMatrix = repmat({[]},length(covarFileNames),1);
end

% Define the threshold for keeping PCA components
pcaThresh = 5;

% Create an HRF for convolution
[flobsbasis, mu] = returnFlobsVectors(stimTime{1}(2)-stimTime{1}(1));
hrf = flobsbasis*mu';
hrf = hrf/sum(abs(hrf));

% Loop through the set of acquisitions
for ii = 1: length(covarFileNames)

    % Load the covar tsv file
    T = readtable(covarFileNames{ii},'FileType','text','Delimiter','\t');

    % Extract and mean center the covariates
    thisMat = [];
    for jj = 1:length(covarSet)
        thisMat(jj,:) = T.(covarSet{jj});
    end
    thisMat = thisMat - mean(thisMat,2,'omitmissing');
    thisMat(isnan(thisMat(:))) = 0;
    thisMat = thisMat ./ std(thisMat,[],2);

    % Add in the physio components
    thisMat = [thisMat; physioMatrix{ii}];

    % Convolve and resample the stimulus matrix to the data domain
    dataTime = 0:tr:(size(thisMat,2)-1)*tr;
    thisStimulus = stimulus{ii};
    X = [];
    for jj = 1:size(thisStimulus,1)
        thisVec = thisStimulus(jj,:);
        if std(thisVec) > 0
            thisVec = conv2run(thisVec',hrf,ones(size(thisVec))');
            X(end+1,:) = interp1(stimTime{ii},thisVec,dataTime,'linear',0);
        end
    end

    % Regress the stimulus matrix from the nuisance components
    for jj = 1:size(thisMat,1)
        thisVec = thisMat(jj,:);
        b=X'\thisVec';
        thisMat(jj,:) = thisVec - b'*X;
    end

    % Perform a PCA decomposition of the nuisance components and just keep
    % the components that explain 100-pcaThresh% of the variance
    [coeff,~,~,~,explained] = pca(thisMat);
    thisMat=coeff(:,1:find(explained<pcaThresh,1)-1)';

    % Store this matrix
    nuissanceVars{ii} = thisMat;
end

close all

end