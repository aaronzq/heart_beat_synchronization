function output_wrapper(outputDir, numOfSlice, numOfImage);
% OUTPUT_WRAPPER Historical conversion from per-slice to per-state folders.
% Inputs: outputDir root, numOfSlice depths, numOfImage frames per depth.
% Expects outputDir/<slice>/<frame>.tif with unpadded integer filenames.
% Copies to outputDir/byState/<frame>/slice_<slice>.tif.
% Deletes an existing byState directory. No return value.
% Not used by the root workflow, which has different frame naming.

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