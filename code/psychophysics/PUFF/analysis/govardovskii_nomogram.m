function S = govardovskii_nomogram(lambda, lambda_max)
    % A1-based visual pigment template
    % lambda: wavelength vector (nm)
    % lambda_max: peak wavelength (nm)
    
    % Alpha band
    x = lambda_max ./ lambda;
    a = 69.7; b = 28; c = -14.9;
    A = 0.88; B = 0.922; C = 1.104; D = 0.674;
    
    alpha = 1 ./ (exp(a*(A - x)) + exp(b*(B - x)) + exp(c*(C - x)) + D);
    
    % Beta band
    beta_peak = 189 + 0.315 * lambda_max;
    beta_width = -40.5 + 0.195 * lambda_max;
    beta = 0.26 * exp(-((lambda_max ./ lambda - beta_peak ./ lambda_max) ./ (beta_width ./ lambda_max)).^2);
    
    S = alpha + beta;
end