tic;
baseDir = ['D:\Zhaoqiang\RawData'];
outputDir = [baseDir '\output'];

h_T = 5;  %exposure time (ms)
numOfSlice = 69; %how many slices recorded in sequence
numOfImage = 450; %how many images recorded at single slice
systolicPoint_1st = 80;
systolicPoint_4st = 329;

lightfield_ref = 35;

numOfPeriod = 2; %how many period you want to output


periodTh1 = (systolicPoint_4st-systolicPoint_1st)/3*h_T*0.85 - 30;
periodTh2 = (systolicPoint_4st-systolicPoint_1st)/3*h_T*1.15 + 30;


lightfield_ref = lightfield_ref+1;
t_p_candidate = zeros(1,numOfSlice);
Q = -500.*ones(numOfSlice, numOfSlice);
% distcomp.feature( 'LocalUseMpiexec', false );
%% get period
parfor i = 1:numOfSlice

    t_p_candidate(i) = getPeriod_wrapper([baseDir '\' int2str(i)], h_T, periodTh1, periodTh2);
 
end
t_p = sum(t_p_candidate)/length(t_p_candidate);

%% get relative shift
for i = 1:numOfSlice
    parfor j = 1:numOfSlice
        
        if i == j % diagonals are 0
            Q(i,j) = 0            
        elseif Q(i,j) == -500 % anti-symmetric matrix
            Q(i,j) = getRelativeShift_wrapper( baseDir, i, j, t_p, h_T );
        end
    end
    for j = 1:numOfSlice
        Q(j,i) = -Q(i,j);
    end
    fprintf('%d is complete\n',i);
end
toc
%% get absolute shift
maxSliceConsidered=2;
maxTermInS = (numOfSlice)*(numOfSlice-1)/2 - (numOfSlice-maxSliceConsidered)*(numOfSlice-maxSliceConsidered-1)/2;

A = zeros(maxTermInS, numOfSlice);
s = zeros(maxTermInS,1);
A(1,1) = 1;
W = zeros(maxTermInS,maxTermInS);
W(1,1) = 1;

k = 2;
weight = 0.8;
for i = 1:maxSliceConsidered
    
   for j = 1:numOfSlice
       
      if( j+i > numOfSlice )
          continue;
      end
      s(k) = Q(j,j+i); 
      A(k,j) = 1;
      A(k,j+i) = -1;
      W(k,k) = weight;
      k = k+1;
   end
   weight = weight * 0.8;
   if i==maxSliceConsidered-1
       weight = 0;
   end
end

t = -inv(A'*W'*W*A) * A'*W'*W*s; % t is the absolute shift calculated
t(1) = 0;

t = mod(t,t_p/h_T);

t = floor(t);

if exist(outputDir,'dir') == 7
    disp('output folder exist, result will be overwritten, press any key to continue, ctrl+c to abort');
    pause;
    rmdir(outputDir, 's');
end
mkdir(outputDir);

%% align all slice bt slice
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

%% align all slice by state
for i = 1:floor(numOfPeriod*floor(t_p/h_T))

    mkdir([byStateDir '\' int2str(i)]);
    % copy image into the corresponding folder
    for j = 1:numOfSlice
        if j == lightfield_ref
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
        if j < lightfield_ref
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
fprintf('Synced index for light field: %d\n',t(lightfield_ref));

% 
