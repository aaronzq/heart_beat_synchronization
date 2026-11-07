function imageStack = imread3d(file)
% IMREAD3D Read all pages of a grayscale TIFF in stored order.
% imageStack = imread3d(file) returns double [height,width,depth].
% file is the TIFF path; pages are expected to have matching dimensions.
% No spatial transforms, intensity normalization, or metadata are returned.

    tiffInfo = imfinfo(file);
%     assert(tiffInfo(1).BitDepth == 8, sprintf('%s is not in 8-bit\n convert this image into 8-bit in ImageJ first\n', tiffInfo(1).Filename))
    
    Width = tiffInfo(1).Width;
    Height = tiffInfo(1).Height;
    Depth = numel(tiffInfo);
    imageStack = zeros(Height, Width, Depth);  % double by default
    for i = 1:Depth
        %imageStack(:,:,i) = imread(file, 'Index', i, 'Info', tiffInfo);
        imageStack(:,:,i) = imread(file, i);
    end
    
    %imageStack = uint8(imageStack);
end

