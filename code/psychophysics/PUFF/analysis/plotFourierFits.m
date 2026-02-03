function plotFourierFits(amplitude,phase,symbolColor)

% Calculate the mean and covariance in Cartesian coordinates
[x, y] = pol2cart(phase, amplitude);
mu_x = mean(x);
mu_y = mean(y);
data_matrix = [x', y'];
C = cov(data_matrix); % Covariance matrix of the data
n = length(amplitude);
SEM_C = C / n;        % Covariance of the Mean (Standard Error)

% Generate the Error Ellipse Points (1 Standard Error)
t = linspace(0, 2*pi, 100);
unit_circle = [cos(t); sin(t)];

% Matrix square root via Eigen decomposition to scale and rotate the ellipse
[V, D] = eig(SEM_C);
ellipse_cart = V * sqrt(D) * unit_circle + [mu_x; mu_y];

% Convert Ellipse and Mean back to Polar for plotting
[el_theta, el_rho] = cart2pol(ellipse_cart(1,:), ellipse_cart(2,:));
[mu_theta, mu_rho] = cart2pol(mu_x, mu_y);

% Plot the data
% figHandle = figure();

polarplot(phase, amplitude, 'o', 'MarkerFaceColor', symbolColor, 'MarkerEdgeColor',[0.7 0.7 0.7], 'DisplayName', 'Data Points'); 
hold on;
polarplot(el_theta, el_rho, 'r-', 'LineWidth', 2, 'DisplayName', 'Standard Error (SEM)');
polarplot(mu_theta, mu_rho, 'r+', 'MarkerSize', 12, 'MarkerFaceColor', 'r', 'DisplayName', 'Mean Vector');
grid on;
end