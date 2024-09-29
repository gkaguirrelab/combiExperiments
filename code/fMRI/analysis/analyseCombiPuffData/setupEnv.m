% The analysis of the fMRI data requires that several software packages be
% installed, and that the paths and environment variables be properly
% defined. 

% Configure environment variables for the matlab shell
envVars = {'FREESURFER_HOME','SUBJECTS_DIR',...
    'FS_LICENSE',...
    'ANTSPATH','PATH'};
envVals = {'/Applications/freesurfer',...
    '$FREESURFER_HOME/subjects',fullfile(tbLocateProjectSilent('combiExperiments'),'code','fMRI','analysis','masks','brainstemOnly','freesurfer_license.txt'),...
    '/Applications/ants-2.5.1-arm/bin',[getenv('PATH') ':/Applications/ants-2.5.1-arm/bin']};
for ii = 1:length(envVars)
    setenv(envVars{ii},envVals{ii});
end

% Check that freesurfer is installed

% Check that ants is installed

% Check that afni is installed