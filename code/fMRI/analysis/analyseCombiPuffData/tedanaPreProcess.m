function tedanaPreProcess(dataPath,dirName,subID,sesID,icaRejectSet,createMaskFlag)
%
%
%
%{
    dataPath = fullfile(filesep,'Users','aguirre','Downloads');
    dirName = '65f1d142f84641b1153a9010';
    subID = '001';
    sesID = '20240312';
    icaRejectSet = {[],[13,14],[16],[5,12,15],[7]};
    createMaskFlag = false;
    tedanaPreProcess(dataPath,dirName,subID,sesID,icaRejectSet,createMaskFlag);
%}


% Paths to the routines we will run. Need to make this a more formal
% installation at some point
antsPath = fullfile(dataPath,'ants-2.5.1-arm','bin',filesep);
tedanaPath = fullfile(filesep,'Users','aguirre','.pyenv','shims','tedana');
icaReclassifyPath = fullfile(filesep,'Users','aguirre','.pyenv','shims','ica_reclassify');

% Silence a warning when we load tables
warnState = warning();
warning('off','MATLAB:table:ModifiedAndSavedVarnames');

% Define the repo directories
repoAnatDir = fullfile(dataPath,dirName,['sub-',subID],['ses-',sesID],'anat');
repoFuncDir = fullfile(dataPath,dirName,['sub-',subID],['ses-',sesID],'func');
repoFmapDir = fullfile(dataPath,dirName,['sub-',subID],['ses-',sesID],'fmap');

% Create a directory for tedana output
repoTdnaDir = fullfile(dataPath,dirName,['sub-',subID],['ses-',sesID],'tdna');
mkdir(repoTdnaDir);

% Get the xfms for MNI space, and for fsnative space
nameStem = ['sub-',subID,'_ses-',sesID];
xfmName_T12MNI = fullfile(repoAnatDir,[nameStem,'_from-T1w_to-MNI152NLin2009cAsym_mode-image_xfm.h5']);
xfmName_MNI2T1 = fullfile(repoAnatDir,[nameStem,'_from-MNI152NLin2009cAsym_to-T1w_mode-image_xfm.h5']);

% All files for this run start with this name
nameStemFunc = ['sub-',subID,'_ses-',sesID,'_task-trigem_acq-me_run-'];

% Get the set of run indicies
acqList = dir(fullfile(repoFuncDir,[nameStemFunc '*' '_from-T1w_to-scanner_mode-image_xfm.txt']));
runIdxVals = cellfun(@(x) str2double(x(strfind(x,'_run-')+5)),{acqList.name});
nRuns = length(runIdxVals);

% Handle an empty icaRejectSet
if isempty(icaRejectSet)
    icaRejectSet = repmat({[]},1,nRuns);
end

% Create a target image in the T1 space that has 2 mm spatial resolution
sourceFile = fullfile(repoAnatDir,[nameStem,'_desc-brain_mask.nii.gz']);    
targetFile = [tempname,'.nii.gz'];
command = [antsPath 'ResampleImage' ' 3 ' sourceFile ' ' targetFile ' 2x2x2 0'];
[returncode, outputMessages] = system(command);

