function applyNordic(dataPath,dirName,subID,sesID,acqSet,nNoiseEPIs,nEchoes)
% Apply the NORDIC pre-processing step to the fMRI data.
%
% The data from multiple echos are z-concatenated prior to being passed to
% NORDIC, following the approach described here:
%   Marco Flores-Coronado & Cesar Caballero-Gaudes. Hydra Nordic: A
%   thermal-noise removal strategy for multi-echo fMRI. 2024 OHBM
%   Conference. Poster 1698.
%
% Examples:
%{
    dataPath = fullfile(filesep,'Users','aguirre','Downloads','flywheel','gkaguirrelab','trigeminal');
    dirName = 'dset';
    subID = '001';
    sesID = '20240930';
    acqSet = {...
        '_task-trigem_acq-multiecho_run-01',...
        '_task-trigem_acq-multiecho_run-02',...
        '_task-trigem_acq-multiecho_run-03',...
        '_task-trigem_acq-multiecho_run-04',...
        '_task-trigem_acq-multiecho_run-05'...
        };
    nEchoes = 3;
    nNoiseEPIs = 2;
    applyNordic(dataPath,dirName,subID,sesID,acqSet,nNoiseEPIs,nEchoes);
%}


% Define the path to the afni executables (HACK -- this should be all
% configured in setupEnv.m)
afniPath = '~/Downloads/mebold-curation-main/bin/afni/';

% Define the nameStem for this subject / session
nameStem = ['sub-',subID,'_ses-',sesID];

% Define the directories
repoFuncDir = fullfile(dataPath,dirName,['sub-',subID],['ses-',sesID],'func');
repoNordDir = fullfile(dataPath,dirName,['sub-',subID],['ses-',sesID],'nord');
repoOrigDir = fullfile(dataPath,dirName,['sub-',subID],['ses-',sesID],'funcOrig');
mkdir(repoNordDir);
mkdir(repoOrigDir);

% Define the labels for the mag and phase data
partLabels = {'_part-mag_bold','_part-phase_bold'};

% Set ARGbase as recommended for fMRI
% set to 0 if input includes both magnitude + phase timeseries
ARG.magnitude_only = 0;
% save out the phase data too
ARG.make_complex_nii = 1;
% set to 1 for fMRI
ARG.temporal_phase = 1;
% set to 1 to enable NORDIC denoising
ARG.NORDIC = 1;
% use 10 for fMRI
ARG.phase_filter_width = 10;
% set equal to number of noise frames at end of scan, if present
ARG.noise_volume_last = nNoiseEPIs;
% DIROUT may need to be separate from fn_out
ARG.DIROUT = tempdir();
% Save a matlab file
ARG.save_add_info = 1;

