function plotPolarBivariateEllipse(amplitude,phase,options)


%% argument block
arguments
    amplitude
    phase
    options.MarkerSymbol = '+';
    options.MarkerFaceColor = [1 0 0];
    options.MarkerEdgeColor = [1 0 0];
    options.FillEdgeColor = [1 0 0];
    options.FillFaceColor = [1 0 0];
    options.FillFaceAlpha = 0.2;
    options.errorType = 'sd';
end

% Calculate the mean and covariance in Cartesian coordinates
[x, y] = pol2cart(phase, amplitude);
mu_x = mean(x);
mu_y = mean(y);
data_matrix = [x', y'];
C = cov(data_matrix); % Covariance matrix of the data
n = length(amplitude);
switch     options.errorType
    case 'sd'
        error_C = C;        % Covariance of the Mean (Standard Error)
    case 'sem'
        error_C = C / n;        % Covariance of the Mean (Standard Error)
end

% Generate the Error Ellipse Points
t = linspace(0, 2*pi, 100);
unit_circle = [cos(t); sin(t)];

% Matrix square root via Eigen decomposition to scale and rotate the ellipse
[V, D] = eig(error_C);
ellipse_cart = V * sqrt(D) * unit_circle + [mu_x; mu_y];

% Convert Ellipse and Mean back to Polar for plotting
[el_theta, el_rho] = cart2pol(ellipse_cart(1,:), ellipse_cart(2,:));
[mu_theta, mu_rho] = cart2pol(mu_x, mu_y);

% Plot the data
polarplot(el_theta, el_rho, '-','Color', options.FillEdgeColor,'MarkerEdgeColor',options.FillEdgeColor);
hold on
fill(el_theta, el_rho, options.FillFaceColor, 'FaceAlpha', options.FillFaceAlpha);
polarplot(el_theta, el_rho, '-','Color', options.FillEdgeColor,'MarkerEdgeColor',options.FillEdgeColor);
if ~strcmp(options.MarkerSymbol,'none')
polarplot(mu_theta, mu_rho, options.MarkerSymbol,'Color', options.MarkerFaceColor,'MarkerEdgeColor',options.MarkerEdgeColor);
end
grid on;

end