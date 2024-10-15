function [physioMatrix,fileNameStem] = returnPhysioMatrix(rawDataPath,subID,sesID,acqSet,tr,nNoiseEPIs)

%{
    rawDataPath = '/Users/aguirre/Downloads/flywheel/gkaguirrelab/trigeminal/';
    subID = '001';
    sesID = '20240923';
    acqSet = {...
        '_task-trigemmed_acq-multiecho_run-01',...
        '_task-trigemhi_acq-multiecho_run-01',...
        '_task-trigemlow_acq-multiecho_run-01'...
    };
    tr = 2.87;
    nNoiseEPIs = 2;
    [physioMatrix,fileNameStem] = returnPhysioMatrix(rawDataPath,subID,sesID,acqSet,tr,nNoiseEPIs);
%}

% Identify a temp directory
workDir = tempdir();

% Step through the acquisitions, find the physio files, download the physio
% dicom
fileNameStem = [];
for ii = 1:length(acqSet)

    % Get the list of directory names within the raw data directory
    rawDir = fullfile(rawDataPath,subID,sesID{ii});
    acquisitionLabels = dir(rawDir);
    acquisitionLabels = {acquisitionLabels.name};

    % To be the physio file for our target acquisition, the label of the
    % acquisition must contain all of these tags
    tags = split(acqSet{ii},'_');
    tags = tags(cellfun(@(x) ~isempty(x),tags));
    tags = [tags;'func';'PhysioLog'];

    % Find an acquisition that satisfies all of these
    tagTestFunc = @(thisLabel) all(arrayfun(@(thisTag) contains(thisLabel, thisTag), tags));
    acqMatches = cellfun(@(x) tagTestFunc(x),acquisitionLabels);

    % Make sure that we have one and only one match
    if sum(acqMatches)>1
        error('There is more than one matching physio file')
    end
    if sum(acqMatches)==0
        error('Cannot find matching physio file')
    end
    physioIdx = find(acqMatches);

    % Download the physio DICOM from Flywheel
    fileName = [acquisitionLabels{physioIdx} '.dcm'];
    rawPhysioPath = fullfile(rawDir,acquisitionLabels{physioIdx},fileName);

    % Convert the DICOM to ".log" physio files
    dicomInfo = readCMRRPhysio(rawPhysioPath, 0, workDir);

    % Extract some information about the acquisition to be used later
    % for the tapas analysis
    nScans = size(dicomInfo.SliceMap,2);
    nSlices = size(dicomInfo.SliceMap,3);

    % Rename the PULS and Info files to have the same prefix as the
    % acquisition name
    tmp = dir(fullfile(workDir,['*' dicomInfo.UUID{1} '_Info.log']));
    fileIn = fullfile(tmp.folder,tmp.name);
    fileOutInfo = fullfile(workDir,strrep(fileName,'_PhysioLog.dcm','_PhysioLog_Info.log'));
    movefile(fileIn,fileOutInfo);
    tmp = dir(fullfile(workDir,['*' dicomInfo.UUID{1} '_PULS.log']));
    fileIn = fullfile(tmp.folder,tmp.name);
    fileOutPULS = fullfile(workDir,strrep(fileName,'_PhysioLog.dcm','_PhysioLog_PULS.log'));
    movefile(fileIn,fileOutPULS);

    % Store the file path and stem name of these physio log files
    fileNameStem{ii} = strrep(rawPhysioPath,'.dcm','');

    % Create a "tapasStruct" that has the information needed for the
    % tapas routine
    saveDir = fullfile(workDir,fileNameStem{ii});
    tapasStruct = createTapasStruct(saveDir,fileOutPULS,fileOutInfo,tr,nScans,nSlices);

    % Call the tapas analysis
    physioStruct = tapas_physio_main_create_regressors(tapasStruct);

    % Mean center and standardize the elements of the R matrix
    R = physioStruct.model.R;
    R = R - mean(R,1);
    R = R ./ std(R,[],1);

    % Remove the end TRs that corresponds to noRF noise acquisitions, and
    % thus do not have a corresponding BOLD fMRI TR
    R = R(1:end-nNoiseEPIs,:);

    % Transpose and save the returned covariates into a cell array
    physioMatrix{ii} = R';

end

end