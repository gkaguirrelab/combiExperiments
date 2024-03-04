function physioMatrix = returnPhysioMatrix(fwSessID)

%{
fwSessID = '6553f6199caa786dfb1b24b6';
physioMatrix = returnPhysioMatrix(fwSessID)

%}


% Create a flywheel object and get the acquisition list
fw = flywheel.Flywheel(getpref('flywheelMRSupport','flywheelAPIKey'));
acquisitionList = fw.getSessionAcquisitions(fwSessID);

% Download the acquisitions; skip over the Phoenix file
acqIdx = [7:21,23:25];
nAcq = length(acqIdx);
for ii = 1:nAcq
    acquisitionId{ii} = acquisitionList{acqIdx(ii)}.id;
    fileID = acquisitionList{acqIdx(ii)}.files{3}.fileId;
    fileName{ii} = acquisitionList{acqIdx(ii)}.files{3}.name;
    savePath = fullfile(saveDir,fileName{ii});
    % fw.downloadFileFromAcquisition(acquisitionId{ii},fileName{ii},savePath);
end


end