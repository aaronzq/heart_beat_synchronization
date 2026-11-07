function [images_resampled] = getResample(images, T_p, N_T, N_t, h_T_original)
% GETRESAMPLE Historical temporal interpolation helper; not in the core flow.
% images is [height,width,frame]. T_p and h_T_original are milliseconds.
% N_T is the number of periods; N_t is the requested output frame count.
% Returns uint16 [height,width,N_t] using the existing interpolation loop.
% A short input prints a message but does not stop execution.
% Preserved for historical callers; root reconstruction does not resample.

    L = T_p * N_T;
    h_T = L / N_t;
    
    [height, width, numOfImages] = size(images); % read statistics from images matrix
    
    timeInstances_original = 0:numOfImages-1; % initialize an array of all time indexes
    timeInstances_original = timeInstances_original .* h_T_original; % convert the array to times

    if L > timeInstances_original(numOfImages)
        disp('resampling cannot be achieved: data given is shorter than requested');
    end
    
    timeInstances = 0:N_t-1; % initialize resampled time index
    timeInstances = timeInstances .* h_T; % convert array into real time
       
    images_resampled = zeros( height, width , N_t ,'uint16'); % create matrix to store the resampled images
    
    images_resampled(:,:,1) = images(:,:,1);
    
    j = 2;
    for i = 2:N_t
        
        if timeInstances_original(j) < timeInstances(i)
            
            % find next available data
            j = j+1;
        end            
        % interpolate data using timeInstances_original(j-1) and timeInstances_original(j)

        coefficient1 = (timeInstances(i) - timeInstances_original(j-1)) / (timeInstances_original(j) - timeInstances_original(j-1));% two parameters for linear interpolation
        coefficient2 = (timeInstances_original(j) - timeInstances(i)) / (timeInstances_original(j) - timeInstances_original(j-1));

        images_resampled(:,:,i) = uint16(coefficient2 .* images(:,:,j-1) + coefficient1 .* images(:,:,j));           
    end
    
   % images_resampled = uint8(images_resampled);
    
    