function meanStimPhaseRightEyeRad = processVideoLags()
% This routine examines the temporal offsets present in the video
% intensityt data that is created by the extractVideoRegions routine

varFile='/Users/aguirre/Aguirre-Brainard Lab Dropbox/Geoffrey Aguirre/BLNK_analysis/PuffLight/modulate/videoLatencyAnalysis/08-Apr-2026.mat';
load(varFile,'fileStructList','intensityData','regionMasks');

% Loop through the videos and find those recordings that have at least 50%
% of the variance in the time series explained by a sinusoidal modulation
r2Thresh = 0.5;
nVids = length(fileStructList);
for nn = 1:nVids
    for ss=1:2
        y=intensityData{ss,nn}-mean(intensityData{ss,nn});
        [~,~,~,r2(ss,nn)]=fitFourier(y');
    end
end
goodVidIdx = find(all(r2>r2Thresh));

% Go through the good vids. Obtain the phase of the response.
r2 = [];
for ii = 1:length(goodVidIdx)
    for ss=1:2
        y=intensityData{ss,goodVidIdx(ii)}-mean(intensityData{ss,goodVidIdx(ii)});
        [~,phase(ss,ii),~,r2(ss,ii)]=fitFourier(y');
        % Handle the two phases of stimuli
        if phase(ss,ii) > pi/2 && phase(ss,ii) < 3*pi/2
            phase(ss,ii) = phase(ss,ii) - pi;
        end
        % wrap to 2 pi
        phase(ss,ii) = wrapTo2Pi(phase(ss,ii));
    end
end

% This is the mean delay of the recording from the left eye as compared to
% the right
leftEyeLagRad = mean(wrapToPi(phase(2,:)-phase(1,:)));

% This is the phase of the stimulus within the recording as measured from
% the right eye
complexVecs = exp(1i * phase(1,:));
meanVec = mean(complexVecs);
meanStimPhaseRightEyeRad = angle(meanVec);

end