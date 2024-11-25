function measurement_matrix = filterGoodChunks(fps_measurements, frames_captured)
    % Define a matrix of the two measurements together 
    measurement_matrix = [fps_measurements, frames_captured];
                    

    % Select GOOD chunks based on the rule
    % 1. Frame count 2406 (regardless of fps)
    % 2. fps 200.5 (regardless of frame count)
    % 3. framecount * fps == XX (which is the slope line of that set of blue skyscrapers aka good points), as long as fps is not < YY, or count is not < ZZ
    XX = 8.8509; 
    YY = 200;
    ZZ = 2404;

    % First, select the points at which we know the chunk is good without any calculation 
                        % Find indices where FPS == 200.5            % Find indices where captured frames == 2406
    rule_onetwo_idx = union(find(measurement_matrix(:, 1) >= 200.5), find(measurement_matrix(:, 2) >= 2406));

    % Then, select on the more complicated variable rule
                      % First find the indices that meet the prescribed cutofffs
    %rule_three_idx = intersect(find(measurement_matrix(:, 1) > YY), find(measurement_matrix(:, 2) > ZZ)); 
    %rule_three_idx = union(find(measurement_matrix(rule_three_idx, 1) .* measurement_matrix(rule_three_idx, 2) == XX), rule_three_idx);

    %rule_three_idx = intersect(find(measurement_matrix(:, 1) >= 200), find(measurement_matrix(:, 2) >= 2405));

    % Combine all of the good indices together 
    %good_rows = union(rule_onetwo_idx, rule_three_idx);

    good_rows = rule_one_two_idx;

    % Select and return only the good measurements
    measurement_matrix = measurement_matrix(good_rows, :);

end