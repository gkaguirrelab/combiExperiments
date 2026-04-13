function plot_photoreceptor_space()
    % Vector directions (normalized)
    v_mel = [0, 0, 1];
    v_s   = [0, 1, 0];
    v_lms = [1, 1, 0];
    v_lmsm = [1, 1, 1];

    vectors = {v_mel, v_s, v_lms, v_lmsm};
    colors = {[0 1 1], [0 0 1], [1 0.9 0], [0 0 0]}; 
    tipLabels = {'Mel', 'S', 'LMS', 'LF'};

    figure('Color', 'w', 'Renderer', 'opengl');
    ax = gca; hold on; axis equal;
    
    boxPos = 1.0; 
    limit = 1.3; 
    xlim([-limit, limit]); ylim([-limit, limit]); zlim([-limit, limit]);

    % --- MANUAL GRAY FRAME ---
    frameLW = 0.5;             
    frameColor = [0.7 0.7 0.7]; 
    box_pts = [-boxPos, boxPos];
    for i = 1:2
        for j = 1:2
            line(box_pts, [box_pts(i) box_pts(i)], [box_pts(j) box_pts(j)], 'Color', frameColor, 'LineWidth', frameLW);
            line([box_pts(i) box_pts(i)], box_pts, [box_pts(j) box_pts(j)], 'Color', frameColor, 'LineWidth', frameLW);
            line([box_pts(i) box_pts(i)], [box_pts(j) box_pts(j)], box_pts, 'Color', frameColor, 'LineWidth', frameLW);
        end
    end

    % --- THIN GRAY AXES ---
    axisLineColor = [0.8 0.8 0.8];
    line([-boxPos boxPos], [0 0], [0 0], 'Color', axisLineColor, 'LineWidth', 0.5);
    line([0 0], [-boxPos boxPos], [0 0], 'Color', axisLineColor, 'LineWidth', 0.5);
    line([0 0], [0 0], [-boxPos boxPos], 'Color', axisLineColor, 'LineWidth', 0.5);

    % --- INTERNAL ORIGIN PLANES ---
    planeAlpha = 0.05;
    patch([-boxPos boxPos boxPos -boxPos], [-boxPos -boxPos boxPos boxPos], [0 0 0 0], ...
          [0.5 0.5 0.5], 'FaceAlpha', planeAlpha, 'EdgeColor', 'none');
    patch([-boxPos boxPos boxPos -boxPos], [0 0 0 0], [-boxPos -boxPos boxPos boxPos], ...
          [0.5 0.5 0.5], 'FaceAlpha', planeAlpha, 'EdgeColor', 'none');

    % --- CENTRAL GRAY SPHERE (FLAT) ---
    [sx, sy, sz] = sphere(30);
    sphereRadius = 0.05;
    surf(sx*sphereRadius, sy*sphereRadius, sz*sphereRadius, ...
        'FaceColor', [0.6 0.6 0.6], 'EdgeColor', 'none', ...
        'FaceLighting', 'none', 'FaceAlpha', 1.0); % <-- Removed shading

    % --- VECTORS AND TIP LABELS ---
    for i = 1:length(vectors)
        v = vectors{i};
        c = colors{i};
        L = 1.0; coneH = 0.20; coneR = 0.053;

        % Positive arm
        drawSingleConeVector([0 0 0], v*L, coneH, coneR, c, '-', 1.0, 1.0);
        % Negative arm
        drawSingleConeVector([0 0 0], -v*L, coneH, coneR, c, ':', 0.1, 0.5);

        text(v(1)*1.15, v(2)*1.15, v(3)*1.15, tipLabels{i}, ...
            'Color', c, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    end

    axis off; 
    view(60, 20);
    % Lighting commands removed to prevent interference
end

function drawSingleConeVector(p1, p2, h, r, col, style, coneAlpha, lineAlpha)
    vec = p2-p1; len = norm(vec); dir = vec/len;
    stemEnd = p1 + dir*(len-h);
    line([p1(1) stemEnd(1)], [p1(2) stemEnd(2)], [p1(3) stemEnd(3)], ...
        'Color', [col lineAlpha], 'LineWidth', 2.5, 'LineStyle', style);
        
    [xc, yc, zc] = cylinder([r, 0], 30); zc = zc*h;
    zAx = [0 0 1];
    if all(abs(dir-zAx)<1e-6), R=eye(3); elseif all(abs(dir+zAx)<1e-6), R=diag([1 1 -1]);
    else
        v_rot = cross(zAx, dir); s_rot = norm(v_rot); c_rot = dot(zAx, dir);
        V_skew = [0 -v_rot(3) v_rot(2); v_rot(3) 0 -v_rot(1); -v_rot(2) v_rot(1) 0];
        R = eye(3) + V_skew + V_skew^2*((1-c_rot)/s_rot^2);
    end
    pts = R*[xc(:)'; yc(:)'; zc(:)'];
    xc = reshape(pts(1,:), size(xc)) + stemEnd(1);
    yc = reshape(pts(2,:), size(yc)) + stemEnd(2);
    zc = reshape(pts(3,:), size(zc)) + stemEnd(3);
    
    % Render with 'FaceLighting' set to 'none'
    surf(xc, yc, zc, 'FaceColor', col, 'EdgeColor', 'none', ...
        'FaceAlpha', coneAlpha, 'FaceLighting', 'none'); 
end