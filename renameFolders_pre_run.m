%% rename the folder
% insert the light-field reference folder in the middle of light-sheet data

sliceNum = 68;  %the total number of folders in raw light-sheet data path
lightfieldRef = 35;   % which folder of light-sheet images to insert light-field-ref images after, '27' is the folder name
                      % e.g. light-sheet folder: '1','2'...'64'  (64 folders in total)
                      %      and we insert light-field-ref images into a folder
                      %      after the light-sheet folder '27'. So
                      %      lightfieldRef = 27. And there are 27 folders
                      %      ahead 
imageNum = 450;
lssourcePath = 'F:\hsiailab\rawData\aaron_spim\cmlc_gfp_gata1_dsred_control_3dpf_20190703\data\fish1\ls\gfp';
lfsourcePath = 'F:\hsiailab\rawData\aaron_spim\cmlc_gfp_gata1_dsred_control_3dpf_20190703\data\fish1\lf\gfp1';
outputPath = 'D:\Zhaoqiang\RawData';

if exist(outputPath,'dir') == 7
    disp('output folder exist, result will be overwritten, press any key to continue, ctrl+c to abort');
    pause;
    rmdir(outputPath, 's');
    
end
mkdir(outputPath);

for i = 1:sliceNum+1
    mkdir( fullfile(outputPath,num2str(i)) );
        
    if i < lightfieldRef+1
        src = fullfile(lssourcePath,num2str(i));
    elseif i == lightfieldRef+1
        src = fullfile(lfsourcePath,'0');
    else
        src = fullfile(lssourcePath,num2str(i-1));
    end
    imageList = dir(fullfile( src,'*.tif' ));
    
    for j = 1:imageNum
        copyfile( fullfile( src,imageList(j).name ) , fullfile(outputPath,num2str(i),imageList(j).name) );
    end
    
end

fprintf('numOfSlice: %d\n',sliceNum+1);
fprintf('lightfield_ref: %d\n',lightfieldRef);
fprintf('numOfImage: %d\n',imageNum);