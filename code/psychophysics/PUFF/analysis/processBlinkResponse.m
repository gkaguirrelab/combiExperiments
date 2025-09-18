%% To extract audio track and puff auditory signature
clear

subjectID = 'HERO_gka';
experimentName = 'blinkResponse';
whichDirection = 'LightFlux';

sessions = {'2025-09-11 AM','2025-09-11 PM','2025-09-01','2025-09-10'};

% Define the contrasts for each session
modContrastLevels = {[0,0.05],[0,0.10],[0,0.25],[0,0.25]};

achievedLux = [1342,2684,4429,6712];


dataDir = '/Users/aguirre/Aguirre-Brainard Lab Dropbox/Geoffrey Aguirre/BLNK_analysis/PuffLight/blinkResponse/HERO_gka';

% Define the intervals for averaging / finding auc or max
baseRange = [100 160];
maxRange = [160 220];
aucRange = [220 280];

% Define the time domain
t = (0:450-1) / 180;

% Define the sequences
sequenceSet{1} = [3,3,1,4,5,5,4,1,2,3,2,2,1,5,3,4,4,3,5,2,4,2,5,1,1,3];
sequenceSet{2} = [3,3,2,5,3,5,2,4,3,4,1,1,5,1,3,1,2,2,1,4,4,5,5,4,2,3];
sequenceSet{3} = [3,3,4,2,5,3,2,4,5,1,4,1,1,5,4,4,3,5,5,2,1,2,2,3,1,3];
sequenceSet{4} = [3,3,1,4,5,1,2,2,3,2,1,3,4,2,4,4,3,5,2,5,5,4,1,1,5,3];

