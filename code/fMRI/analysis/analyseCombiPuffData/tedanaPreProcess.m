function tedanaPreProcess(dataPath,dirName,subID,sesID,acqSet,echoTimesMs,icaRejectSet)
%
%
%
%{
    dataPath = fullfile(filesep,'Users','aguirre','Downloads','flywheel','gkaguirrelab','trigeminal');
    dirName = 'fprep';
    subID = '001';
    sesID = '20240930';
    acqSet = {...
        '_task-trigem_acq-multiecho_run-01',...
        '_task-trigem_acq-multiecho_run-02',...
        '_task-trigem_acq-multiecho_run-03',...
        '_task-trigem_acq-multiecho_run-04',...
        '_task-trigem_acq-multiecho_run-05'...
        };
    echoTimesMs = [19.4,51.06,82.72];
    icaRejectSet = {...
        [15,16,18,38],...
        [3,5,7,14,49,50],...
        [1,20],...
        [1,4,8,22,23],...
        [9,22,60,61]...
        };
    tedanaPreProcess(dataPath,dirName,subID,sesID,acqSet,echoTimesMs,icaRejectSet);
%}

% How many echoes do we have?
nEchos = length(echoTimesMs);

% The nameStem
nameStem = ['sub-',subID,'_ses-',sesID];

% Paths to the routines we will run. Need to make this a more formal
% installation at some point
tedanaPath = fullfile(filesep,'Users','aguirre','py39','bin','tedana');
icaReclassifyPath = fullfile(filesep,'Users','aguirre','py39','bin','ica_reclassify');

% Silence a warning when we load tables
warnState = warning();
warning('off','MATLAB:table:ModifiedAndSavedVarnames');

% Define the repo directories
repoAnatDir = fullfile(dataPath,dirName,['sub-',subID],['ses-',sesID],'anat');
repoFuncDir = fullfile(dataPath,dirName,['sub-',subID],['ses-',sesID],'func');
repoMaskDir = fullfile(dataPath,dirName,['sub-',subID],['ses-',sesID],'mask');

% Create a directory for tedana output
repoTdnaDir = fullfile(dataPath,dirName,['sub-',subID],['ses-',sesID],'tdna');
mkdir(repoTdnaDir);

% Get the xfms for MNI space
xfm_T12MNI = fullfile(repoAnatDir,[nameStem,'_from-T1w_to-MNI152NLin2009cAsym_mode-image_xfm.h5']);

% Handle an empty icaRejectSet
if isempty(icaRejectSet)
    icaRejectSet = repmat({[]},1,length(acqSet));
end

% Loop through the acquisitions
for jj = 1: length(acqSet)

    % Update the console
    fprintf(['acquisition: ' nameStem acqSet{jj} '\n']);

    % Identify the mask for this acquisition
    maskFile = fullfile(repoMaskDir,[nameStem acqSet{jj} '_desc-brain_mask.nii.gz']);

    % Define some file paths
    outdir = fullfile(repoTdnaDir,[nameStem acqSet{jj}]);
    filePrefix = [nameStem acqSet{jj}];

    % Run the tedana analysis
    command = [tedanaPath ' -d'];
    for ee = 1:nEchos
        command = [command ' ' fullfile(repoFuncDir,sprintf([nameStem acqSet{jj},'_echo-%d_part-mag_desc-preproc_bold.nii.gz'],ee))];
    end
    command = [command ' -e ' num2str(echoTimesMs) ' --gscontrol mir --out-dir ' outdir ];
    command = [command ' --prefix ' filePrefix ];
    command = [command ' --mask ' maskFile];
    system(command);

    % If we have been given a customized list of ICA components to reject,
    % prepare for the icaReclassifyPath operation
    rejectSet = icaRejectSet{jj};
    if ~isempty(rejectSet)

        % Load the tedana matrix output
        resultMetricsFile = fullfile(outdir,[filePrefix '_desc-tedana_metrics.tsv']);
        T = readtable(resultMetricsFile, "FileType","text",'Delimiter', '\t');

        T.classification(rejectSet+1) = {'rejected'};
        accepted = find(strcmp(T.classification,'accepted'))-1;
        rejected = find(strcmp(T.classification,'rejected'))-1;

        % Reclassify based upon custom choices for accepted and rejected
        % components
        registryFile = fullfile(outdir,[filePrefix '_desc-tedana_registry.json']);
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

        command = [command ' --out-dir ' outdir ];
        command = [command ' --prefix ' filePrefix ];
        command = [command ' ' registryFile ];
        system(command);
    end

    % Move the tedana output to MNI space
    xfm_boldref2T1 = fullfile(repoFuncDir,[nameStem,acqSet{jj},'_from-boldref_to-T1w_mode-image_desc-coreg_xfm.txt']);
    boldrefFile = fullfile(repoFuncDir,[nameStem,acqSet{jj},'_part-mag_space-MNI152NLin2009cAsym_boldref.nii.gz']);
    sourceFile = fullfile(outdir,[nameStem,acqSet{jj},'_desc-optcomMIRDenoised_bold.nii.gz']);
    outfile = fullfile(repoFuncDir,[nameStem,acqSet{jj},'_space-MNI152NLin2009cAsym_desc-tdna_bold.nii.gz']);
    command = ['antsApplyTransforms -e 3 -i ' sourceFile ' -r ' boldrefFile ' -o ' outfile ' -t ' xfm_boldref2T1 ' -t ' xfm_T12MNI ];
    system(command);

end % acq set

% Restore warning state
warning(warnState);


end
