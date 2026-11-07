function regulizeData_wrapper(baseDir, outputDir, T_p, t, h_T, numOfSlice, numOfPeriod, numOfImage)
% REGULIZEDATA_WRAPPER Historical crop-and-resample exporter.
% baseDir contains numbered layer folders; outputDir is the destination.
% T_p and h_T are milliseconds; t contains per-layer frame offsets.
% numOfSlice selects layers, numOfPeriod selects cycles, and numOfImage is
% the resampled output count per layer. Uses getResample and writes uint16.
% Prompts before deleting an existing outputDir. Its crop convention differs
% from STEP4_align_slices; not called by the core workflow.

    if exist(outputDir,'dir') == 7
        
        disp('output folder exist, result will be overwritten, press any key to continue, ctrl+c to abort');
        pause;
        rmdir(outputDir, 's');
    end
    
    mkdir(outputDir);
    
%% align all slice
    for i = 1:numOfSlice
        
        mkdir([outputDir '\' int2str(i)]);
        
        imageList = dir([baseDir '\' int2str(i) '\*.tif']);
        tempIMG = imread([baseDir '\' int2str(i) '\' imageList(1).name]); % read in one image
        [height, width] = size(tempIMG); % get the height and length of the images
        
        images= zeros( height , width , floor(numOfPeriod*T_p/h_T)+2 , 'uint16' );
        
        count = 1;
        for j = t(i)+floor(T_p/h_T)+1 : t(i)+floor(T_p/h_T)+2+floor(numOfPeriod*T_p/h_T)
           
            images(:,:,count) = imread([baseDir '\' int2str(i) '\' imageList(j).name]);
            count = count + 1;
            j
        end
        
        
        %% resample data         
        [images_resampled] = getResample(images, T_p , numOfPeriod , numOfImage, h_T );

        for j = 1:numOfImage

            imwrite(uint16(images_resampled(:,:,j)),[outputDir '\' int2str(i) '\' int2str(j) '.tif']);
        end        
    end




