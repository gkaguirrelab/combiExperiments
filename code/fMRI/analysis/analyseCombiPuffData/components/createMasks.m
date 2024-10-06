function repoMaskDir = createMasks(dataPath,dirName,subID,sesID,acqSet)
% Create a set of masks for this subject to support derivation of
% nuisance covariates and defining the extent of the voxels to be
% processed.
%
% Most significantly, this routine creates a brainstem mask using a
% "brainstem only" mask provided by Susanne Mueller, which can be found in
% the "masks" directory of this repo.
%
% Note that setupEnv must be run prior to this function
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
    repoMaskDir = createMasks(dataPath,dirName,subID,sesID,acqSet);
%}

% Define the nameStem for this subject / session
nameStem = ['sub-',subID,'_ses-',sesID];

% Define the repo directories
repoAnatDir = fullfile(dataPath,dirName,['sub-',subID],['ses-',sesID],'anat');
repoFuncDir = fullfile(dataPath,dirName,['sub-',subID],['ses-',sesID],'func');
repoMaskDir = fullfile(dataPath,dirName,['sub-',subID],['ses-',sesID],'mask');
mkdir(repoMaskDir);

% Identify a temp directory
workDir = tempdir();

% Define source file paths
brainstemOnlyMaskDir_FSLMNI152 = fullfile(tbLocateProjectSilent('combiExperiments'),'code','fMRI','analysis','masks','brainstemOnly');
brainstemOnlyMaskPath_FSLMNI152 = fullfile(brainstemOnlyMaskDir_FSLMNI152,'brainstem_only_final_mask.nii');
templatePath_FSLMNI152 = fullfile(brainstemOnlyMaskDir_FSLMNI152,'FSL_MNI152_FreeSurferConformed_1mm.nii.gz');
subjectT1wPath_MNI152NLin2009cAsym = fullfile(repoAnatDir,[nameStem,'_space-MNI152NLin2009cAsym_desc-preproc_T1w.nii.gz']);
tempDir = dir(fullfile(repoFuncDir,[nameStem,'*space-MNI152NLin2009cAsym_boldref.nii.gz']));
subjectBoldPath_MNI152NLin2009cAsym = fullfile(tempDir(1).folder,tempDir(1).name);

% Define output paths
brainstemOnlyMaskPathAnat_MNI152NLin2009cAsym = fullfile(repoAnatDir,[nameStem,'_space-MNI152NLin2009cAsym_label-brainstem.nii.gz']);
brainstemOnlyMaskPathFunc_MNI152NLin2009cAsym = fullfile(repoMaskDir,[nameStem,'_space-MNI152NLin2009cAsym_label-brainstem.nii.gz']);
gmMaskPathFunc_MNI152NLin2009cAsym = fullfile(repoMaskDir,[nameStem,'_space-MNI152NLin2009cAsym_label-GM.nii.gz']);
wmMaskPathFunc_MNI152NLin2009cAsym = fullfile(repoMaskDir,[nameStem,'_space-MNI152NLin2009cAsym_label-WM.nii.gz']);
csfMaskPathFunc_MNI152NLin2009cAsym = fullfile(repoMaskDir,[nameStem,'_space-MNI152NLin2009cAsym_label-CSF.nii.gz']);

% Using ANTS, calculate the warp from the FSLMNI space to the subject T1w
% brain in MNI152NLin2009cAsym space
command = ['antsRegistrationSyNQuick.sh -d 3 -f ' subjectT1wPath_MNI152NLin2009cAsym ' -m ' templatePath_FSLMNI152 ' -o  ' fullfile(workDir,'FSLMNI_to_MNI152NLin2009cAsym_') ];
system(command)

% Apply the warp to the brainstem only mask, creating a mask that is at the
% resolution of the T1w anatomical image of the subject in MNI space
xfm_FSL2MNI = fullfile(workDir,'FSLMNI_to_MNI152NLin2009cAsym_0GenericAffine.mat');
command = ['antsApplyTransforms -d 3 -i ' brainstemOnlyMaskPath_FSLMNI152 ' -r ' subjectT1wPath_MNI152NLin2009cAsym ' -t ' xfm_FSL2MNI ' -o ' brainstemOnlyMaskPathAnat_MNI152NLin2009cAsym ];
system(command);

