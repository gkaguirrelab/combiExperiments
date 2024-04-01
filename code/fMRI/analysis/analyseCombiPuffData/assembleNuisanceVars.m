function nuissanceVars = assembleNuisanceVars(fwSessID,runIdxSet,tr,covarFileNames,covarSet)

% Obtain the physio matrices for these runs
if ~isempty(fwSessID)
    physioMatrix = returnPhysioMatrix(fwSessID,tr,runIdxSet);
else
    physioMatrix = repmat({[]},length(covarFileNames),1);
end

pcaThresh = 5;

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

    % Perform a PCA decomposition of the nuisance components and just keep
    % the components that explain 97.5% of the variance
    [coeff,~,~,~,explained] = pca(thisMat);
    thisMat=coeff(:,1:find(explained<pcaThresh,1)-1)';

    % Store this matrix
    nuissanceVars{ii} = thisMat;
end

close all

end