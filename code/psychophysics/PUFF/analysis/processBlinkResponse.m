%% To extract audio track and puff auditory signature
clear
rng;

subjectID = 'HERO_gka';
experimentName = 'blinkResponse';
whichDirection = 'LightFlux';

psiLevels = logspace(log10(5),log10(30),5);
psiLevelsLog = log10(psiLevels);

sessions = {'2025-09-11 AM','2025-09-11 PM','2025-09-01','2025-09-10'};
sessions = {'2025-09-11 PM','2025-09-01','2025-09-10'};

% Define the contrasts for each session
modContrastLevels = {[0,0.05],[0,0.10],[0,0.25],[0,0.25]};
modContrastLevels = {[0,0.10],[0,0.25],[0,0.25]};

achievedLux = [1342,2684,4429,6712];
achievedLux = [2684,4429,6712];

figHangle = figure();

dataDir = '/Users/aguirre/Aguirre-Brainard Lab Dropbox/Geoffrey Aguirre/BLNK_analysis/PuffLight/blinkResponse/HERO_gka';

% Define the intervals for averaging / finding auc or max
baseRange = [100 160];
closeRange = [160 220];
squintRange = [220 280];

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
    titleText = {'dark','light'};
    for ii = 1:5
        for lightLevel = 1:2
            subplot(1,2,lightLevel)
            blinkMatrix = dataStruct(sess,lightLevel,ii).blinkMatrix;
            yVals = mean(blinkMatrix,'omitmissing');
            yValsSmooth = smoothdata(yVals,"gaussian",7);
            plot(t,yValsSmooth,'-','Color',cs{ii},'LineWidth',1.5);
            hold on
            plot([t(closeRange(1)) t(closeRange(1))],[-0.1 1],'-k');
            plot([t(closeRange(2)) t(closeRange(2))],[-0.1 1],'-k');
            plot([t(squintRange(1)) t(squintRange(1))],[-0.1 1],'-r');
            plot([t(squintRange(2)) t(squintRange(2))],[-0.1 1],'-r');

            % Clean up the plot
            ylim([-0.1 1]);
            xlim([0.5 2.5]);
            xlabel('time [s]');
            ylabel('proportion close');
            title(titleText{lightLevel});

            % Calcuate the max lid closure for each of the set of trails
            maxCloseVec = max(blinkMatrix(:,closeRange(1):closeRange(2)),[],2,'omitmissing');

            % Calculate the max close values for the A and B data sets
            maxCloseMean(lightLevel,ii) = mean(maxCloseVec,'omitmissing');
            maxCloseSEM(lightLevel,ii) = std(maxCloseVec,'omitmissing')/sqrt(sum(~isnan(maxCloseVec)));

            % Calculate the mean closure during the squint period
            squintMeanVec = sum(blinkMatrix(:,squintRange(1):squintRange(2)),2,'omitmissing');
            nTimePoints = sum(~isnan(blinkMatrix(:,squintRange(1):squintRange(2))),2);
            nTimePoints(nTimePoints<range(squintRange)/2)=nan;
            squintMeanVec = squintMeanVec ./ nTimePoints;

            aucSquintMean(lightLevel,ii) = mean(squintMeanVec,'omitmissing');
            aucSquintSEM(lightLevel,ii) = std(squintMeanVec,'omitmissing')/sqrt(sum(~isnan(nTimePoints)));
        end
    end

    figure(figHangle)
    plotColors = {'k','y'};
    myWeibullFit = @(x,p) p(3).* p(3).*(1 - exp(-(x./p(1)).^p(2)));
    myLogisticFit = @(x,p) p(3).* (1 ./ (1 + exp(-p(2).*(x-p(1)))));
    ylabels = {'Proportion max closure','Proportion closure per second'};
    xFit = 0:0.1:3;

    for mm = 1:2
        for lightLevel = 1:2

            subplot(2,length(sessions),sess+(mm-1)*length(sessions));

            switch mm
                case 1
                    dataVec = maxCloseMean(lightLevel,:);
                    semVec = maxCloseSEM(lightLevel,:);
                    ub = [1.5 6 1];
                    lb = [0.5 2.5 1];
                    x0 = [1 4 1];
                    myObj = @(p) norm((dataVec - myWeibullFit(psiLevelsLog,p)).*(1./semVec));
                    myObj = @(p) norm(dataVec - myWeibullFit(psiLevelsLog,p));
                    myFit = @(p) myWeibullFit(xFit,p);
                case 2
                    dataVec = aucSquintMean(lightLevel,:);
                    semVec = aucSquintSEM(lightLevel,:);
                    ub = [20 20 0.57];
                    lb = [0 2 0.57];
                    x0 = [1 3 0.57];
                    myObj = @(p) norm((dataVec - myLogisticFit(psiLevelsLog,p)).*(1./semVec));
                    myFit = @(p) myLogisticFit(xFit,p);
            end

            % Plot a sigmoidal fit to the data
            p = fmincon(myObj,x0,[],[],[],[],lb,ub);
            pStore(sess,mm,lightLevel,:) = p;
            yFit = myFit(p);
            plot(xFit,yFit,'-','Color','r');
            hold on

            % Add the SEM error bars
            for ii = 1:5
                plot([psiLevelsLog(ii),psiLevelsLog(ii)],[dataVec(ii)+aucSquintSEM(ii),dataVec(ii)-aucSquintSEM(ii)],...
                    '-','Color',[0.5 0.5 0.5],'LineWidth',1.5);
            end

            % Plot the data points
            plot(psiLevelsLog,dataVec,'.','Color',plotColors{lightLevel},'MarkerSize',20);

        end
        if sess == 1
            ylabel(ylabels{mm});
            xlabel('puff pressure [log_1_0 PSI]');
        else
            set(gca,'YTick',[]);
        end
        if mm == 1
            title(sprintf('%d lux',achievedLux(sess)));
        end
        xlim([0 2]);
        box off
        set(gca,'TickDir','out');

    end
end
