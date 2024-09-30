function tedanaPreProcess(dataPath,dirName,subID,sesID,echoTimesMs,icaRejectSet,maskFile)
%
%
%
%{
    dataPath = fullfile(filesep,'Users','aguirre','Downloads','flywheel','gkaguirrelab','trigeminal');
    dirName = 'fprep';
    subID = '001';
    sesID = '20240923';
    acqSet = {...
        '_task-trigemlow_acq-multiecho_run-01',...
        '_task-trigemmed_acq-multiecho_run-01',...
        '_task-trigemhi_acq-multiecho_run-01'};
    echoTimesMs = [19.4,51.06,82.72];
    icaRejectSet = {[],[],[]};
    tedanaPreProcess(dataPath,dirName,subID,sesID,echoTimesMs,icaRejectSet,[]);
%}

% How many echoes do we have?
nEchoes = length(echoTimesMs);

% Paths to the routines we will run. Need to make this a more formal
% installation at some point
antsPath = fullfile(filesep,'Applications','ants-2.5.1-arm','bin',filesep);
tedanaPath = fullfile(filesep,'Users','aguirre','py39','bin','tedana');
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

% Get the xfms for MNI space
nameStem = ['sub-',subID,'_ses-',sesID];
xfmName_T12MNI = fullfile(repoAnatDir,[nameStem,'_from-T1w_to-MNI152NLin2009cAsym_mode-image_xfm.h5']);
xfmName_MNI2T1 = fullfile(repoAnatDir,[nameStem,'_from-MNI152NLin2009cAsym_to-T1w_mode-image_xfm.h5']);

% All files for this run start with this name
nameStemFuncSet = {...
    ['sub-',subID,'_ses-',sesID,'_task-trigemlow_acq-multiecho_run-'],...
    ['sub-',subID,'_ses-',sesID,'_task-trigemmed_acq-multiecho_run-'],...
    ['sub-',subID,'_ses-',sesID,'_task-trigemhi_acq-multiecho_run-']...
    };

for ff = 1: length(nameStemFuncSet)

    % Get the set of run indicies
    acqList = dir(fullfile(repoFuncDir,[nameStemFuncSet{ff} '*' '_from-boldref_to-T1w_mode-image_desc-coreg_xfm.txt']));
    runIdxVals = cellfun(@(x) str2double(x(strfind(x,'_run-')+6)),{acqList.name});
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
        fprintf('run-%02d \n',runIdxVals(jj));

        % Define the xfm names
        xfmName_scanner2T1 = fullfile(repoFuncDir,sprintf([nameStemFuncSet{ff},'%02d_from-boldref_to-T1w_mode-image_desc-coreg_xfm.txt'],runIdxVals(jj)));

        % If this is the first nameStem and first run, create a binary mask
        % that is in the functional space, using the fmriprep MNI mask
        if ff==1 && jj==1
            T1wRef = fullfile(repoAnatDir,[nameStem '_desc-preproc_T1w.nii.gz']);
            funcRef = fullfile(repoFuncDir,sprintf([nameStemFuncSet{ff},'%02d_echo-1_part-mag_desc-preproc_bold.nii.gz'],runIdxVals(jj)));
            maskSource = fullfile(repoAnatDir,[nameStem '_space-MNI152NLin2009cAsym_desc-brain_mask.nii.gz']);
            maskFileT1w = fullfile(repoAnatDir,[nameStem '_space-T1w_desc-brain_mask.nii.gz']);
            maskFile = fullfile(repoAnatDir,[nameStem '_space-boldref_desc-brain_mask.nii.gz']);
            command = [antsPath 'antsApplyTransforms'  ' -e 3 -i ' maskSource ' -r ' T1wRef ' -o ' maskFileT1w ' - t ' xfmName_MNI2T1 ];
            [returncode, outputMessages] = system(command);
            command = [antsPath 'antsApplyTransforms'  ' -e 3 -i ' maskFileT1w ' -r ' funcRef ' -o ' maskFile ' - t [ ' xfmName_scanner2T1 ' ,1]'];
            [returncode, outputMessages] = system(command);
        end

        % Run the tedana analysis
        command = [tedanaPath ' -d'];
        for ee = 1:nEchos
            command = [command ' ' fullfile(repoFuncDir,sprintf([nameStemFuncSet{ff},'%02d_echo-%d_part-mag_desc-preproc_bold.nii.gz'],runIdxVals(jj),ee))];
        end
        command = [command ' -e ' echoVals ' --gscontrol mir --out-dir ' fullfile(repoTdnaDir,sprintf('run-%02d',runIdxVals(jj))) ];
        command = [command ' --prefix ' sprintf([nameStemFuncSet{ff},'%02d'],runIdxVals(jj)) ];
        if ~isempty(maskFile)
            command = [command ' --mask ' maskFile];
        end
        [returncode, outputMessages] = system(command);
        
        % If we have been given a customized list of ICA components to reject,
        % prepare for the icaReclassifyPath operation
        rejectSet = icaRejectSet{runIdxVals(jj)};
        if ~isempty(rejectSet)

            % Load the tedana matrix output
            resultMetricsFile = fullfile(repoTdnaDir,sprintf('run-%02d',runIdxVals(jj)),sprintf([nameStemFuncSet{ff} '%02d_desc-tedana_metrics.tsv'],runIdxVals(jj)));
            T = readtable(resultMetricsFile, "FileType","text",'Delimiter', '\t');

            T.classification(rejectSet+1) = {'rejected'};
            accepted = find(strcmp(T.classification,'accepted'))-1;
            rejected = find(strcmp(T.classification,'rejected'))-1;

            % Reclassify based upon custom choices for accepted and rejected
            % components
            registryFile = fullfile(repoTdnaDir,sprintf('run-%02d',runIdxVals(jj)),sprintf([nameStemFuncSet{ff} '%02d_desc-tedana_registry.json'],runIdxVals(jj)));
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
            command = [command ' --out-dir ' fullfile(repoTdnaDir,sprintf('run-%02d',runIdxVals(jj))) ];
            command = [command ' --prefix ' sprintf([nameStemFuncSet{ff},'%02d'],runIdxVals(jj)) ];
            command = [command ' --prefix ' sprintf([nameStemFuncSet{ff},'%02d'],runIdxVals(jj)) ];
            command = [command ' ' registryFile ];
            [returncode, outputMessages] = system(command);
        end

        % Produce the tedana output in T1 space
        sourceFile = fullfile(repoTdnaDir,sprintf('run-%02d',runIdxVals(jj)),sprintf([nameStemFuncSet{ff} '%02d_desc-optcomDenoised_bold.nii.gz'],runIdxVals(jj)));
        refFile = targetFile;
        outFile = fullfile(repoTdnaDir,sprintf('run-%02d',runIdxVals(jj)),sprintf([nameStemFuncSet{ff} '%02d_space-T1_desc-optcomDenoised_bold.nii.gz'],runIdxVals(jj)));
        command = [antsPath 'antsApplyTransforms'  ' -e 3 -i ' sourceFile ' -r ' refFile ' -o ' outFile ' - t ' xfmName_scanner2T1 ];
        [returncode, outputMessages] = system(command);

    end % runs

end % name set

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
