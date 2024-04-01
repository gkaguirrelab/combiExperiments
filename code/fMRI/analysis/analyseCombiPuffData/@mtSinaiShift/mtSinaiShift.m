classdef mtSinaiShift < handle
    
    properties (Constant)
        
        % Properties of the search stages.
        nStages = 2;
        
        % A description of the model
        description = ...
            ['Find the gain for each stimulus component, \n' ...
            'and the parameters of an HRF model.\n'];
    end
    
    % Private properties
    properties (GetAccess=private)
        
        % The FLOBS eigenvectors
        flobsbasis
        
        % The multivariate normal means of the 3 eigenvectors
        mu
        
        % The multivariate normal covariance matrix
        C
        
        % The projection matrix used to regress our nuisance effects
        T

        % The current state of the regression matrix
        X

    end
    
    % Calling function can see, but not modify
    properties (SetAccess=private)

        % The number of elements of the stimulus matrix
        nStimTypes

        % The number of parameters in the model
        nParams

        % The number of separate acquisitions
        nAcqs
        
        % Properties of the search stages.
        floatSet
        fixSet
        
        % A vector of the length totalTRs x 1 that has an index value to
        % indicate which acquisition (1, 2, 3 ...) a data time
        % sample is from.
        dataAcqGroups
        
        % A vector of length totalTRs x 1 and in units of seconds that
        % defines the temporal support of the data relative to the time of
        % onset of the first TR of each acquisition.
        dataTime
        
        % TR of the data in seconds
        dataDeltaT
        
        % The stimulus vector, concatenated across acquisitions and
        % squished across x y. Thus it will have the dimensions:
        %	[totalST x*y]
        stimulus
        
        % A cell array of labels for the stimuli, used to label maps and
        % the result fields
        stimLabels
        
        % A particular stimulus label that corresponds to events that we
        % wish to regress out of the time-series prior to averaging across
        % acquisitions.
        confoundStimLabel

        % A cell array of vectors, each of which contains the indices that
        % are used to average together the timeseries data and model fit
        % across sets of acquisitions
        avgAcqIdx

        % A cell array of matrices, with the number of cells equal to the
        % numner of acquisitions. Each matrix is passed with the dimension
        % n x t, where t is the number of trs in that acquisition, and n is
        % the number of nuisance covariates that have been passed. The
        % matrix is subsequently transposed for storage in the obj
        % variable.
        nuisanceVars
        
        % A vector of length totalST x 1 that has an index value to
        % indicate which acquisition (1, 2, 3 ...) a stimulus time
        % sample is from.
        stimAcqGroups
        
        % A vector of length totalST x 1 and in units of seconds that
        % defines the temporal support of stimulus relative to the time of
        % onset of the first TR of each acquisition. If set to empty, the
        % stimTime is assumed to be equal to the dataTime.
        stimTime
        
        % The temporal resolution of the stimuli in seconds.
        stimDeltaT
        
        % A cell array that contains things that the model might want
        payload
        
        % A time x 1 vector that defines the HRF convolution kernel
        hrf
        
        % The type of HRF model, including {'flobs','gamma'};
        hrfType
        
    end
    
    % These may be modified after object creation
    properties (SetAccess=public)
        
        % The number of low frequencies to be removed from each acquisition
        polyDeg
        
        % Typical amplitude of the BOLD fMRI response in the data
        typicalGain
        
        % The lower and upper bounds for the model
        lb
        ub
        paraSD
        
        % A vector, equal in length to the number of parameters, that
        % specifies the smallest step size that fmincon will take for each
        % parameter. This threshold is also used to determine if, in a call
        % to obj.forward, the gaussvector needs to be re-calculated, or if
        % the prior value can be used.
        FiniteDifferenceStepSize
        
        % Verbosity
        verbose
        
    end
    
    methods
        
        % Constructor
        function obj = mtSinaiShift(data,stimulus,tr,varargin)
            
            % instantiate input parser
            p = inputParser; p.KeepUnmatched = false;
            
            % Required
            p.addRequired('data',@iscell);
            p.addRequired('stimulus',@iscell);
            p.addRequired('tr',@isscalar);
            
            p.addParameter('stimTime',{},@iscell);
            p.addParameter('stimLabels',{},@iscell);
            p.addParameter('payload',{},@iscell);
            p.addParameter('confoundStimLabel','',@ischar);
            p.addParameter('avgAcqIdx',{},@iscell);  
            p.addParameter('polyDeg',[],@isnumeric);
            p.addParameter('nuisanceVars',{},@iscell);  
            p.addParameter('typicalGain',1,@isscalar);
            p.addParameter('paraSD',15,@isscalar);
            p.addParameter('hrfType','flobs',@ischar);            
            p.addParameter('verbose',true,@islogical);
            
            % parse
            p.parse(data, stimulus, tr, varargin{:})
            
            % Create the dataTime and dataAcqGroups variables
            % Concatenate and store in the object.
            for ii=1:length(data)
                dataAcqGroups{ii} = ii*ones(size(data{ii},2),1);
                dataTime{ii} = (0:tr:tr*(size(data{ii},2)-1))';
            end
            obj.dataAcqGroups = catcell(1,dataAcqGroups);
            obj.dataTime = catcell(1,dataTime);
            obj.dataDeltaT = tr;
            obj.nAcqs = length(data);
            
            % Each row in the stimulus is a different stim type that will
            % be fit with its own gain parameter. Record how many there are
            obj.nStimTypes = size(stimulus{1},1);
            
            % The number of params is the number of stim types, plus three
            % for the form of the HRF plus a temporal shift for each
            % acquisition
            obj.nParams = obj.nStimTypes+obj.nAcqs+3;
            
            % Define the stimLabels
            if ~isempty(p.Results.stimLabels)
                stimLabels = p.Results.stimLabels;
                if length(stimLabels) ~= obj.nStimTypes
                    error('forwardModelObj:badStimLabels','The stimLabels value must be a cell array equal to the number of stimulus types.');
                end
            else
                stimLabels = cell(1,obj.nStimTypes);
                for pp = 1:obj.nStimTypes
                    stimLabels{pp} = sprintf('beta%02d',pp);
                end
            end
            obj.stimLabels = stimLabels;
            
            % Check the confoundStimLabel
            obj.confoundStimLabel = p.Results.confoundStimLabel;
            if ~isempty(obj.confoundStimLabel)
                if ~any(startsWith(obj.stimLabels,obj.confoundStimLabel))
                    error('forwardModelObj:badConfoundStimLabel','The confoundStimLabel must be present within the stimLabels array.');
                end
            end
            
            % Sanity check the avgAcqIdx
            obj.avgAcqIdx = p.Results.avgAcqIdx;
            if ~isempty(obj.avgAcqIdx)
                if length(unique(cellfun(@(x) length(x),obj.avgAcqIdx))) > 1
                    error('forwardModelObj:badAvgAcqIdx','The avgAcqIdx cell array must have vectors of equal length.');
                end
                if sum(cellfun(@(x) length(x),obj.avgAcqIdx)) ~= length(obj.dataTime)
                    error('forwardModelObj:badAvgAcqIdx','The total length of the indices in avgAcqIdx cell array must be equal to the total data length.');
                end
            end
            
            % Define the fix and float param sets
            % In this model, only the HRF parameters float. The gain
            % parameters are derived by regression
            obj.fixSet = {1:obj.nParams-(3+obj.nAcqs), 1:obj.nParams-(3+obj.nAcqs)};
            obj.floatSet = {obj.nParams-(2+obj.nAcqs):obj.nParams, obj.nParams-(2+obj.nAcqs):obj.nParams};
            
            % Create the stimAcqGroups variable. Concatenate the cells and
            % store in the object.
            for ii=1:length(stimulus)
                % Transpose the stimulus matrix within cells
                stimulus{ii} = stimulus{ii}';
                stimAcqGroups{ii} = ii*ones(size(stimulus{ii},1),1);
            end
            obj.stimulus = catcell(1,stimulus);
            obj.stimAcqGroups = catcell(1,stimAcqGroups);
            
            % Construct and / or check stimTime
            if isempty(p.Results.stimTime)
                % If stimTime is empty, check to make sure that the length
                % of the data and stimulus matrices in the time domain
                % match
                if length(obj.stimAcqGroups) ~= length(obj.dataAcqGroups)
                    error('forwardModelObj:timeMismatch','The stimuli and data have mismatched temporal support and no stimTime has been passed.');
                end
                % Set stimTime to empty
                obj.stimTime = [];
                % The temporal resolution of the stimuli is the same as the
                % temporal resolution of the data
                obj.stimDeltaT = tr;
            else
                % We have a stimTime variable.
                stimTime = p.Results.stimTime;
                % Make sure that all of the stimTime vectors are regularly
                % sampled (within 3 decimal precision)
                regularityCheck = cellfun(@(x) length(unique(round(diff(x),3))),stimTime);
                if any(regularityCheck ~= 1)
                    error('forwardModelObj:timeMismatch','One or more stimTime vectors are not regularly sampled');
                end
                % Make sure that the deltaT of the stimTime vectors all
                % match, and store this value
                deltaTs = cellfun(@(x) x(2)-x(1),stimTime);
                if length(unique(deltaTs)) ~= 1
                    error('forwardModelObj:timeMismatch','The stimTime vectors do not have the same temporal resolution');
                end
                obj.stimDeltaT = deltaTs(1);
                % Concatenate and store the stimTime vector
                for ii=1:length(stimTime)
                    % Transpose stimTime within cells
                    stimTime{ii} = stimTime{ii}';
                end
                obj.stimTime = catcell(1,stimTime);
                % Check to make sure that the length of the stimTime vector
                % matches the length of the stimAcqGroups
                if length(obj.stimTime) ~= length(obj.stimAcqGroups)
                    error('forwardModelObj:timeMismatch','The stimTime vectors are not equal in length to the stimuli');
                end
            end            

            % Sanity check the nuisanceVars. There should be as many cells
            % as there are acquisitions, and the lengh of each matrix in
            % each cell should be equal to the number of TRs in each
            % acquisition
            nuisanceVars = p.Results.nuisanceVars;
            if ~isempty(nuisanceVars)
                if length(data) ~= length(nuisanceVars)
                    error('forwardModelObj:dataMismatch','The nuisanceVars cells are not equal in length to the data cells');
                end
                for ii = 1:length(nuisanceVars)
                    if size(nuisanceVars{ii},2) ~= size(data{ii},2)
                        error('forwardModelObj:dataMismatch',sprintf('nuisanceVar matrix #%d has a number of TRs that differs with the data matrix',ii));
                    end
                    % Transpose rows and columns in the nuisanceVars for
                    % later construction of the projection matrix
                    nuisanceVars{ii} = nuisanceVars{ii}';
                end
            else
                nuisanceVars = repmat({[]},1,length(data));
            end
            obj.nuisanceVars = nuisanceVars;
            
            % Done with these big variables
            clear data stimulus stimTime acqGroups
            
            % Distribute other params to obj properties
            obj.payload = p.Results.payload;
            obj.polyDeg = p.Results.polyDeg;
            obj.typicalGain = p.Results.typicalGain;
            obj.paraSD = p.Results.paraSD;
            obj.hrfType = p.Results.hrfType;
            obj.verbose = p.Results.verbose;
            
            % Create and cache the flobs basis
            obj.genflobsbasis;
            
            % Set the bounds and minParamDelta
            obj.setbounds;
            
            % Create and cache the projection matrix
            obj.genprojection;
                        
            
        end
        
        % Required methds -- The forwardModel function expects these
        rawData = prep(obj,rawData)
        x0 = initial(obj)
        signal = clean(obj, signal)
        [c, ceq] = nonlcon(obj, x)
        fVal = objective(obj, signal, x)
        [fit, hrf] = forward(obj, x)
        x0 = update(obj,x,x0,floatSet,signal)
        [metric, signal, modelFit] = metric(obj, signal, x)
        seeds = seeds(obj, data, vxs)
        results = results(obj, params, metric)
        results = plot(obj, data, results)
        X = hrfX(obj,x)
        
        % Internal methods
        genflobsbasis(obj);
        setbounds(obj)
        genprojection(obj)
        
        % Set methods
        function set.polyDeg(obj, value)
            obj.polyDeg = value;
            obj.genprojection;
        end
        
    end
end