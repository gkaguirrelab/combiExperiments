% Create an illustration of continuous psychophysics nulling of a flicker

pertubation = [0 0 0 0 0 sign(rand(1,60)-0.5)];
pertVec = [];
for ii = 1:length(pertubation)
    pertVec = [pertVec, repmat(pertubation(ii),1,10)];
end
pertVec = pertVec - mean(pertVec);

timebase = linspace(0,10,length(pertVec));

% Create a gamma kernel
g1 = gampdf(timebase*60,20,1);
g1 = circshift(g1,(length(pertVec)/10)*1);
g2 = gampdf(timebase*10,1.5,1);

pertNoiseVec = pertVec + (randn(size(pertVec)))*4;
pertNoiseVec = pertNoiseVec - mean(pertNoiseVec);

track = conv2(pertNoiseVec,g1);

figure
plot(timebase,pertVec);
hold on
plot(timebase,track(1:length(pertVec)));

% Create two log-normal Gausians
timeLin = linspace(-0.5,1.5,150);
timeLog = logspace(log10(2),log10(0.01),150);
signal = circshift(normpdf(timeLog,0.5,0.14),20)/20;
noise = randn(size(signal))/100;
noise = noise - mean(noise);

f1 = figure();
figuresize(200,400,'pt');
set(gcf,'color','w');


tiledlayout(2,1)
nexttile
plot(timeLin,signal,'-b');
hold on
plot(timeLin,signal+noise,'-k')
ylim([-0.05 0.2]);

signal = circshift(normpdf(timeLog,0.5,0.2),30)/20;
noise = randn(size(signal))/100;
noise = noise - mean(noise);
nexttile
plot(timeLin,signal,'-b');
hold on
plot(timeLin,signal+noise,'-k')
ylim([-0.05 0.2]);
