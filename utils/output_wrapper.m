function output_wrapper(outputDir, numOfSlice, numOfImage);
    
    byStateDir = [outputDir '\byState'];
    if exist(byStateDir,'dir') == 7
        
        rmdir(byStateDir, 's');
    end
    
    mkdir(byStateDir);
        
%% align all slice
    for i = 1:numOfImage
        
        mkdir([byStateDir '\' int2str(i)]);
        % copy image into the corresponding folder
        for j = 1:numOfSlice
        
            copyfile([outputDir '\' int2str(j) '\' int2str(i) '.tif'],[byStateDir '\' int2str(i) '\slice_' int2str(j) '.tif' ]);
        end
    end