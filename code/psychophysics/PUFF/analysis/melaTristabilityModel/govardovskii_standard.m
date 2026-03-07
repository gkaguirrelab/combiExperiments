function S = govardovskii_standard(lambda, lmax_val)
% Peak-normalized wavelength
x = lmax_val ./ lambda;

% Alpha band (Main absorbance)
alpha = 1 ./ (exp(69.7*(0.88 - x)) + exp(28*(0.922 - x)) + ...
    exp(-14.9*(1.104 - x)) + 0.674);

% Beta band (UV absorbance)
% The Beta band peak is determined by lmax
beta_peak = 189 + 0.315 * lmax_val;
beta_width = -40.5 + 0.195 * lmax_val;

% Standard Gaussian Beta band
beta = 0.26 * exp(-((lambda - beta_peak) ./ beta_width).^2);

% Critical fix for red tail convergence: Beta band must not leak into red
beta(lambda > lmax_val) = 0;

S = alpha + beta;
end