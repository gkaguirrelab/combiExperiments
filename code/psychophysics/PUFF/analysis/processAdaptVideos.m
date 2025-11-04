

% Define some properties of the analysis
dataDir = '/Users/aguirre/Aguirre-Brainard Lab Dropbox/Geoffrey Aguirre/BLNK_analysis/PuffLight/blinkResponse/HERO_gka';
fps = 180;

sessions = {'2025-09-11 AM','2025-09-11 PM','2025-09-01','2025-09-10'};
achievedLux = [1342,2684,4429,6712];
modContrastLevels = {[0,0.05],[0,0.10],[0,0.25],[0,0.25]};

% Set up some data variables
blinksPerMinData = nan(length(sessions),2,2);
pupilDiameterData = nan(length(sessions),2,2);
palpFissureData = nan(length(sessions),2,2);

for ss = 1:length(sessions)

    for cc = 1:2

        thisContrast = modContrastLevels{ss}(cc);

        % Get a list of the adapt files; have to special case the 09-01
        % session at the high contrast level as the adapt 5 was lost
        if ss==3 && cc == 2
        mList = dir(fullfile(dataDir,sessions{ss},sprintf('*contrast-%2.2f*adapt-4*mat',thisContrast)));
        else
        mList = dir(fullfile(dataDir,sessions{ss},sprintf('*contrast-%2.2f*adapt-4*mat',thisContrast)));
        end

        % Loop over the data files
        for ii = 1:length(mList)

            % Load the data
            load(fullfile(mList(ii).folder,mList(ii).name),'eye_features');

            % Take the second half of the data
            eye_features = eye_features(1:round(length(eye_features)/2));

            % Extract the upper and lower lid to calculate the height of the palpebral
            % fissure over time
            nTimePoints = length(eye_features);
            palpFissureHeight = nan(1,nTimePoints);
            pupilDiameter = nan(1,nTimePoints);

            for tt = 1:nTimePoints
                xVals = eye_features{tt}.eyelids.eyelid_x;
                lidUpper = eye_features{tt}.eyelids.eyelid_up_y;
                lidLower = eye_features{tt}.eyelids.eyelid_lo_y;
                [~,xIdx] = min(abs(xVals-mean(xVals)));
                val = lidLower(xIdx) - lidUpper(xIdx);
                if val > 0 && val < 100
                    palpFissureHeight(tt) = val;
                end
                pupilDiameter(tt) = eye_features{tt}.pupil.diameter;
            end

            % This is a vector of blink events
            blinkVec = diff(palpFissureHeight < median(palpFissureHeight,'omitmissing')/2)>0;

            % Slide a window along and ensure that no more than one blink
            % event exists within a 0.25 second window
            for tt = 1:length(blinkVec)
                if blinkVec(tt) == 1
                    blinkVec(tt+1:tt+fps/4)=0;
                end
            end
            
            % Obtain the blink rate and store this
            blinksPerMinData(ss,cc,ii) = sum(blinkVec)/(55/60);
            
            % Obtain an estimate of the pupil diameter and palpebral
            % fissure height, after censoring time points around the blinks
            for mm = -20:50
                pupilDiameter(circshift(blinkVec,mm))=nan;
                palpFissureHeight(circshift(blinkVec,mm))=nan;
            end

            % figure
            % subplot(3,1,1)
            % plot(palpFissureHeight);
            % title(mList(ii).name);
            % subplot(3,1,2);
            % plot(blinkVec,'*');
            % title(sprintf('%2.2f',blinksPerMinData(ss,cc,ii)));
            % subplot(3,1,3)
            % plot(pupilDiameter);
            % pause

            pupilDiameterData(ss,cc,ii) = median(pupilDiameter,'omitmissing');
            palpFissureData(ss,cc,ii) = median(palpFissureHeight,'omitmissing');

        end % adapt files for this session and contrast level
    end % contrast level
end % session

