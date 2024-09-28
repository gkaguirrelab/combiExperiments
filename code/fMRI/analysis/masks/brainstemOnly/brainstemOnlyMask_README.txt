A brainstem mask was generated using the following process:

- I obtained the brainstem only mask file described here:
	Mueller SG. Mapping internal brainstem structures using MP2RAGE derived T1 weighted and T1 relaxation images at 3 and 7 T. Human brain mapping. 2020 Jun 1;41(8):2173-86.
- In practice the file itself was made available as part of the supplementary materials for this paper:
	Mueller SG. Mapping internal brainstem structures using T1 and T2 weighted 3T images. Frontiers in Neuroimaging. 2023 Dec 15;2:1324107.
	https://data.mendeley.com/datasets/8pfjgrwtsr/1

- This mask file was created using FSL tools, based upon the FSL template file FSL_MNI152_FreeSurferConformed_1mm.nii.gz, described in the paper:
	Yeo BTT, Krienen FM, Sepulcre J, Sabuncu MR, Lashkari D, Hollinshead M, Roffman JL, Smoller JW, Zollei L, Polimeni JR, Fischl B, Liu H, Buckner RL (2011) The organization of the human cerebral cortex estimated by intrinsic functional connectivity. J Neurophysiol 106: 1125-1165

- I used the FSL command flirt to calculate a 12 dof, affine transformation between the FSL MNI atlas space to the T1 image of the studied subject that is produced by fmriprep and is in the MNI152NLin2009cAsym space. The command was:

flirt -in FSL_MNI152_FreeSurferConformed_1mm.nii.gz -ref sub-001_ses-20240923_space-MNI152NLin2009cAsym_desc-preproc_T1w.nii.gz -omat tpl-MNI152NLin2009cAsym_from-FSL_MNI152_FreeSurferConformed_1mm_mode-image.xfm  

- I then applied the xfm to warp the brainstem mask to the MNI152NLin2009cAsym space:
flirt -in FSL_MNI152_FreeSurferConformed_1mm.nii.gz -ref sub-001_ses-20240923_space-MNI152NLin2009cAsym_desc-preproc_T1w.nii.gz -init tpl-MNI152NLin2009cAsym_from-FSL_MNI152_FreeSurferConformed_1mm_mode-image.xfm -out brainstemOnly_space-MNI152NLin2009cAsym.nii.gz


