lightfield_ref = 41;

directory = uigetdir('D:\Zhaoqiang\');
D = dir(directory);
outDir = [directory , '\..\output_each_state_in_one_tiff'];

if exist(outDir) ~= 7
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