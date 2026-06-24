function realTimeSpectralModulationVideo(modResult)
%% Smooth Real-Time (53s) Silent Substitution Three-Panel Animation
% Panel 1: Sinusoidal contrast timeline cleanly anchored from 0-60s, starting loop at t=7s.
% Panel 2: The dynamic spectral power distribution change drawn in black.
% Panel 3: Dynamic absolute isomerization rates with a cyan Melanopsin bar.

% 1. Define wavelength range (visible range)
S = modResult.meta.cal.rawData.S;
wavelengths = SToWls(S);

% 2. Pull the spectra out of the modResult
background = modResult.backgroundSPD';
positive = modResult.positiveModulationSPD';
negative = modResult.negativeModulationSPD';

% Pull out the T_receptors that we want; make them quantal
T_receptors = modResult.meta.T_receptors([6,7,5,4],:);

% 3. Call the multi-panel visualization function
videoFilename = 'smooth_silent_substitution.mp4';
generateSmoothThreePanelVideo(wavelengths, background, positive, negative, T_receptors, videoFilename);

%% Core Function for Video Generation
function generateSmoothThreePanelVideo(wl, bg, pos, neg, T_receptors, filename)
    % Timing Constraints
    totalTimeline = 60;         % Total timeline width in seconds
    startTime = 7;              % Playback starts exactly at 7 seconds
    fps = 30;                   % High frame rate for silky smooth video
    numFrames = (totalTimeline - startTime) * fps; % 53 * 30 = 1590 total frames
    
    % Active animation time vector from exactly 7s to 60s
    timeVec = linspace(startTime, totalTimeline, numFrames);
    
    % Absolute mapping function: shifted by pi so t=0 starts at 0 contrast moving into negative values
    timeToPhase = @(t) ((t / totalTimeline) * (2 * pi)) + pi;
    
    % Pre-calculate the maximum spectral value to fix the line 58 syntax error
    maxSpectralVal = max([max(pos), max(neg), max(bg)]);
    yLimitSpectrum = maxSpectralVal * 1.2;
    
    % Clean definition of the RGB matrix (S, Mel, M, L rows)
    barColors = [0, 0, 1; 0, 1, 1; 0, 1, 0; 1, 0, 0];
    
    % Setup VideoWriter with H.264 compression
    v = VideoWriter(filename, 'MPEG-4');
    v.FrameRate = fps;
    v.Quality = 95; 
    open(v);
    
    % Set up figure window (hidden during render for performance)
    fig = figure('Position', [30, 100, 1600, 520], 'Color', 'w', 'Visible', 'off');
    
    % --- Define Global Font Sizes ---
    titleFontSize = 20;
    labelFontSize = 17;
    axisFontSize  = 15;
    
    % Pre-calculate the exact history line from 0 to 7 seconds based on the negative-going wave
    historyTime = linspace(0, startTime, 200);
    historyContrast = sin(timeToPhase(historyTime));
    
    fprintf('Rendering %d frames starting firmly from t = 7s (Phase shifted by pi). Please wait...\n', numFrames);
    
    for f = 1:numFrames
        current_time = timeVec(f);
        
        % Calculate phase and contrast cleanly anchored to the absolute timeline
        theta = timeToPhase(current_time);
        m = sin(theta);
        
        % Calculate current spectrum based on modulation phase
        if m >= 0
            current_spectrum = bg + m * (pos - bg);
        else
            current_spectrum = bg + abs(m) * (neg - bg);
        end
        
        % Compute absolute photoreceptor isomerization rates
        isomerization_rates = calculateRelativeIsomerizationRates(current_spectrum, T_receptors);
        
        % --- PANEL 1: Modulation Timeline ---
        subplot(1, 3, 1);
        cla; hold on; grid on;
        
        % 1. Plot the pre-rendered history line strictly from 0 to 7 seconds
        plot(historyTime, historyContrast, 'k-', 'LineWidth', 3);
        
        % 2. Plot the live running line from 7 seconds up to the current frame
        if f > 1
            plot(timeVec(1:f), sin(timeToPhase(timeVec(1:f))), 'k-', 'LineWidth', 3);
        end
        
        % 3. Draw the tracker dot at its absolute timeline position
        plot(current_time, m, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 11, 'LineWidth', 2);
        
        % Explicitly freeze limits and prevent auto-scaling engine jumps
        xlim([0 totalTimeline]);
        ylim([-1.2 1.2]);
        set(gca, 'XLimMode', 'manual', 'YLimMode', 'manual', ...
                 'FontSize', axisFontSize, 'LineWidth', 1.5);
             
        xlabel('Time (seconds)', 'FontSize', labelFontSize, 'FontWeight', 'bold');
        ylabel('Contrast', 'FontSize', labelFontSize, 'FontWeight', 'bold');
        title('Sinusoidal Modulation Course', 'FontSize', titleFontSize, 'FontWeight', 'bold');
        
        % --- PANEL 2: Spectral Content Modulation ---
        subplot(1, 3, 2);
        cla; hold on; grid on;
        
        % Plotting spectral distribution
        plot(wl, current_spectrum, 'Color', 'k', 'LineWidth', 3.5);
        
        xlim([min(wl) max(wl)]);
        ylim([0 yLimitSpectrum]);
        set(gca, 'XLimMode', 'manual', 'YLimMode', 'manual', ...
                 'FontSize', axisFontSize, 'LineWidth', 1.5);
             
        xlabel('Wavelength (nm)', 'FontSize', labelFontSize, 'FontWeight', 'bold');
        ylabel('Spectral Power Distribution', 'FontSize', labelFontSize, 'FontWeight', 'bold');
        title('Modulation of Spectral Content', 'FontSize', titleFontSize, 'FontWeight', 'bold');
        
        % --- PANEL 3: Absolute Isomerization Rate Bar Plot ---
        subplot(1, 3, 3);
        cla; hold on; grid on;
        
        % Generate the bar chart and assign the entire color block matrix directly
        hBar = bar(1:4, isomerization_rates, 'FaceColor', 'flat', 'EdgeColor', [0.2 0.2 0.2], 'LineWidth', 1.5);
        hBar.CData = barColors;
        
        ylim([0 14]); 
        set(gca, 'YLimMode', 'manual', 'XTick', 1:4, 'XTickLabel', {'S', 'Mel', 'M', 'L'}, ...
                 'FontSize', axisFontSize, 'FontWeight', 'bold', 'LineWidth', 1.5);
        ylabel('Isomerization Rate (au)', 'FontSize', labelFontSize, 'FontWeight', 'bold');
        title('Absolute Isomerization Rate', 'FontSize', titleFontSize, 'FontWeight', 'bold');
        
        % Capture the static, rigid layout and write to the MP4 file
        frame = getframe(fig);
        writeVideo(v, frame);
    end
    
    % Clean up
    close(v);
    close(fig);
    fprintf('Success! Rigid, smoothly rendered video saved as "%s"\n', filename);
end
end

%% Photoreceptor Isomerization Rate Calculation Function
function rates = calculateRelativeIsomerizationRates(current_spectrum, T_receptorsQuantal)
    rates = zeros(1, size(T_receptorsQuantal, 1));
    for ii = 1:size(T_receptorsQuantal, 1)
        rates(ii) = sum(current_spectrum .* T_receptorsQuantal(ii, :));
    end
end