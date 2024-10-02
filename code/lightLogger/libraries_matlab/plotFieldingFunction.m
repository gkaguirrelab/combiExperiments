dropboxBaseDir = getpref('combiExperiments','dropboxBaseDir');
numDataPath = fullfile(dropboxBaseDir,'FLIC_admin','Equipment','SpectacleCamera','calibration','numerical_data');
fieldingFuncPath = fullfile(numDataPath,'fielding_function.mat');
bayerMatrixPath = fullfile(numDataPath,'pixel_matrix.mat');

load(fieldingFuncPath,'fielding_function');
load(bayerMatrixPath,'pixel_matrix');

plotColors = {'r','g','b'};
figure
tiledlayout(1,3,"TileSpacing","compact","Padding","none")
for pp = 1:3
    Z = fielding_function;
    Z(pixel_matrix ~= pp-1) = nan;
    Z = fliplr(flipud(fillmissing(Z,'linear')));
    nexttile
    imagesc(Z)
    axis equal
    ylim([0 size(fielding_function,1)])
    axis off
    title(['sensor channel ' plotColors{pp}])
    colorbar; 
end




