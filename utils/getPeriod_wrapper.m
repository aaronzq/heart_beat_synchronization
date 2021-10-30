function [T_p, images_resampled] = getPeriod_wrapper(path, h_T_1, th1, th2)

%%  read images
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
    
    

    