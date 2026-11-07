%% STEP6_assemble_xyzt.m
% Assemble the phase-aligned slices into xyzt data.
%
% The assembly is the light-sheet part of STEP2_sync_ls_lf.m with the LF
% reference slice removed:
%   * every time state gathers all numOfSlice light-sheet slices;
%   * fliplr / flip(z) keep the geometry convention of the original code
%     (controlled by mirrorXY / flipZ in STEP1_init.m);
%   * one multi-page TIFF per time state is written, page = z.
%
% Output:
%   outputPath\byState\<state>\slice_<slice>.tif   (if saveByState)
%   outputPath\xyzt\state_<state>.tif              (if saveVolumes)
%
% If byState already exists and only mirrorXY / flipZ changed, run
% assemble_xyzt_from_byState.m instead of STEP1 ... STEP6: it rebuilds xyzt
% from the stored byState slices without repeating the reconstruction.
%
% xyzt layout: x = columns, y = rows, z = TIFF pages, t = state index.

clear all; close all; clc;

stepDir = fileparts(mfilename('fullpath'));
if isempty(stepDir)
    stepDir = pwd;
end
load(fullfile(stepDir,'ls_recon_para.mat'));

if ~exist('t','var') || ~exist('timePointNum','var') || isempty(t)
    error('t / timePointNum not found. Run STEP4_compute_phase first.');
end
if ~exist('bySliceDir','var') || exist(bySliceDir,'dir') ~= 7
    error('bySliceDir not found. Run STEP5_align_slices first.');
end
if ~saveByState && ~saveVolumes
    error('Both saveByState and saveVolumes are false: nothing to assemble.');
end

%% Output folders
byStateDir = fullfile(outputPath,'byState');
volDir = fullfile(outputPath,'xyzt');

if saveByState
    if exist(byStateDir,'dir') == 7
        rmdir(byStateDir,'s');
    end
    mkdir(byStateDir);
end
if saveVolumes
    if exist(volDir,'dir') == 7
        rmdir(volDir,'s');
    end
    mkdir(volDir);
end

% Image size (all slices are expected to have the same size)
tempImg = imread(fullfile(bySliceDir,int2str(1),'0001.tif'));
[height, width] = size(tempImg);

%% Assemble state by state
fprintf('Assembling %d states of %d slices ...\n', timePointNum, numOfSlice);
for k = 1:timePointNum

    % Optional "byState" representation: one folder per time state
    if saveByState
        stateDir = fullfile(byStateDir,sprintf('%04d',k));
        mkdir(stateDir);
        for i = 1:numOfSlice
            copyfile( ...
                fullfile(bySliceDir,int2str(i),sprintf('%04d.tif',k)), ...
                fullfile(stateDir,sprintf('slice_%d.tif',i)));
        end
    end

    % xyzt volume: one multi-page TIFF per time state
    if saveVolumes
        vol = zeros(height,width,numOfSlice,'uint16');
        for i = 1:numOfSlice
            if saveByState
                imgFile = fullfile(byStateDir,sprintf('%04d',k), ...
                    sprintf('slice_%d.tif',i));
            else
                imgFile = fullfile(bySliceDir,int2str(i),sprintf('%04d.tif',k));
            end
            img = imread(imgFile);
            if mirrorXY
                img = fliplr(img);
            end
            vol(:,:,i) = img;
        end

        if flipZ
            vol = flip(vol,3);
        end

        outFile = fullfile(volDir,sprintf('state_%04d.tif',k));
        if exist(outFile,'file') == 2
            delete(outFile);
        end
        imwrite(vol(:,:,1), outFile);
        for z = 2:numOfSlice
            imwrite(vol(:,:,z), outFile, 'WriteMode', 'append');
        end
    end

    if mod(k,10) == 0 || k == timePointNum
        fprintf('  state %4d/%4d done\n', k, timePointNum);
    end
end

fprintf('Light-sheet xyzt reconstruction finished.\n');
fprintf('  volumes : %s (%d files, %d x %d x %d)\n', ...
    volDir, timePointNum, width, height, numOfSlice);
if saveByState
    fprintf('  byState : %s\n', byStateDir);
end
fprintf('  t axis  : state_0001 ... state_%04d\n', timePointNum);
if flipZ
    fprintf('  note    : z axis was flipped (flipZ = true).\n');
end
if mirrorXY
    fprintf('  note    : every slice was mirrored left-right (mirrorXY = true).\n');
end
