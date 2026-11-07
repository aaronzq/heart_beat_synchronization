function [energy] = getPeriodMatchEnergy(T_p)
% GETPERIODMATCHENERGY Score a candidate heartbeat period in milliseconds.
% Reads globals images [height,width,frame] and h_T (frame interval in ms).
% Folds acquisition times modulo T_p, sorts the frames by folded phase,
% and sums neighboring image differences including the normalized time term.
% Returns a scalar objective for getPeriod; there is no last-to-first term.

    global images;
    global h_T;
    
    [height, width, numOfImages] = size(images);
    
    timeInstances = 0:numOfImages-1; % initialize an array of all time indexes
    timeInstances = timeInstances .* h_T; % convert frame indices to milliseconds
    timeInstances = mod(timeInstances, T_p); % phase lock w.r. to different candidate period
 
    energy = 0;
    timeDiff = 0;
    buffer = zeros(height,width); % per-pixel squared image differences
    
    [timeInstances_sort, index] = sort(timeInstances , 'ascend'); % sort time instances into ascending order
    
    for i = 1:numOfImages-1
       
        buffer = images(:,:,index(i+1)) - images(:,:,index(i));
        buffer = buffer.^2;
        
        timeDiff = timeInstances_sort(i+1) - timeInstances_sort(i);
        timeDiff = timeDiff^2 / T_p^2; % normalized squared difference in folded time
        
        buffer = buffer + timeDiff;
        energy = energy + sqrt(sum(sum(buffer))); % original dispersion objective
    end

