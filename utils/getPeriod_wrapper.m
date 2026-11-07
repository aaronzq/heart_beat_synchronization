function [T_p, images_resampled] = getPeriod_wrapper(path, h_T_1, th1, th2)
% GETPERIOD_WRAPPER Estimate the period of one on-disk layer recording.
% T_p = getPeriod_wrapper(path, h_T_1, th1, th2) returns milliseconds.
% path contains chronologically ordered, matching grayscale .tif frames.
% h_T_1 is the frame interval in ms; th1/th2 bound the period search in ms.
% All TIFFs are loaded as double [height,width,frame] into globals images
% and h_T. Calls getPeriod. Paths retain Windows separators.
% Request only T_p: the historical images_resampled output is unassigned.

    imageList = dir([path '\*.tif']); % obtain image list    
    numOfImage = length(imageList); % obtain num of images    
    
    tempIMG = imread([path '\' imageList(1).name]); % read in one image
    [height, width] = size(tempIMG); % get the height and length of the images
       
    global h_T; % since use matlab nonlinear optimization function, so has to use global variable
    global images;
        
    h_T = h_T_1;
    images= zeros( height , width , numOfImage ); % create matrix to store all images
    
    for i = 1:numOfImage        
        images(:,:,i) = imread([path '\' imageList(i).name]); % read all images in to the matrix
    end

%% get period
    T_p = getPeriod(th1,th2); % get period from input data
    
    

    