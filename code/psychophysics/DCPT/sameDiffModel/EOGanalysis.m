% SETUP
% Defining the directory
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
experimentName = 'DCPT_SDT';

% Define subjects + parameters
% Control subject IDs: {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', ...
% 'FLIC_0018', 'FLIC_0019','FLIC_0020', 'FLIC_0021', 'FLIC_0022', 'FLIC_0027', 
% 'FLIC_0028','FLIC_0039', 'FLIC_0042'};
% Migraine subject IDs: {'FLIC_1016','FLIC_1029','FLIC_1030','FLIC_1031',
%                         'FLIC_1034','FLIC_1038'}; 
% Had to take out 'FLIC_0028' for controls bc haven't done the fitting with her
subjectID = {'FLIC_1016','FLIC_1029','FLIC_1030','FLIC_1031',...
                         'FLIC_1034','FLIC_1038'}; 
modDirection = 'LightFlux';
NDLabel = {'3x0', '0x5'};   % {'3x0', '0x5'}
stimParamLabels = {'low', 'hi'}; % {'low', 'hi'}
refFreqHz = logspace(log10(10),log10(30),5);  % logspace(log10(10),log10(30),5)
targetPhotoContrast = {'0x1','0x3'};  % {'0x1','0x3'}

% Define length variables
nFreqs = length(refFreqHz);
nContrasts = length(targetPhotoContrast);
nLightLevels = length(NDLabel); 
nSubj = length(subjectID);
nSides = length(stimParamLabels); 

%% 

% Preallocate a cell array to store 40 structs (one per trial) per condition
allEOG = cell(nSubj, nLightLevels, nFreqs, nContrasts, nSides);
% Storing the average of the max amplitude values for this condition
meanStdDevEOG = zeros(nSubj, nLightLevels, nFreqs, nContrasts, nSides);

% Loading files and extracting the data 
for subjIdx = 1:nSubj
    thisSubj = subjectID{subjIdx};

    for lightIdx = 1:nLightLevels
        for refFreqIdx = 1:nFreqs
            currentRefFreq = refFreqHz(refFreqIdx);

            for contrastIdx = 1:nContrasts

                comboTrialData = [];

                for sideIdx = 1:nSides
                    % Build path to the data file
                    subjectDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, thisSubj);
                    dataDir = fullfile(subjectDir, [modDirection '_ND' NDLabel{lightIdx} '_shifted'], experimentName);

                    fileName = fullfile(dataDir, ...
                        [thisSubj '_' modDirection '_' experimentName ...
                        '_cont-' targetPhotoContrast{contrastIdx} '_refFreq-' num2str(currentRefFreq) 'Hz_' stimParamLabels{sideIdx} '.mat']);

                    if exist(fileName, 'file')
                        load(fileName, 'psychObj');
                        thisTrialData = psychObj.questData.trialData;

                        trialStructs = [thisTrialData.EOGdata];
                        nTrials = numel(trialStructs);

                        % store the 40 structs
                        allEOG{subjIdx, lightIdx, refFreqIdx, contrastIdx, sideIdx} = trialStructs;

                        % Calculating standard deviation of EMG
                        % for each trial in this condition
                        for t = 1:nTrials
                            % Second row of response is EMG
                            emg_signal = trialStructs(t).response(1,:); 
                            trialStdDev(t) = std(emg_signal);  % peak-to-peak amplitude
                        end

                        % Averaging across trials and storing
                        meanStdDevEOG(subjIdx, lightIdx, refFreqIdx, contrastIdx, sideIdx) = mean(trialStdDev);

                    else
                        warning('File not found: %s', fileName);
                    end
                   
                end % sideIdx
            end
        end
    end
end

% Average std deviation EMG value across side
meanStdDevEOG = squeeze(mean(meanStdDevEOG, 5)); 

for lightIdx = 1:nLightLevels
    for contrastIdx = 1:nContrasts

        % Slice the data: subjects × freqs for this light × contrast
        thisData = squeeze(meanStdDevEOG(:, lightIdx, :, contrastIdx));  % nSubj × nFreqs

        % Flatten the data into a column vector for plotSpread
        yData = thisData(:);  % all subjects × freqs in one column

        % Create colors and categoryIdxs for plotSpread
        colors = lines(nSubj);

        distIdx = repmat(1:nFreqs, nSubj, 1);
        distIdx = distIdx(:);      
       % plot the first nSubj rows at the first ref freq

        categoryIdx = repmat((1:nSubj)', nFreqs, 1)
        categoryIdx = categoryIdx(:);  % plot the first nSubj rows at the
        % first ref freq

        % x-axis positions = reference frequencies repeated for each subject
        xValues = 1:5;

        fig = figure;
        ax = axes(fig);
        hold(ax, 'on');

        H = plotSpread(yData, ...
            'xValues', xValues, ...
            'distributionIdx', distIdx, ...
            'categoryIdx', categoryIdx, ...
            'categoryColors', colors);

        % Customizing the marker
        for h = 1:numel(H{1})
            c = get(H{1}(h), 'Color');  % get the current line color
            cFaint = c + (1 - c)*0.5;   % blend 70% with white
            set(H{1}(h), 'Marker', 's', ...
                'MarkerSize', 8, ...
                'MarkerFaceColor', cFaint, ...
                'MarkerEdgeColor', cFaint);
        end

        % Connecting the points for each subject
        % Extract the XY positions from plotSpread output
        xy = get(H{1}, 'XData');
        yy = get(H{1}, 'YData');

        allX = cell2mat(xy(:)');
        allY = cell2mat(yy(:)');
        % plotSpread reorders by categoryIdx. so now indices 1-5 are subj1,
        % indices 6-10 are subj2, and so on.

        for s = 1:nSubj
            idx = (s-1)*nFreqs + (1:nFreqs);

            % draw line
            h = plot(allX(idx), allY(idx), '-', ...
                'Color', colors(s,:), ...
                'LineWidth', 1, ...
                'MarkerSize', 6, ...
                'MarkerFaceColor', colors(s,:));

            h.Color(4) = 0.2; % make the lines more transparent
        end

        % Compute mean and standard error across subjects for each frequency
        % for k = 1:nFreqs
        %     thisFreq = subjData{k};
        %     meanValues(k) = mean(thisFreq);  % mean across subjects for this frequency
        %     semValues(k)  = std(thisFreq) / sqrt(nSubj);  % SEM
        % end
        % hMean = errorbar(xValues, meanValues, semValues, ...
        %     '-ks', ...
        %     'MarkerFaceColor', 'k', ...
        %     'MarkerSize', 10, ...
        %     'LineWidth', 1.5);

        % Title and labels
        title('False alarm rates across reference frequencies', 'FontWeight', 'bold');
        xlabel('Reference frequency [Hz]');
        ylabel('Mean Std Dev EOG');
        ylim([0 0.5]);
        title(sprintf('Light %s, Contrast %s', NDLabel{lightIdx}, targetPhotoContrast{contrastIdx}));
        xticklabels(refFreqHz); 

        hold(ax, 'off');

    end
end

