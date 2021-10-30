clear all;
%% rename the folder
% insert the light-field reference folder in the middle of light-sheet data

sliceNum = 83;  %the total number of folders in raw light-sheet data path
startingNum = 11; %the starting index of the raw light-sheet data folders
lightfieldRef = 47;   % which folder of light-sheet images to insert light-field-ref images after, '27' is the folder name
                      % e.g. light-sheet folder: '1','2'...'64'  (64 folders in total)
                      %      and we insert light-field-ref images into a folder
                      %      after the light-sheet folder '27'. So
                      %      lightfieldRef = 27. And there are 27 folders
                      %      ahead 
imageNum = 450;
lssourcePath = 'G:\Zhaoqiang\spim_room\plos_revision_3dpf_20210114\data\fish5\ls\gfp';
lfsourcePath = 'G:\Zhaoqiang\spim_room\plos_revision_3dpf_20210114\data\fish5\lf\gfp';
outputPath = 'D:\Zhaoqiang\RawData';



if exist(outputPath,'dir') ~= 7
    mkdir(outputPath);
end
for i = 1:sliceNum+1
    mkdir( fullfile(outputPath,num2str(i)) );
        
    if i < lightfieldRef-startingNum+2
        src = fullfile(lssourcePath,num2str(i+startingNum-1));
    elseif i == lightfieldRef-startingNum+2
        src = fullfile(lfsourcePath,'0');
    else
        src = fullfile(lssourcePath,num2str(i+startingNum-2));
    end
    imageList = dir(fullfile( src,'*.tif' ));
    
    for j = 1:imageNum
        copyfile( fullfile( src,imageList(j).name ) , fullfile(outputPath,num2str(i),imageList(j).name) );
    end
    
end

lightfieldRef = lightfieldRef-startingNum+1;
fprintf('numOfSlice: %d\n',sliceNum+1);
fprintf('lightfieldRef: %d\n',lightfieldRef);
fprintf('numOfImage: %d\n',imageNum);
save('sync_para.mat', 'sliceNum', 'lightfieldRef', 'imageNum', '-v7.3');