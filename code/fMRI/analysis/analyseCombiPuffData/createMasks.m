function repoMaskDir = createMasks(dataPath,dirName,subID,sesID)
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
    sesID = '20240923';
    tr = 2.87;
    repoMaskDir = createMasks(dataPath,dirName,subID,sesID);
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
command = ['antsApplyTransforms -d 3 -i ' brainstemOnlyMaskPath_FSLMNI152 ' -r ' subjectT1wPath_MNI152NLin2009cAsym ' -o  ' brainstemOnlyMaskPathAnat_MNI152NLin2009cAsym ];
system(command);

% Using freesurfer mri_vol2vol, resample the brainstem, white matter, gray
% matter, and CSF masks to be in func space
command = ['mri_vol2vol --regheader --nearest --mov ' brainstemOnlyMaskPathAnat_MNI152NLin2009cAsym ' --targ ' subjectBoldPath_MNI152NLin2009cAsym ' --o ' brainstemOnlyMaskPathFunc_MNI152NLin2009cAsym];
system(command);
command = ['mri_vol2vol --regheader --nearest --mov ' fullfile(repoAnatDir,[nameStem '_space-MNI152NLin2009cAsym_label-GM_probseg.nii.gz']) ' --targ ' subjectBoldPath_MNI152NLin2009cAsym ' --o ' gmMaskPathFunc_MNI152NLin2009cAsym];
system(command);
command = ['mri_vol2vol --regheader --nearest --mov ' fullfile(repoAnatDir,[nameStem '_space-MNI152NLin2009cAsym_label-WM_probseg.nii.gz']) ' --targ ' subjectBoldPath_MNI152NLin2009cAsym ' --o ' wmMaskPathFunc_MNI152NLin2009cAsym];
system(command);
command = ['mri_vol2vol --regheader --nearest --mov ' fullfile(repoAnatDir,[nameStem '_space-MNI152NLin2009cAsym_label-CSF_probseg.nii.gz']) ' --targ ' subjectBoldPath_MNI152NLin2009cAsym ' --o ' csfMaskPathFunc_MNI152NLin2009cAsym];
system(command);

end