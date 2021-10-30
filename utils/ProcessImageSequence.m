function [T_p, images_resampled] = ProcessImageSequence( path , h_T_1 , resample )

    if nargin < 3
        resample =  'noresample'; % default with no resample
    end

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
    T_p = getPeriod(); % get period from input data

%% get relative Shift
    Q = getRelativeShift();
    
% %% resample data
%     
%     if strcmp(resample, 'resample') 
%         
%         [images_resampled] = getResample(images, T_p , 1 , 5, h_T );
%     end
    