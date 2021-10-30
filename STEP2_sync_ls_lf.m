clear all;
addpath('./utils');
load('sync_para.mat');


%% user defined parameters
numOfSlice = sliceNum+1; %how many slices recorded in sequence
numOfImage = imageNum; %how many images recorded at single slice
refOfLightfield = lightfieldRef+1;  %if no light-field ref, then set this to be equal to numOfSlice

numOfSlice = 3;
numOfImage = 450;
refOfLightfield = 2;

baseDir = ['D:\Zhaoqiang\RawData'];
outputDir = [baseDir '\output'];
h_T = 5;  %exposure time (ms)
numOfPeriod = 2; %how many period you want to output
maxSliceConsidered = 2;

% edit these
systolicPoint_1st = 94;
systolicPoint_4st = 359;
%

tic;
%% compute the period of the heartbeat
periodTh1 = (systolicPoint_4st-systolicPoint_1st)/3*h_T*0.85 - 30;
periodTh2 = (systolicPoint_4st-systolicPoint_1st)/3*h_T*1.15 + 30;
t_p_candidate = zeros(1,numOfSlice);
Q = -500.*ones(numOfSlice, numOfSlice);
% distcomp.feature( 'LocalUseMpiexec', false );
parfor i = 1:numOfSlice
    t_p_candidate(i) = getPeriod_wrapper([baseDir '\' int2str(i)], h_T, periodTh1, periodTh2);
end
t_p = sum(t_p_candidate)/length(t_p_candidate);
fprintf("The period of the heartbeat has been calculated: %f ms. Time elapsed: %f s.\n", t_p, toc);
save('sync_para.mat', 'h_T', 't_p', '-append');


%% compute the phase delay of each slice
maxTermInS = (numOfSlice - maxSliceConsidered) * maxSliceConsidered;

A = zeros(maxTermInS+1, numOfSlice);
s = zeros(maxTermInS+1, 1);
W = zeros(maxTermInS+1, maxTermInS+1);
A(1,1) = 1; W(1,1) = 1; s(1) = 0;

weight = 0.8;
parfor k = 1 : maxTermInS
    
    deltaS = floor( (k-1) / (numOfSlice - maxSliceConsidered) ) + 1;
    indexS = mod( k , (numOfSlice - maxSliceConsidered) );
    if indexS == 0
        indexS = numOfSlice - maxSliceConsidered; 
    end
    temp = zeros(1, numOfSlice);
    temp(indexS) = 1; temp(indexS+deltaS) = -1;
    temp2 = zeros(1, maxTermInS+1);
    temp2(k+1) = weight * 0.1^(deltaS-1);
    A(k+1,:) = temp; 
    s(k+1,:) = getRelativeShift_wrapper( baseDir, indexS, indexS+deltaS, t_p, h_T );
    W(k+1,:) = temp2;
    
end
t = -inv(A'*W'*W*A) * A'*W'*W*s; % t is the absolute shift calculated
t(1) = 0;
t = mod(t,t_p/h_T);
t = floor(t);
t_lf = t(refOfLightfield);
timePointNum = floor(numOfPeriod*floor(t_p/h_T));
fprintf("Phase displacement completed. Time: %f s.\n", toc);
save('sync_para.mat', 't', 't_lf', 'timePointNum', '-append');



%% align and save images
fprintf("Start saving images... Time: %f s.\n", toc);
if exist(outputDir,'dir') == 7
    disp('output folder exist, result will be overwritten, press any key to continue, ctrl+c to abort');
    pause;
    rmdir(outputDir, 's');
end
mkdir(outputDir);

% align all slice bt slice
for i = 1:numOfSlice

    mkdir([outputDir '\' int2str(i)]);

    imageList = dir([baseDir '\' int2str(i) '\*.tif']);
    tempIMG = imread([baseDir '\' int2str(i) '\' imageList(1).name]); % read in one image
    [height, width] = size(tempIMG); % get the height and length of the images

    images= zeros( height , width , floor(numOfPeriod*floor(t_p/h_T))+2 , 'uint16' );

    count = 1;
    for j = t(i)+1 : t(i)+floor(numOfPeriod*floor(t_p/h_T))

        images(:,:,count) = imread([baseDir '\' int2str(i) '\' imageList(j).name]);
        count = count + 1;
    end
    
    for j = 1:floor(numOfPeriod*floor(t_p/h_T))

        imwrite(uint16(images(:,:,j)),[outputDir '\' int2str(i) '\' int2str(j) '.tif']);
    end 
end

byStateDir = [outputDir '\byState'];
if exist(byStateDir,'dir') == 7

    rmdir(byStateDir, 's');
end

mkdir(byStateDir);

% align all slice by state
for i = 1:floor(numOfPeriod*floor(t_p/h_T))

    mkdir([byStateDir '\' int2str(i)]);
    % copy image into the corresponding folder
    for j = 1:numOfSlice
        if j == refOfLightfield
            continue;
        end
        copyfile([outputDir '\' int2str(j) '\' int2str(i) '.tif'],[byStateDir '\' int2str(i) '\slice_' int2str(j) '.tif' ]);
    end
end


directory = byStateDir;
D = dir(directory);
outDir = [directory , '\..\output_each_state_in_one_tiff'];

if exist(outDir,'dir') ~= 7
    mkdir(outDir);
end

for i = 1:size(D,1)-2
    fdName = num2str(i);
    sliceName = dir(fullfile(directory,fdName));
    numSlice = size(sliceName,1);
    temp = imread(fullfile(directory,fdName,sliceName(3).name));
    out = uint16(zeros([size(temp) , numSlice-2]));
    
    cName = sliceName(3).name(1:find(sliceName(3).name=='_'));
    
    for j = 1:numSlice-2
        if j < refOfLightfield
            inputName = [cName , num2str(j) , '.tif'];
        else
            inputName = [cName , num2str(j+1) , '.tif'];
        end
        out(:,:,j) = fliplr(imread( fullfile(directory,fdName,inputName) ) );  %the light-sheet camera is mirrored to light-field camera
    end
    
    out = flip(out,3);  % the depth orientation of light-sheet is opposite to light-field 
    
    imwrite(out(:,:,1), fullfile(outDir , ['state_' , num2str(i) , '.tif']));
    for k = 2:numSlice-2
        imwrite(out(:,:,k), fullfile(outDir , ['state_' , num2str(i) , '.tif']) , 'WriteMode' , 'append');
    end 
end

fprintf('Consumed time in total: %f\n',toc);
fprintf('Light-sheet image depth: %d\n',numOfSlice-1);
fprintf('Synced index for light field: %d\n',t(refOfLightfield));