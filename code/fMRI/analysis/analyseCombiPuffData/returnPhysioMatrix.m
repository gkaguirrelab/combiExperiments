function [physioMatrix,fileNameStem] = returnPhysioMatrix(fwSessID,tr,runIdxSet)

%{
    fwSessID = '65f083a829fdb99849fa2e95';
    tr = 2.040;
    runIdxSet = [2,3,4,5];
    [physioMatrix,fileNameStem] = returnPhysioMatrix(fwSessID,tr,runIdxSet);
%}


% Create a flywheel object and get the acquisition list
fw = flywheel.Flywheel(getpref('flywheelMRSupport','flywheelAPIKey'));
acquisitionList = fw.getSessionAcquisitions(fwSessID);

% Identify a temp directory
workDir = tempdir();

% Step through the acquisitions, find the physio files, download the physio
% dicom
fileNameStem = [];
nPhysioFiles = 0;
for ii = 1:length(acquisitionList)

    % Check the acquisition label for the physio suffix
    label = acquisitionList{ii}.label;
    if contains(label,'_PhysioLog')

        % Get the "run" index for this acquisition
        runIdx = str2double(label(strfind(label,'_acq-')+5));

        % If this runIdx is a member of runIdxSet, then continue
        if ismember(runIdx,runIdxSet)

            % Increment the total number of physio files we have found
            nPhysioFiles = nPhysioFiles+1;

            % Download the physio DICOM from Flywheel
            fileName = acquisitionList{ii}.files{1}.name;
            savePath = fullfile(workDir,fileName);
            fw.downloadFileFromAcquisition(acquisitionList{ii}.id,fileName,savePath);

            % Convert the DICOM to ".log" physio files
            dicomInfo = readCMRRPhysio(savePath, 0, workDir);

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
            fileNameStem{runIdx} = strrep(savePath,'.dcm','');

            % Create a "tapasStruct" that has the information needed for the
            % tapas routine
            saveDir = fullfile(workDir,fileNameStem{nPhysioFiles});
            tapasStruct = createTapasStruct(saveDir,fileOutPULS,fileOutInfo,tr,nScans,nSlices);

            % Call the tapas analysis
            physioStruct = tapas_physio_main_create_regressors(tapasStruct);

            % Mean center and standardize the elements of the R matrix
            R = physioStruct.model.R;
            R = R - mean(R,1);
            R = R ./ std(R,[],1);

            % Transpose and save the returned covariates into a cell array
            physioMatrix{runIdx} = R';

        end
    end
end

% Drop the empty cells
goodIdx = cellfun(@(x) ~isempty(x),physioMatrix);
physioMatrix = physioMatrix(goodIdx);
fileNameStem = fileNameStem(goodIdx);

% Delete the fw object
delete(fw);

end