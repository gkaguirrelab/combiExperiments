%% Code to plot the Bayesian two sigma model with various levels of
% prior probability of same
% Note you may have to edit the model code to make this work

figure;
ax = axes;
hold(ax, 'on');

x = -5:0.1:5;
priorSames = [0.3 0.4 0.5 0.6 0.7 0.8];

lightGreen = [0.7 1.0 0.7];
darkGreen  = [0.0 0.5 0.0];

for ii = 1:numel(priorSames)
    t = (ii-1)/(numel(priorSames)-1);
    color = (1-t)*lightGreen + t*darkGreen; % going from light to dark green

    y = bayesianSameDiffModelTwoSigma(x, [0.3 0.8], priorSames(ii));

    plot(ax, x, y, ...
        'LineWidth', 2, ...
        'Color', color);
end

xlabel('stimulus difference [dB]');
ylabel('P(respond different)');
ylim([0 1]);
xlim([-6 6]);
title('Bayesian two sigma model: varying prior probability of same');
box on;

%% Code to plot the Bayesian two sigma model with various levels of sigma
figure;
ax = axes;
hold(ax, 'on');

x = -5:0.1:5;
priorSame = 0.5;
sigmaZeros = linspace(0.01, 1, 6);
sigmas = arrayfun(@(v) [0.5, v], sigmaZeros, 'UniformOutput', false);

lightBlue = [0.7 0.8 1.0];
darkBlue  = [0.0 0.0 0.6];

for ii = 1:numel(sigmas)
    t = (ii-1)/(numel(sigmas)-1);
    color = (1-t)*lightBlue + t*darkBlue;

    y = bayesianSameDiffModelTwoSigma(x, sigmas{ii}, priorSame);

    plot(ax, x, y, ...
        'LineWidth', 2, ...
        'Color', color);
end

xlabel('stimulus difference [dB]');
ylabel('P(respond different)');
ylim([0 1]);
xlim([-6 6]);
title('Bayesian two sigma model: varying sigma zero level');
box on;