% Loop over sessions
for sess = 1:length(sessions)

    mList = dir(fullfile(dataDir,sessions{sess},'*trial*R_eye_features.mat'));
    nVids = length(mList);

    palpHeightX = nan(nVids,1);
    blinkX = nan(nVids,450);
    pupilX = nan(nVids,450);

    cropY = 150:325;
    cropX = 200:425;
    myTempDir = tempdir;

    for ii = 1:nVids

        % load the eye features
        load(fullfile(mList(ii).folder,mList(ii).name),'eye_features');

        % Get the difference between the upper and lower lid at the mid-point
        % across time points
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

        % Store the initial palp fissue height, and convert the vector into
        % proportion lid closure
        openPixels = mean(palpFissureHeight(baseRange(1):baseRange(2)),'omitmissing');
        blinkVec = -(palpFissureHeight-openPixels)./openPixels;

        % Store these vectors
        palpHeightX(ii) = openPixels;
        blinkX(ii,1:length(blinkVec)) = blinkVec;
        pupilX(ii,1:length(pupilDiameter)) = pupilDiameter;

    end

    % Direct effect
    for cc = 1:2
        thisContrast = modContrastLevels{sess}(cc);
        for ll = 1:5
            blinkMatrix = nan(40,450);
            pupilMatrix = nan(40,450);
            palpHeight = nan(40,1);
            count = 1;
            for bb = 1:2
                for ss = 1:4
                    idx = find(sequenceSet{ss}==ll);
                    for ii = 1:length(idx)
                        if idx(ii)>1
                            filename = sprintf( [subjectID '_' experimentName ...
                                '_direction-' whichDirection '_contrast-%2.2f_block-%d_sequence-%d' ...
                                '_trial-%02d_side-R_eye_features.mat'],...
                                thisContrast,bb,ss,idx(ii));
                            entryIdx = find(strcmp({mList.name},filename));
                            if ~isempty(entryIdx)
                                blinkMatrix(count,:)=blinkX(entryIdx,:);
                                pupilMatrix(count,:)=pupilX(entryIdx,:);
                                palpHeight(count)=palpHeightX(entryIdx);
                                count = count+1;
                            else
                                foo=1;
                            end
                        end
                    end
                end
            end
            dataStruct(sess,cc,ll).mean = mean(blinkMatrix,'omitmissing');
            dataStruct(sess,cc,ll).blinkMatrix = blinkMatrix;
            dataStruct(sess,cc,ll).pupilMatrix = pupilMatrix;
            dataStruct(sess,cc,ll).palpHeight = palpHeight;

        end

        % Carry over effect
        countMatrix = zeros(5,5);
        carryMatrix = nan(5,5,8,450);
        for ss = 1:4
            for bb = 1:2
                for tt = 2:26
                    filename = sprintf( [subjectID '_' experimentName ...
                        '_direction-' whichDirection '_contrast-%2.2f_block-%d_sequence-%d' ...
                        '_trial-%02d_side-R_eye_features.mat'],...
                        thisContrast,bb,ss,tt);
                    entryIdx = find(strcmp({mList.name},filename));
                    if ~isempty(entryIdx)
                        curr = sequenceSet{ss}(tt);
                        last = sequenceSet{ss}(tt-1);
                        count = countMatrix(curr,last)+1;
                        carryMatrix(curr,last,count,:) = blinkX(entryIdx,:);
                        countMatrix(curr,last) = count;
                    else
                        foo=1;
                    end
                end
            end
        end
        carryStruct(sess,cc).carryMatrix = carryMatrix;
    end

    % Plot the carry over matrix for the two light levels
    %{
    figure
    for cc = 1:2
        for xx = 1:5
            for yy=1:5
                vec = mean(squeeze(carryStruct(sess,cc).carryMatrix(xx,yy,:,:)),1,'omitmissing');
                max30(xx,yy) =  max(vec(maxRange(1):maxRange(2)),[],'omitmissing');
                auc120(xx,yy) =  sum(vec(aucRange(1):aucRange(2)),'omitmissing');
            end
        end
        subplot(2,2,(cc-1)*2+1)
        imagesc(max30); title('max30');
        xlabel('prior'); ylabel('current');
        subplot(2,2,(cc-1)*2+2)
        imagesc(auc120); title('auc120');
    end
    %}


    figure
    cs = {[0.2,0,0],[0.4,0,0],[0.6,0,0],[0.8,0,0],[1.0,0,0]};
    for ii = 1:5
        subplot(2,3,ii)
        blinkMatrixA = dataStruct(sess,1,ii).blinkMatrix;
        yValsA = mean(blinkMatrixA,'omitmissing');
        plot(t,yValsA,'-','Color',cs{ii});
        hold on
        blinkMatrixB = dataStruct(sess,2,ii).blinkMatrix;
        yValsB = mean(blinkMatrixB,'omitmissing');
        plot(t,yValsB,':','Color',cs{ii});
        plot([t(maxRange(1)) t(maxRange(1))],[-0.1 1],'-k');
        plot([t(maxRange(2)) t(maxRange(2))],[-0.1 1],'-k');
        plot([t(aucRange(1)) t(aucRange(1))],[-0.1 1],'-r');
        plot([t(aucRange(2)) t(aucRange(2))],[-0.1 1],'-r');
        max30Mean(1,ii) = mean(max(blinkMatrixA(:,maxRange(1):maxRange(2)),[],2,'omitmissing'),'omitmissing');
        max30SEM(1,ii) = std(max(blinkMatrixA(:,maxRange(1):maxRange(2)),[],2,'omitmissing'))/sqrt(40);
        max30Mean(2,ii) = mean(max(blinkMatrixB(:,maxRange(1):maxRange(2)),[],2,'omitmissing'),'omitmissing');
        max30SEM(2,ii) = std(max(blinkMatrixB(:,maxRange(1):maxRange(2)),[],2,'omitmissing'))/sqrt(40);
        auc30Mean(1,ii) = mean(sum(blinkMatrixA(:,maxRange(1):maxRange(2)),2,'omitmissing'))/30;
        auc30Mean(2,ii) = mean(sum(blinkMatrixB(:,maxRange(1):maxRange(2)),2,'omitmissing'))/30;
        auc30SEM(1,ii) = std(sum(blinkMatrixA(:,maxRange(1):maxRange(2)),2,'omitmissing'))/30/sqrt(40);
        auc30SEM(2,ii) = std(sum(blinkMatrixB(:,maxRange(1):maxRange(2)),2,'omitmissing'))/30/sqrt(40);
        auc120Mean(1,ii) = mean(sum(blinkMatrixA(:,aucRange(1):aucRange(2)),2,'omitmissing'))/120;
        auc120Mean(2,ii) = mean(sum(blinkMatrixB(:,aucRange(1):aucRange(2)),2,'omitmissing'))/120;
        auc120SEM(1,ii) = std(sum(blinkMatrixA(:,aucRange(1):aucRange(2)),2,'omitmissing'))/120/sqrt(40);
        auc120SEM(2,ii) = std(sum(blinkMatrixB(:,aucRange(1):aucRange(2)),2,'omitmissing'))/120/sqrt(40);
        ylim([-0.1 1]);
        xlim([0.5 2.5]);
        xlabel('time [s]');
        ylabel('proportion close');
    end


    figure
    subplot(1,3,1);
    plot(max30Mean','o-');
    %plot(auc30Mean','o-');
    hold on
    for ii = 1:5
        plot([ii,ii],[max30Mean(1,ii)+1.5*max30SEM(1,ii),max30Mean(1,ii)-1.5*max30SEM(1,ii)],'-k');
        plot([ii,ii],[max30Mean(2,ii)+1.5*max30SEM(2,ii),max30Mean(2,ii)-1.5*max30SEM(2,ii)],'-k');
        %    plot([ii,ii],[auc30Mean(1,ii)+auc30SEM(1,ii),auc30Mean(1,ii)-auc30SEM(1,ii)],'-k');
        %    plot([ii,ii],[auc30Mean(2,ii)+auc30SEM(2,ii),auc30Mean(2,ii)-auc30SEM(2,ii)],'-k');
    end
    ylabel('Proportion closure per second');
    xlim([0.75 5.25])
    ylim([0 1]);

    subplot(1,3,2);
    plot(auc120Mean','o-');
    hold on
    for ii = 1:5
        plot([ii,ii],[auc120Mean(1,ii)+1.5*auc30SEM(1,ii),auc120Mean(1,ii)-1.5*auc30SEM(1,ii)],'-k');
        plot([ii,ii],[auc120Mean(2,ii)+1.5*auc30SEM(2,ii),auc120Mean(2,ii)-1.5*auc30SEM(2,ii)],'-k');
    end
    ylabel('Proportion closure per second');
    xlim([0.75 5.25])
    ylim([0 1]);

    subplot(1,3,3);
    for ii = 1:5
        plot(ii,mean(dataStruct(sess,1,ii).palpHeight),'ok');
        hold on
        plot(ii,mean(dataStruct(sess,2,ii).palpHeight),'or');
    end
    ylabel('palp fissure pixels');

end

%save('/Users/aguirre/Desktop/puffBlinkData.mat','audioX','imageX','mList','dataStruct');

