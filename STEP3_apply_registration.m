%% Apply transformation to light-field recon images
%  This is a script to apply spatial and temporal registration to the light
%  field reconstrcuted images to co-locate with light-sheet images
clear all;
addpath('./utils');
load('sync_para.mat');
load('trans_matrix.mat');

%% Files io
lfLoadPath = 'E:\Zhaoqiang\processedData\plos_revision_5dpf_20210104\fish2\blood';
outPath = [lfLoadPath '\registered'];

%% Data parameters
%light-sheet image resolution
lsSizeCol = 768;
lsSizeRow = 768;
%light-field image resolution
lfSliceNum = 77;
%% Parameter 1: z registration 
%  z displacements include: <1> displacement from translation stages
%                           <2> displacement between native focal plane of
%                           light-field and wide-field
lightfieldRef; % Scan through the light sheet data, find the slice position 
                     % that resembers the timestamps
z_adjustment = 5; % Displacement between native focal plane of light-field camera
                  % and wide-field 
                  % Instruction: Use the resolution target, focus on it using 
                  % wide-field; Then take one light-field shot and reconstruct. 
                  % Next find where the target is foucsed in reconstruction.
                  % Calculate how far it is ahead of focal plane
%% Parameter 2: xy registration
%  Due to the anisotropic spatial resolution of lfd, here we separate the
%  xy registration (fine) from z registration (coarse)
%  Run registerXY.m to generate trans_matrix.mat from rigid registration
%  based on selected points
mytform;
%% Parameter 3: t registration
% Temporal gating, these parameters will be output by ls_lf_sync.m
timePointNum;
t_lf;

%% Apply transformation
if exist(outPath) ~= 7
    mkdir(outPath);
end
lfMidSliceNum = sliceNum - lightfieldRef + 1;
zfillingStartPoint = lfMidSliceNum - (lfSliceNum-1)/2 + z_adjustment;
zfillingEndPoint = zfillingStartPoint + lfSliceNum - 1;
% assert((zfillingStartPoint>=1 && zfillingEndPoint<=sliceNum),'ls doesnt have enough space to hold lf');
tfillingStartPoint = t_lf + 1;

%% Apply registrations
lfImageList = dir(fullfile(lfLoadPath,'*.tif'));
for i = tfillingStartPoint:tfillingStartPoint+timePointNum-1
    outVol = zeros([lsSizeRow,lsSizeCol,zfillingEndPoint]);
    wfFixed = imref2d([lsSizeRow,lsSizeCol]);
    lfStk = imread3d(fullfile( lfLoadPath,lfImageList(i).name ));
    for d = 1:lfSliceNum
        temp = uint16(imresize(lfStk(:,:,d), upSampleRatio, 'bicubic'));
        temp = imwarp(temp,mytform,'FillValues', 0,'OutputView',wfFixed,'interp','cubic');
        outVol(:,:,zfillingStartPoint+d-1) = temp;
    end
    outVol = uint16(outVol);
    imwrite(outVol(:,:,1), fullfile(outPath , ['RBC_' , num2str(i-tfillingStartPoint+1) , '.tif']));
    for k = 2:zfillingEndPoint
        imwrite(outVol(:,:,k), fullfile(outPath , ['RBC_' , num2str(i-tfillingStartPoint+1) , '.tif']) , 'WriteMode' , 'append');
    end 
    
end
