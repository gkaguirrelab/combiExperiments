%% To extract audio track and puff auditory signature

subjectID = 'HERO_gka';
experimentName = 'blinkResponse';
whichDirection = 'LightFlux';


mList=dir('*trial*avi');
nVids = length(mList);

audioX = nan(nVids,21000);
imageX = nan(nVids,450);
fsVals = nan(1,nVids);

cropY = 150:325;
cropX = 200:425;
myTempDir = tempdir;

for ii = 1:nVids
    filename = mList(ii).name;
    [~,filestem]=fileparts(filename);
    % Convert the avi to mov using ffmpeg (as close to lossless as possible)
    newfile = fullfile(myTempDir,[filestem '.mov']);
    command = ['ffmpeg -i ' filestem '.avi -c:v prores_ks -profile:v 4 -c:a pcm_s16le ' newfile];
    system(command);

    % Obtain the std of the audio track
    [y, fsVals(ii)] = audioread(newfile);
    audioX(ii,1:length(y)) = movstd(y,5);

    % Obtain the mean image within the crop area
    v = VideoReader(newfile);
    video = read(v);
    video = squeeze(video(:,:,1,:));
    video = video(cropY,cropX,:);
    imageX(ii,1:size(video,3)) = squeeze(mean(mean(video,1),2));
    clear v

    % Delete the mov file
    command = ['rm ' newfile];
    system(command);

end

save('/Users/aguirre/Desktop/puffBlinkData.mat','audioX','imageX','mList');

sequenceSet{1} = [3,3,1,4,5,5,4,1,2,3,2,2,1,5,3,4,4,3,5,2,4,2,5,1,1,3];
sequenceSet{2} = [3,3,2,5,3,5,2,4,3,4,1,1,5,1,3,1,2,2,1,4,4,5,5,4,2,3];
sequenceSet{3} = [3,3,4,2,5,3,2,4,5,1,4,1,1,5,4,4,3,5,5,2,1,2,2,3,1,3];
sequenceSet{4} = [3,3,1,4,5,1,2,2,3,2,1,3,4,2,4,4,3,5,2,5,5,4,1,1,5,3];

modContrastLevels = [0,0.25];


for cc = 1:2
    thisContrast = modContrastLevels(cc);
    for ll = 1:5
        dataMatrix = nan(40,450);
        count = 1;
        for bb = 1:2
            for ss = 1:4
                idx = find(sequenceSet{ss}==ll);
                for ii = 1:length(idx)
                    if idx(ii)>1
                        filename = sprintf( [subjectID '_' experimentName ...
                            '_direction-' whichDirection '_contrast-%2.2f_block-%d_sequence-%d' ...
                            '_trial-%02d_side-R.avi'],...
                            thisContrast,bb,ss,idx(ii));
                        entryIdx = find(strcmp({mList.name},filename));
                        dataMatrix(count,:)=imageX(entryIdx,:);
                        count = count+1;
                    end
                end
            end
        end
        dataStruct(cc,ll).mean = mean(dataMatrix);
        dataStruct(cc,ll).sem = std(dataMatrix) / sqrt(count);
    end
end


t = (0:450-1) / 180;

figure
for ii = 1:5
    yVals = dataStruct(1,ii).mean;
    yVals = yVals - mean(yVals(1:150));
    yVals = yVals / 25.677;
    plot(t,yVals)
    hold on
end
ylim([-0.1 1]);

figure
for ii = 1:5
    yVals = dataStruct(2,ii).mean;
    yVals = yVals - mean(yVals(1:150));
    yVals = yVals / 18 ;
    plot(t,yVals)
    hold on
end
ylim([-0.1 1]);

save('/Users/aguirre/Desktop/puffBlinkData.mat','audioX','imageX','mList','dataStruct');