% Using freesurfer mri_vol2vol, resample the brainstem, white matter, gray
% matter, and CSF masks to be in MNI space, and then threshold
command = ['mri_vol2vol --regheader --nearest --mov ' brainstemOnlyMaskPathAnat_MNI152NLin2009cAsym ' --targ ' subjectBoldPath_MNI152NLin2009cAsym ' --o ' brainstemOnlyMaskPathFunc_MNI152NLin2009cAsym];
system(command);
command = ['fslmaths ' brainstemOnlyMaskPathFunc_MNI152NLin2009cAsym ' -thr 0.25 ' brainstemOnlyMaskPathFunc_MNI152NLin2009cAsym];
system(command);
command = ['fslmaths ' brainstemOnlyMaskPathFunc_MNI152NLin2009cAsym ' -bin ' brainstemOnlyMaskPathFunc_MNI152NLin2009cAsym];
system(command);

    command = ['mri_vol2vol --regheader --nearest --mov ' fullfile(repoAnatDir,[nameStem '_space-MNI152NLin2009cAsym_label-GM_probseg.nii.gz']) ' --targ ' subjectBoldPath_MNI152NLin2009cAsym ' --o ' gmMaskPathFunc_MNI152NLin2009cAsym];
system(command);
command = ['fslmaths ' gmMaskPathFunc_MNI152NLin2009cAsym ' -thr 0.5 ' gmMaskPathFunc_MNI152NLin2009cAsym];
system(command);
command = ['fslmaths ' gmMaskPathFunc_MNI152NLin2009cAsym ' -bin ' gmMaskPathFunc_MNI152NLin2009cAsym];
system(command);


command = ['mri_vol2vol --regheader --nearest --mov ' fullfile(repoAnatDir,[nameStem '_space-MNI152NLin2009cAsym_label-WM_probseg.nii.gz']) ' --targ ' subjectBoldPath_MNI152NLin2009cAsym ' --o ' wmMaskPathFunc_MNI152NLin2009cAsym];
system(command);
system(command);
command = ['fslmaths ' wmMaskPathFunc_MNI152NLin2009cAsym ' -thr 0.5 ' wmMaskPathFunc_MNI152NLin2009cAsym];
system(command);
command = ['fslmaths ' wmMaskPathFunc_MNI152NLin2009cAsym ' -bin ' wmMaskPathFunc_MNI152NLin2009cAsym];
system(command);


command = ['mri_vol2vol --regheader --nearest --mov ' fullfile(repoAnatDir,[nameStem '_space-MNI152NLin2009cAsym_label-CSF_probseg.nii.gz']) ' --targ ' subjectBoldPath_MNI152NLin2009cAsym ' --o ' csfMaskPathFunc_MNI152NLin2009cAsym];
system(command);
system(command);
command = ['fslmaths ' csfMaskPathFunc_MNI152NLin2009cAsym ' -thr 0.5 ' csfMaskPathFunc_MNI152NLin2009cAsym];
system(command);
command = ['fslmaths ' csfMaskPathFunc_MNI152NLin2009cAsym ' -bin ' csfMaskPathFunc_MNI152NLin2009cAsym];
system(command);


% Create a brain mask in subject native space for each acqusitions. This is
% used for tedana processing.
for ii = 1:length(acqSet)
    % Transform the brain mask back to boldref
    xfm_boldref2T1 = fullfile(repoFuncDir,[nameStem,acqSet{ii},'_from-boldref_to-T1w_mode-image_desc-coreg_xfm.txt']);
    sourceFile = fullfile(repoAnatDir,[nameStem '_desc-brain_mask.nii.gz']);
    boldrefFile = fullfile(repoFuncDir,[nameStem,acqSet{ii},'_part-mag_desc-coreg_boldref.nii.gz']);
    outFileBrain = fullfile(repoMaskDir,[nameStem,acqSet{ii},'_desc-brain_mask.nii.gz']);
    command = ['antsApplyTransforms -d 3 -i ' sourceFile ' -r ' boldrefFile ' -t [ ' xfm_boldref2T1 ' ,1 ] -o  ' outFileBrain ];
    system(command);
    % Threshold
    command = ['fslmaths ' outFileBrain ' -thr 0.25 ' outFileBrain];
    system(command);
    command = ['fslmaths ' outFileBrain ' -bin ' outFileBrain];
    system(command);
end

end