% Historical interactive XY calibration using corresponding image points.
% Edit example images and calibration settings; run from PLOSCompBio/.
% Requires Image Processing Toolbox and interactive point selection.
% Writes mytform and upSampleRatio to trans_matrix.mat.

clear all;

%% user defined parameters
filePath = 'C:\example_data\registration'; %folder path
lf = 'example_light_field_slice.tif'; % light-field recon single slice
wf = 'example_wide_field_image.tif'; %wide field single image
upSampleRatio = 23.69/11; %compensate for the downsampling during light-field recon
lf_lt = 1000;
lf_ht = 5000;
%%
lfImg = imread(fullfile(filePath,lf));
figure(1);
imshow( lfImg, [0.75 * min(lfImg(:)) , 1.25 * max(lfImg(:))] );
% figure(2);
% [counts,x] = imhist(lfImg,256);
% stem(x,counts)
lfImgBlur = imgaussfilt(lfImg, 2);
% figure(3);
% imshow( lfImgBlur, [0.75 * min(lfImgBlur(:)) , 1.25 * max(lfImgBlur(:))]);
lfImgBlur = imresize(lfImgBlur, upSampleRatio, 'bicubic');
lfImgBin = (lfImgBlur>lf_lt) & (lfImgBlur<lf_ht);
figure(4);
imshow( lfImgBin, [0,1]);

wfImg = fliplr(imread(fullfile(filePath,wf)));
figure(5)
imshow(wfImg,[0.75 * min(wfImg(:)) , 1.25 * max(wfImg(:))])
[countsWF,wfHist] = imhist(wfImg,256);
wfImgBinT = otsuthresh(countsWF);
wfImgBin = imbinarize(wfImg,wfImgBinT);
wfImgBin = mod(wfImgBin+1,2); 
figure(6)
imshow(wfImgBin, [0,1])

[movingPoints,fixedPoints]  = cpselect(lfImgBin,wfImgBin,'Wait',true);
mytform = fitgeotrans(movingPoints, fixedPoints, 'nonreflectivesimilarity');

wfFixed = imref2d(size(wfImgBin));
lf_registered = imwarp(lfImgBin,mytform,'FillValues', 0,'OutputView',wfFixed);
close all;
figure(7), imshowpair(wfImgBin,lf_registered,'blend');

save('trans_matrix.mat','mytform', 'upSampleRatio');

