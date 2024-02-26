stimulusCoarse = [0,0,0,0,1,4,4,3,1,1,3,4,3,1,3,0,4,3,4,2,0,0,2,1,0,3,3,0,3,4,0,2,4,2,1,3,3,1,2,4,1,3,3,1,4,4,2,0,0,2,1,3,0,0,4,2,0,4,2,1,2,2,4,0,2,2,0,1,3,1,4,4,2,0,3,3,1,0,2,2,1,4,1,0,0,0,0];
isi = 4.25;
dT = 0.25;
initialDelay = 1;
smoothSD = '0.25';


stimVecLength = length(stimulusCoarse)*(isi/dT);
stimulus = zeros(4,stimVecLength);
carryOver = zeros(1,stimVecLength);
newStim = zeros(1,stimVecLength);
for ii = 1:length(stimulusCoarse)
    if stimulusCoarse(ii)~=0
        idx = (ii-1)*(isi/dT)+(initialDelay/dT);
        stimulus(stimulusCoarse(ii),idx) = 1;
        if ii > 1
            if stimulusCoarse(ii-1) ~=0
                carryOver(idx) = stimulusCoarse(ii) - stimulusCoarse(ii-1);
            else
                newStim(idx) = 1;
            end
        end
    end
end
idx = carryOver ~= 0;
carryOver(idx) = carryOver(idx) - mean(carryOver(idx));

idx = newStim == 0;
newStim(idx) = -mean(newStim);

stimulus = [stimulus];%; carryOver; newStim];

stimTime = -isi:dT:(length(stimulus)-(isi/dT)-1)*dT;

stimFilePath = '/Users/aguirre/Downloads/trigemStim.mat';
save(stimFilePath,'stimulus','stimTime');

funcZipPath = '/Users/aguirre/Downloads/tedanaOutput.zip';
maskFilePath = '/Users/aguirre/Downloads/656a130eacf7f8b0b0d1845d/sub-001/ses-20231114/fmap/sub-001_ses-20231114_acq-meSe_fmapid-mask.nii.gz';
maskFilePath = '/Users/aguirre/Downloads/65d8ecc1367208b4d14e21de/sub-001/ses-20240222/fmap/sub-001_ses-20240222_acq-meSe_fmapid-mask.nii.gz';

workbenchPath = 'Na';
convertToPercentChange = true;
averageAcquisitions = true;

[~, ~, data, vxs, templateImage] = handleInputs(workbenchPath, {funcZipPath}, stimFilePath, ...
    'dataFileType', 'volumetric', ...
    'dataSourceType', 'tedana', ...
    'smoothSD',smoothSD,...
    'convertToPercentChange',convertToPercentChange,...
    'averageAcquisitions',averageAcquisitions);

%vxsPath = '/Users/aguirre/Downloads/vxs.mat';
%load(vxsPath,'vxs');


stimLabels = {'3','7','15','30'};%,'co','ns'};
confoundStimLabel = '';
avgAcqIdx = {[1:177]};%,[178:354],[355:531],[532:708],[709:885]};
polyDeg = 10;
typicalGain = 3e3;
modelOpts = {'polyDeg',polyDeg,'typicalGain',typicalGain,...
    'stimLabels',stimLabels,'confoundStimLabel',confoundStimLabel,'avgAcqIdx',avgAcqIdx};


tr = 2.140;


results = forwardModel(data, stimulus, tr, ...
    'stimTime', stimTime, ...
     'vxs',vxs, ...
'modelClass','glm');
%   'modelClass','mtSinai',...
%   'modelOpts',modelOpts);


outPath = '/Users/aguirre/Downloads';
Subject = 'sub-001';

mapOutDirName = handleOutputs(results, templateImage, outPath, Subject, workbenchPath, ...
        'dataFileType', 'volumetric');