% Loop over the acquisitions
for ii = 1:length(acqSet)

    % Identify filenames for each of the echos for the mag and phase data
    for pp = 1:length(partLabels)
        % Define a location to save the z-concatenated file from the set
        % acquisitions across echoes
        concatFilePaths{pp} = fullfile(ARG.DIROUT,[nameStem acqSet{ii} partLabels{pp} '_desc-zcat.nii.gz']);
        % Assemble a command
        command = [afniPath '3dZcat -prefix ' concatFilePaths{pp} ' ' ];
        % Loop over the echoes
        for ee = 1:nEchoes
            % The path to the source file
            acqFileNames{pp,ee} = ...
                sprintf([nameStem acqSet{ii} '_echo-%d' partLabels{pp} '.nii.gz'],ee);
            acqFileNamesNoZip{pp,ee} = ...
                sprintf([nameStem acqSet{ii} '_echo-%d' partLabels{pp} '.nii'],ee);
            % The growing 3dZcat command
            command = [command fullfile(repoFuncDir,acqFileNames{pp,ee}) ' '];
            % Get the number of z-slices for this acquisition
            niftiToolCommand = [afniPath 'nifti_tool -disp_hdr -field dim -quiet -infiles ' fullfile(repoFuncDir,acqFileNames{pp,ee})];
            [~,sysOutput] = system(niftiToolCommand);
            sysOutput = split(sysOutput,' ');
            nZslices(pp,ee) = str2double(sysOutput{4});
        end
        % Create the z-cat file
        system(command);
        % Assign these parts to the NORDIC input
        if contains(partLabels{pp},'mag')
            fn_magn_in = concatFilePaths{pp};
        end
        if contains(partLabels{pp},'phase')
            fn_phase_in = concatFilePaths{pp};
        end
    end

    % Confirm that there is the same number of zSlices in all acquisitions
    nZslices = unique(nZslices);
    if length(nZslices)>1
        error('The echos or phase and mag acquisitions vary in the size of the z-dimension');
    end

    % Define a name for the output
    fn_out = [nameStem acqSet{ii} '_desc-zcat'];

    % Call NORDIC on the input files
    NIFTI_NORDIC(fn_magn_in, fn_phase_in, fn_out, ARG);

    % Move the .mat result file to the repoNordDir
    matResultFile = [fn_out '.mat'];
    movefile(fullfile(ARG.DIROUT,matResultFile),fullfile(repoNordDir,matResultFile))

    % Z-split the nordic output
    for pp = 1:length(partLabels)
        % Identify the nordic, concatenated output file
        if contains(partLabels{pp},'mag')
            zCatFile = fullfile(ARG.DIROUT,[nameStem acqSet{ii} '_desc-zcatmagn.nii']);
        end
        if contains(partLabels{pp},'phase')
            zCatFile = fullfile(ARG.DIROUT,[nameStem acqSet{ii} '_desc-zcatphase.nii']);
        end
        % Loop over the echoes
        for ee = 1:nEchoes
            % Move the original func acquisition
            movefile(fullfile(repoFuncDir,acqFileNames{pp,ee}),fullfile(repoOrigDir,acqFileNames{pp,ee}));
            % Split off the Z slices for this acquisition into the "temp"
            % dir, as we will update the header of this file in a moment
            a = 0 + (ee-1)*nZslices;
            b = ee*nZslices-1;
            command = sprintf([afniPath '3dZcutup -keep %d %d -prefix ' fullfile(ARG.DIROUT,acqFileNamesNoZip{pp,ee}) ' ' zCatFile],a,b);
            system(command);
            % The newly created nifti file has inaccurate spatial header
            % information. We copy over some header information from the
            % original to the new nifti file.
            niftiFields = {'srow_z','srow_x','qoffset_z','quatern_b',...
                'aux_file','descrip','slice_end','dim_info'};
            for ff = 1:length(niftiFields)
                % Get the header value in the original file
                command = [afniPath 'nifti_tool -quiet -disp_hdr -field ' niftiFields{ff} ' -infiles ' fullfile(repoOrigDir,acqFileNames{pp,ee})];
                [~,origVal] = system(command);
                % Remove the trailing carriage return from the output
                if double(origVal(length(origVal)))
                    origVal = origVal(1:length(origVal)-1);
                end
                % Rename the file to be modified to be called temp
                movefile(fullfile(ARG.DIROUT,acqFileNamesNoZip{pp,ee}),fullfile(ARG.DIROUT,['tmp_' acqFileNamesNoZip{pp,ee}]))
                % Place this header value in the new nifti
                command = [afniPath 'nifti_tool -mod_hdr -mod_field ' niftiFields{ff} ' ''' origVal ''''  ' -infiles ' fullfile(ARG.DIROUT,['tmp_' acqFileNamesNoZip{pp,ee}]) ' -prefix ' fullfile(ARG.DIROUT,acqFileNamesNoZip{pp,ee})];
                system(command);
                % Remove the temp file
                delete(fullfile(ARG.DIROUT,['tmp_' acqFileNamesNoZip{pp,ee}]));
            end
            % Zip the file
            gzip(fullfile(ARG.DIROUT,acqFileNamesNoZip{pp,ee}));
            % Move it to the func directory
            movefile(fullfile(ARG.DIROUT,acqFileNames{pp,ee}),fullfile(repoFuncDir,acqFileNames{pp,ee}));
            % Delete the .nii file that was used to create the zip
            delete(fullfile(ARG.DIROUT,acqFileNamesNoZip{pp,ee}));
        end
    end

end

end