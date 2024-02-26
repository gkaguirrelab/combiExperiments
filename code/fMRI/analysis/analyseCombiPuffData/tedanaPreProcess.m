
% Basic properties of the data
dirNames = {'65da1a5ee843c3c62f739bdf','65da4a256da124f01b739bf1','65da51a06da124f01b739bf4'};
subIDs = {'001','001','001'};
sesIDs = {'20240222','20240213','20231114'};
nRuns = [5,2,5];

% Custom ICA component assignment
acceptSet{1,1} = [];
rejectSet{1,1} = [10 12];
acceptSet{1,2} = [];
rejectSet{1,2} = [1 7];
acceptSet{1,3} = [];
rejectSet{1,3} = [11 12 16];
acceptSet{1,4} = [];
rejectSet{1,4} = [9 13 15];
acceptSet{1,5} = [];
rejectSet{1,5} = [2 7 15];

acceptSet{2,1} = [];
rejectSet{2,1} = [0];
acceptSet{2,2} = [];
rejectSet{2,2} = [];

acceptSet{3,1} = [];
rejectSet{3,1} = [2 5 13 20];
acceptSet{3,2} = [];
rejectSet{3,2} = [2];
acceptSet{3,3} = [];
rejectSet{3,3} = [11 12 16];
acceptSet{3,4} = [5];
rejectSet{3,4} = [6 15];
acceptSet{3,5} = [];
rejectSet{3,5} = [1 9 13];

% Paths to the routines we will run
antsApplyTransformsPath = fullfile(filesep,'Users','aguirre','Downloads','ants-2.5.1-arm','bin','antsApplyTransforms');
tedanaPath = fullfile(filesep,'Users','aguirre','.pyenv','shims','tedana');
icaReclassifyPath = fullfile(filesep,'Users','aguirre','.pyenv','shims','ica_reclassify');

% Silence a warning when we load tables
warnState = warning();
warning('off','ModifiedAndSavedVarnames');

% Loop through the fmriprep repos
for ii = 1:length(dirNames)

    % Define the repo directories
    repoAnatDir = fullfile(filesep,'Users','aguirre','Downloads',dirNames{ii},['sub-',subIDs{ii}],['ses-',sesIDs{ii}],'anat');
    repoFuncDir = fullfile(filesep,'Users','aguirre','Downloads',dirNames{ii},['sub-',subIDs{ii}],['ses-',sesIDs{ii}],'func');
    repoFmapDir = fullfile(filesep,'Users','aguirre','Downloads',dirNames{ii},['sub-',subIDs{ii}],['ses-',sesIDs{ii}],'fmap');

    % Create a directory for tedana output
    repoTdnaDir = fullfile(filesep,'Users','aguirre','Downloads',dirNames{ii},['sub-',subIDs{ii}],['ses-',sesIDs{ii}],'tdna');
    mkdir(repoTdnaDir);

    % Get the xfms for MNI space
    nameStem = ['sub-',subIDs{ii},'_ses-',sesIDs{ii}];
    xfmName_T12MNI = fullfile(repoAnatDir,[nameStem,'_from-T1w_to-MNI152NLin2009cAsym_mode-image_xfm.h5']);
    xfmName_MNI2T1 = fullfile(repoAnatDir,[nameStem,'_from-MNI152NLin2009cAsym_to-T1w_mode-image_xfm.h5']);

    % Loop over the acquisitions
    for jj = 1:nRuns(ii)

        % Update the console
        fprintf('%d...%d \n',ii,jj);

        % All files for this run start with this name
        nameStemFunc = ['sub-',subIDs{ii},'_ses-',sesIDs{ii},'_task-trigem_acq-me_run-'];

        % Define the xfm names
        xfmName_scanner2T1 = fullfile(repoFuncDir,sprintf([nameStemFunc,'%d_from-scanner_to-T1w_mode-image_xfm.txt'],jj));
        xfmName_T12Scanner = fullfile(repoFuncDir,sprintf([nameStemFunc,'%d_from-T1w_to-scanner_mode-image_xfm.txt'],jj));

        % Create a mask for tedana
        sourceFile = fullfile(repoAnatDir,[nameStem,'_desc-brain_mask.nii.gz']);
        refFile = fullfile(repoFmapDir,[nameStem,'_acq-meSe_fmapid-auto00000_desc-epi_fieldmap.nii.gz']);
        maskFile = [tempname,'.nii.gz'];
        command = [antsApplyTransformsPath ' -e 3 -i ' sourceFile ' -r ' refFile ' -o ' maskFile ' - t ' xfmName_T12Scanner];
        [returncode, outputMessages] = system(command);

        % Run the tedana analysis
        command = [tedanaPath ' -d'];
        for ee = 1:5
            command = [command ' ' fullfile(repoFuncDir,sprintf([nameStemFunc,'%d_echo-%d_desc-preproc_bold.nii.gz'],jj,ee))];
        end
        command = [command ' -e 11.00 24.07 37.14 50.21 63.28 --out-dir ' fullfile(repoTdnaDir,sprintf('run-%d',jj)) ];
        command = [command ' --prefix ' sprintf([nameStemFunc,'%d'],jj) ];
        command = [command ' --mask ' maskFile];
        [returncode, outputMessages] = system(command);

        % Load the tedana matrix output
        resultMetricsFile = fullfile(repoTdnaDir,sprintf('run-%d',jj),sprintf([nameStemFunc '%d_desc-tedana_metrics.tsv'],jj));
        T = readtable(resultMetricsFile, "FileType","text",'Delimiter', '\t');

        % Adjust the accepted and rejected assignments
        T.classification(acceptSet{ii,jj}+1) = {'accepted'};
        T.classification(rejectSet{ii,jj}+1) = {'rejected'};
        accepted = find(strcmp(T.classification,'accepted'))-1;
        rejected = find(strcmp(T.classification,'rejected'))-1;

        % Reclassify based upon custom choices for accepted and rejected
        % components
        registryFile = fullfile(repoTdnaDir,sprintf('run-%d',jj),sprintf([nameStemFunc '%d_desc-tedana_registry.json'],jj));
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
        command = [command ' --out-dir ' fullfile(repoTdnaDir,sprintf('run-%d',jj)) ];
        command = [command ' --prefix ' sprintf([nameStemFunc,'%d'],jj) ];
        command = [command ' --prefix ' sprintf([nameStemFunc,'%d'],jj) ];
        command = [command ' ' registryFile ];
        [returncode, outputMessages] = system(command);

        % Produce the tedana output in MNI space
        sourceFile = fullfile(repoTdnaDir,sprintf('run-%d',jj),sprintf([nameStemFunc '%d_desc-optcomDenoised_bold.nii.gz'],jj));
        refFile = fullfile(repoFuncDir,sprintf([nameStemFunc,'%d_space-MNI152NLin2009cAsym_boldref.nii.gz'],jj));
        outFile = fullfile(repoTdnaDir,sprintf('run-%d',jj),sprintf([nameStemFunc '%d_space-MNI152NLin2009cAsym_desc-optcomDenoised_bold.nii.gz'],jj));
        command = [antsApplyTransformsPath ' -e 3 -i ' sourceFile ' -r ' refFile ' -o ' outFile ' - t ' xfmName_scanner2T1 ' ' xfmName_T12MNI];
        [returncode, outputMessages] = system(command);

    end

end

% Restore warning state
warning(warnState);


