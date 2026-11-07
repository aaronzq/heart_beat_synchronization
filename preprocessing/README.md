# Optional data preparation

These utilities are separate from the root reconstruction workflow. Skip this directory when your input already follows the [required layout](../README.md#arrange-your-input-first). Neither utility is called by `ls_reconstruct.m`.

## Copy and renumber existing depth folders

[prepare_ls_data.m](prepare_ls_data.m) copies the first `numOfImage` files in MATLAB `dir()` order from each source depth folder into destination folders `1..numOfSlice`. It does not insert a light-field reference layer or alter image pixels.

Edit the settings at the top of the script:

```matlab
rawLsPath = 'C:\example_data\raw_light_sheet';
rawFirstSlice = 11;    % source folders 11..20 in this example
lsSourcePath = 'C:\example_data\light_sheet';
numOfSlice = 10;
numOfImage = 600;
overwriteOutput = true;
```

Run this utility separately, then configure the root `STEP1_init.m` to use the resulting `lsSourcePath`. No reconstruction parameter file is needed for preparation.

Use separate, nonoverlapping source and destination trees. The preserved copying loop deletes existing destination slice folders when `overwriteOutput = true`; its equality check does not detect every possible path overlap. Source filenames must already sort chronologically.

## Export frames from multipage TIFFs

[read_3ds_to_ls_roi.py](read_3ds_to_ls_roi.py) streams TIFF pages, optionally crops a rectangular XY region, and writes numbered slice folders. Python with **NumPy** and **tifffile** is needed only for this utility. Some optional TIFF compression codecs may also require `imagecodecs`.

Edit the script's `User parameters` section, then run from the repository root:

```text
python preprocessing/read_3ds_to_ls_roi.py
```

| Setting | Meaning |
| --- | --- |
| `inputDir`, `outputDir` | Example paths to replace; input contains `.tif` or `.tiff` files |
| `numOfImage` | Consecutive pages belonging to one depth |
| `ROIxmin`, `ROIxmax`, `ROIymin`, `ROIymax` | Inclusive crop bounds; `None` means the image edge |
| `roiIndexBase` | `1` for MATLAB-style coordinates, `0` for zero-based coordinates; upper bounds remain inclusive in either case |
| `startSlice`, `endSlice` | One-based inclusive source slice range; `None` means the available end |
| `renumberSlices` | Keep `True` to export the required `1..N` folder layout |
| `allowIncompleteLastSlice` | Default `False`: discard trailing pages that do not form a complete slice |
| `overwrite` | Default `False`; enabling it permits deleting a nonempty output directory |
| `sortMode` | Default `natural`: `scan_2.tif` precedes `scan_10.tif` |
| `compression` | Default `None`; optional TIFF compression name |

**Page order must be depth first, time second:** all frames for depth 1, then all frames for depth 2, and so on. Slice boundaries may span files. Recordings stored as one z stack per time point do not match this convention.

Output frames have zero-padded names and retain the original dtype. Only a page at a time is decoded. The optional partial final slice is not suitable for the equal-length core workflow; omit it or prepare a complete dataset separately. After export, set `lsSourcePath`, `numOfSlice`, and `numOfImage` in the root initialization script.

The importable `run(...)` function returns a summary dictionary for scripts or notebooks. Its conversion behavior is unchanged; the example paths and documentation have been updated.
