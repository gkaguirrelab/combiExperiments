% For DCPT discrim task:
% Code runs 3 blocks of staircase and then 7 blocks of Quest+

% Set subject ID 
subjectID = 'HERO_rsb';
NDlabel = '0x5';
EOGFlag = true;

% 3 blocks of staircase
runDCPT_discrim(subjectID,NDlabel, EOGFlag, 'nBlocks', 3, 'useStaircase', true);

% 7 blocks of Quest+
runDCPT_discrim(subjectID,NDlabel, EOGFlag, 'nBlocks', 7, 'useStaircase', false);
