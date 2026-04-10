function [nDetectTrials,proportionDetect,trialIdxWithMissedDetections] = reportModulateBehavPerformance(subjects,directions,contrasts,phases)

% Report the performance on the behavior task
experimentName = 'modulate';
dropboxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dataDir = fullfile(dropboxBaseDir,'BLNK_data','PuffLight',experimentName);

% Loop over the data files
for ss = 1:length(subjects)
    for dd = 1:length(directions)
        for cc = 1:length(contrasts)
            for pp = 1:length(phases)
                % Load the psychometric object
                psychFileName = sprintf( [subjects{ss} '_' experimentName ...
                    '_direction-' directions{dd} '_contrast-%2.2f_phase-%2.2f.mat'], contrasts{cc}(dd), phases(pp) );
                load(fullfile(dataDir,subjects{ss},psychFileName),'psychObj');

                % The proportion correct on the detection task, and  the trials in
                % which any missed events occured
                nDetectTrials(ss,dd,cc,pp) = length([psychObj.trialData.detected]);
                proportionDetect(ss,dd,cc,pp) = sum([psychObj.trialData.detected])/length([psychObj.trialData.detected]);
                trialIdxWithMissedDetections{ss,dd,cc,pp} = find(arrayfun(@(x) any(x.detected==0),psychObj.trialData));
            end
        end
    end
end

% 
% % Report the stats
% fprintf('Each subject was presented an average of %2.0f detection events across all trials.\n',mean(nDetectTrialsBySub));
% fprintf('Mean (across subject) detection performance in the lightLevel test was %2.2f \n',mean(proportionDetectBySub));
% fprintf('    with a range of %2.2f to %2.2f\n',min(proportionDetectBySub),max(proportionDetectBySub));

