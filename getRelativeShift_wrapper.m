function [Q_i_j] = getRelativeShift_wrapper( baseDir, index1, index2, t_p, h_T)

    global images1;
    global images2;
        
%%  read images of slice i
    imageList = dir([baseDir '\' int2str(index1) '\*.tif']); % obtain image list    
    numOfImage1 = length(imageList); % obtain num of images    
    
    tempIMG = imread([baseDir '\' int2str(index1) '\' imageList(1).name]); % read in one image
    [height, width] = size(tempIMG); % get the height and length of the images
    
    startIndex = floor(t_p/h_T)+1;
    
    images1= zeros( height , width , numOfImage1 ); % create matrix to store all images
        
    for i = 1:numOfImage1
        
        images1(:,:,i) = imread([baseDir '\' int2str(index1) '\' imageList(i).name]); % read all images in to the matrix
    end
    
 %%  read images of slice j
    imageList = dir([baseDir '\' int2str(index2) '\*.tif']); % obtain image list    
    numOfImage2 = length(imageList); % obtain num of images    

    images2= zeros( height , width , numOfImage2 ); % create matrix to store all images
    
    for i = 1:numOfImage2
        
        images2(:,:,i) = imread([baseDir '\' int2str(index2) '\' imageList(i).name]); % read all images in to the matrix
    end
    
%%  calculate relative shift between slice i and j
    Q_i_j = getRelativeShift(startIndex);