% Loop over the acquisitions
for jj = 1:nRuns

    % Update the console
    fprintf('run-%d \n',runIdxVals(jj));

    % Define the xfm names
    xfmName_scanner2T1 = fullfile(repoFuncDir,sprintf([nameStemFunc,'%d_from-scanner_to-T1w_mode-image_xfm.txt'],runIdxVals(jj)));
    xfmName_T12Scanner = fullfile(repoFuncDir,sprintf([nameStemFunc,'%d_from-T1w_to-scanner_mode-image_xfm.txt'],runIdxVals(jj)));

    % Create a mask for tedana
    if createMaskFlag
    sourceFile = fullfile(repoAnatDir,[nameStem,'_desc-brain_mask.nii.gz']);    
    refFile = fullfile(repoFmapDir,[nameStem,'_acq-meSe_fmapid-auto00000_desc-epi_fieldmap.nii.gz']);
    maskFile = [tempname,'.nii.gz'];
    command = [antsPath 'antsApplyTransforms'  ' -e 3 -i ' sourceFile ' -r ' refFile ' -o ' maskFile ' - t ' xfmName_T12Scanner ];
    [returncode, outputMessages] = system(command);
    command = [antsPath 'ImageMath'  ' 3 ' maskFile ' ReplaceVoxelValue ' maskFile ' 0 0.25 0 '];
    [returncode, outputMessages] = system(command);
    command = [antsPath 'ImageMath'  ' 3 ' maskFile ' ReplaceVoxelValue ' maskFile ' 0.25 100 1 '];
    [returncode, outputMessages] = system(command);
    end

    %% NOTE
    % For some reason, the mask I am creating by the above process leads
    % TEDANA to give bad results. The mask substituted below is generated
    % by thresholding the fmap in MATLAB at a voxel value of 20. It is
    % possible that this mask would work if I created it following the same
    % algorithm but using ants. Not sure what makes this output behave so
    % differently from the mask generated above. need to invvestigate
    maskFile = fullfile(repoFmapDir,[nameStem,'_acq-meSe_fmapid-mask.nii.gz']);

    % Run the tedana analysis
    command = [tedanaPath ' -d'];
    for ee = 1:5
        command = [command ' ' fullfile(repoFuncDir,sprintf([nameStemFunc,'%d_echo-%d_desc-preproc_bold.nii.gz'],runIdxVals(jj),ee))];
    end
    command = [command ' -e 11.00 24.07 37.14 50.21 63.28 --gscontrol mir --out-dir ' fullfile(repoTdnaDir,sprintf('run-%d',runIdxVals(jj))) ];
    command = [command ' --prefix ' sprintf([nameStemFunc,'%d'],runIdxVals(jj)) ];
    if createMaskFlag
        command = [command ' --mask ' maskFile];
    end
    [returncode, outputMessages] = system(command);

    % If we have been given a customized list of ICA components to reject,
    % prepare for the icaReclassifyPath operation
    rejectSet = icaRejectSet{runIdxVals(jj)};
    if ~isempty(rejectSet)

        % Load the tedana matrix output
        resultMetricsFile = fullfile(repoTdnaDir,sprintf('run-%d',runIdxVals(jj)),sprintf([nameStemFunc '%d_desc-tedana_metrics.tsv'],runIdxVals(jj)));
        T = readtable(resultMetricsFile, "FileType","text",'Delimiter', '\t');

        T.classification(rejectSet+1) = {'rejected'};
        accepted = find(strcmp(T.classification,'accepted'))-1;
        rejected = find(strcmp(T.classification,'rejected'))-1;

        % Reclassify based upon custom choices for accepted and rejected
        % components
        registryFile = fullfile(repoTdnaDir,sprintf('run-%d',runIdxVals(jj)),sprintf([nameStemFunc '%d_desc-tedana_registry.json'],runIdxVals(jj)));
        command = [icaReclassifyPath ' -f '];

        if ~isempty(accepted)
            command = [command ' --manacc '];
            for kk = 1:length(accepted)
                command = [command sprintf('%d,',accepted(kk))];
            end
            command = command(1:end-1);
        end
        if ~isempty(rejected)
            command = [command ' --manrej '];
            for kk = 1:length(rejected)
                command = [command sprintf('%d,',rejected(kk))];
            end
            command = command(1:end-1);
        end
        command = [command ' --out-dir ' fullfile(repoTdnaDir,sprintf('run-%d',runIdxVals(jj))) ];
        command = [command ' --prefix ' sprintf([nameStemFunc,'%d'],runIdxVals(jj)) ];
        command = [command ' --prefix ' sprintf([nameStemFunc,'%d'],runIdxVals(jj)) ];
        command = [command ' ' registryFile ];
        [returncode, outputMessages] = system(command);
    end

    % Produce the tedana output in T1 space
    sourceFile = fullfile(repoTdnaDir,sprintf('run-%d',runIdxVals(jj)),sprintf([nameStemFunc '%d_desc-optcomDenoised_bold.nii.gz'],runIdxVals(jj)));
    refFile = targetFile;    
    outFile = fullfile(repoTdnaDir,sprintf('run-%d',runIdxVals(jj)),sprintf([nameStemFunc '%d_space-T1_desc-optcomDenoised_bold.nii.gz'],runIdxVals(jj)));
    command = [antsPath 'antsApplyTransforms'  ' -e 3 -i ' sourceFile ' -r ' refFile ' -o ' outFile ' - t ' xfmName_scanner2T1 ];
    [returncode, outputMessages] = system(command);

end

% Restore warning state
warning(warnState);

% Create mask files for GM and WM
gmMaskFileIn = fullfile(repoAnatDir,[nameStem,'_label-GM_probseg.nii.gz']);
gmMaskFileOut = fullfile(dataPath,dirName,[subID '_space-T1_label-GM_2x2x2.nii.gz']);
command = [antsPath 'ResampleImage' ' 3 ' gmMaskFileIn ' ' gmMaskFileOut ' 2x2x2 0 0 7'];
[returncode, outputMessages] = system(command);

wmMaskFileIn = fullfile(repoAnatDir,[nameStem,'_label-WM_probseg.nii.gz']);
wmMaskFileOut = fullfile(dataPath,dirName,[subID '_space-T1_label-WM_2x2x2.nii.gz']);
command = [antsPath 'ResampleImage' ' 3 ' wmMaskFileIn ' ' wmMaskFileOut ' 2x2x2 0 0 7'];
[returncode, outputMessages] = system(command);

end
