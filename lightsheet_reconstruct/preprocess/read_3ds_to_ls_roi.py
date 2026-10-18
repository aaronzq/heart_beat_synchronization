# -*- coding: utf-8 -*-
"""
read_3ds_to_ls_roi.py
=====================
Adapted from ``E:/research/utils/readwrite.py::read_3ds``.

``read_3ds`` reads *all* pages of *all* multi-page TIFFs in a folder and
concatenates them into one big ``(Total_Z, Y, X)`` array.  For a full
light-sheet scan that array is huge, and the XY ROI is only known afterwards.

This script keeps exactly the same input convention
----------------------------------------------------
  * ``inputDir`` contains one or more ``.tif`` / ``.tiff`` files;
  * file names are sorted naturally (``scan_2.tif`` before ``scan_10.tif``);
  * pages are concatenated in file order, then page order.

but changes the processing to a streaming one
---------------------------------------------
  * one page is decoded at a time;
  * the XY ROI is cropped immediately;
  * the frame is written immediately;
  * every ``numOfImage`` consecutive pages form one scanned slice.

Therefore no ``(Total_Z, Y, X)`` array is ever allocated.  Peak memory is
roughly one decoded page plus the TIFF decoder buffers.

Output layout (directly usable by ``lightsheet_reconstruct``)
-------------------------------------------------------------
::

    outputDir/
        1/
            0001.tif
            0002.tif
            ...
            0NNN.tif          <- numOfImage frames of slice 1
        2/
            0001.tif
            ...
        ...

Set ``lightsheet_reconstruct/STEP1_init.m`` to::

    lsSourcePath = outputDir;
    prepareData  = false;      % no copy needed

and the pipeline will use the exported data directly.

Important assumption
--------------------
The global page order is **slice-major / time-minor**::

    slice 1: frame 1 ... frame numOfImage
    slice 2: frame 1 ... frame numOfImage
    ...

This is the layout produced by a light-sheet acquisition that stores one
multi-page TIFF per scanned slice (one page = one time point), or by a single
multi-page TIFF whose pages are ordered slice by slice.  If your TIFFs are
ordered time-major (one multi-page TIFF per time point, pages = z), do not use
this script unchanged.
"""

from __future__ import annotations

import re
import shutil
import time
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

import numpy as np
import tifffile


# ---------------------------------------------------------------------------
# User parameters
# ---------------------------------------------------------------------------
# Input: folder containing multi-page TIFF files (same input as read_3ds).
inputDir = r"F:\4_gating"

# Output root.  It will contain the sub-folders 1,2,...,numOfSlice.
# You can point this directly to STEP1_init.m's lsSourcePath.
outputDir = r"E:\research\dataset\zebrafish-heartbeat"

numOfImage = 400       # number of images recorded for EACH slice

# XY ROI.  Default is MATLAB style: 1-based and inclusive on both ends.
#   ROIxmin = 101, ROIxmax = 700  -> columns 101..700 (600 columns)
#   ROIxmax = None                -> use the last column
# For Python/numpy style (0-based, still inclusive), set roiIndexBase = 0.
roiIndexBase = 1
ROIxmin = 1350
ROIxmax = 1350+600
ROIymin = 1
ROIymax = None

# Optional slice range.  startSlice/endSlice are 1-based.
# endSlice = None -> all complete slices (plus an incomplete last slice only
#                    when allowIncompleteLastSlice = True).
startSlice = 1
endSlice = None
renumberSlices = True  # output folders 1..N for the exported range
allowIncompleteLastSlice = False

# Output options.
overwrite = False          # True: delete an existing non-empty outputDir
compression = None         # e.g. "zlib", "lzw"; None = uncompressed
sortMode = "natural"       # "natural" or "ascii" (same meaning as read_3ds)
verbose = True
progressEvery = 500        # print progress every N written pages


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_TIFF_SUFFIXES = (".tif", ".tiff")


def _natural_key(name: str) -> List[object]:
    """Natural sort key: scan_2.tif < scan_10.tif."""
    return [int(part) if part.isdigit() else part.lower()
            for part in re.split(r"(\d+)", name)]


def _list_tiff_files(folder: Path, mode: str) -> List[Path]:
    files = [p for p in folder.iterdir()
             if p.is_file() and p.suffix.lower() in _TIFF_SUFFIXES]
    if not files:
        raise FileNotFoundError(f"No .tif/.tiff files found in: {folder}")

    if mode == "natural":
        files.sort(key=lambda p: _natural_key(p.name))
    elif mode == "ascii":
        files.sort(key=lambda p: p.name)
    else:
        raise ValueError("sortMode must be 'natural' or 'ascii'.")

    return files


def _shape_2d(shape: Sequence[int]) -> Tuple[int, int]:
    """Return (height, width), accepting (1,H,W) or (H,W,1) wrappers."""
    shape = tuple(int(v) for v in shape)
    if len(shape) == 2:
        return shape
    if len(shape) == 3 and shape[0] == 1:
        return shape[1], shape[2]
    if len(shape) == 3 and shape[-1] == 1:
        return shape[0], shape[1]
    raise ValueError(
        f"Expected a 2-D grayscale page, got page shape {shape}. "
        "RGB / multi-channel TIFFs are not supported."
    )


def _as_2d(array: np.ndarray) -> np.ndarray:
    """Drop a leading/trailing singleton axis, but keep a real 2-D image."""
    if array.ndim == 2:
        return array
    if array.ndim == 3 and array.shape[0] == 1:
        return array[0]
    if array.ndim == 3 and array.shape[-1] == 1:
        return array[..., 0]
    raise ValueError(
        f"Expected a 2-D grayscale page, got array shape {array.shape}. "
        "RGB / multi-channel TIFFs are not supported."
    )


def _resolve_roi(
    roi_min: Optional[int],
    roi_max: Optional[int],
    size: int,
    base: int,
    axis_name: str,
) -> Tuple[int, int]:
    """Convert user ROI (base-based, inclusive) to 0-based inclusive bounds."""
    lo = base if roi_min is None else int(roi_min)
    hi = (size - 1 + base) if roi_max is None else int(roi_max)

    if not (base <= lo <= hi <= size - 1 + base):
        raise ValueError(
            f"{axis_name} ROI [{lo}, {hi}] is outside the valid range "
            f"[{base}, {size - 1 + base}] (roiIndexBase={base})."
        )

    return lo - base, hi - base


# ---------------------------------------------------------------------------
# Main routine
# ---------------------------------------------------------------------------
def run(
    input_dir: str,
    output_dir: str,
    num_of_image: int,
    roi_xmin: Optional[int] = None,
    roi_xmax: Optional[int] = None,
    roi_ymin: Optional[int] = None,
    roi_ymax: Optional[int] = None,
    roi_index_base: int = 1,
    start_slice: int = 1,
    end_slice: Optional[int] = None,
    renumber_slices: bool = True,
    allow_incomplete_last_slice: bool = False,
    overwrite_output: bool = False,
    compression: Optional[str] = None,
    sort_mode: str = "natural",
    verbose: bool = True,
    progress_every: int = 500,
) -> Dict[str, object]:
    """Stream multi-page TIFFs into ``outputDir/1..N/<frame>.tif``.

    Returns a small summary dictionary (useful for tests / notebooks).
    """
    if num_of_image < 1:
        raise ValueError("numOfImage must be a positive integer.")
    if roi_index_base not in (0, 1):
        raise ValueError("roiIndexBase must be 0 or 1.")
    if progress_every < 1:
        progress_every = 500

    input_path = Path(input_dir).expanduser().resolve()
    output_path = Path(output_dir).expanduser().resolve()

    if not input_path.is_dir():
        raise FileNotFoundError(f"inputDir not found: {input_path}")

    # Never let a cleanup delete the input data or one of its parents.
    if output_path == input_path or input_path in output_path.parents:
        raise ValueError("outputDir must not be inputDir or inside inputDir.")
    if output_path in input_path.parents:
        raise ValueError("outputDir must not be a parent of inputDir.")

    files = _list_tiff_files(input_path, sort_mode)

    # ----- first pass: page counts / geometry / dtype (no pixel decoding) ---
    file_info: List[Tuple[Path, int, int]] = []   # (path, pages, start page)
    total_pages = 0
    reference_shape: Optional[Tuple[int, int]] = None
    reference_dtype: Optional[np.dtype] = None

    for file_path in files:
        with tifffile.TiffFile(file_path) as tif:
            n_pages = len(tif.pages)
            if n_pages == 0:
                if verbose:
                    print(f"  skip empty TIFF: {file_path.name}")
                continue

            page_shape = _shape_2d(tif.pages[0].shape)
            page_dtype = np.dtype(tif.pages[0].dtype)

        if reference_shape is None:
            reference_shape = page_shape
            reference_dtype = page_dtype
        elif page_shape != reference_shape:
            raise ValueError(
                f"Page size differs: {file_path.name} has "
                f"{page_shape[1]}x{page_shape[0]}, expected "
                f"{reference_shape[1]}x{reference_shape[0]}."
            )
        elif page_dtype != reference_dtype:
            raise ValueError(
                f"Page dtype differs: {file_path.name} has {page_dtype}, "
                f"expected {reference_dtype}."
            )

        file_info.append((file_path, n_pages, total_pages))
        total_pages += n_pages

    if reference_shape is None:
        raise ValueError("No readable TIFF pages found.")

    height, width = reference_shape
    if reference_dtype is None:
        raise ValueError("Could not determine the TIFF page dtype.")

    # ----- slice bookkeeping ------------------------------------------------
    full_slices, remainder = divmod(total_pages, num_of_image)
    if full_slices < 1:
        raise ValueError(
            f"Only {total_pages} pages found, fewer than numOfImage="
            f"{num_of_image}; cannot form one slice."
        )

    available_end = full_slices + (
        1 if (allow_incomplete_last_slice and remainder) else 0
    )
    end_slice_value = available_end if end_slice is None else int(end_slice)

    if start_slice < 1:
        raise ValueError("startSlice must be >= 1.")
    if end_slice_value < start_slice:
        raise ValueError(
            f"endSlice ({end_slice_value}) must be >= startSlice "
            f"({start_slice})."
        )
    if end_slice_value > available_end:
        raise ValueError(
            f"endSlice ({end_slice_value}) exceeds the available slices "
            f"({available_end}). Total pages = {total_pages}, "
            f"numOfImage = {num_of_image}, remainder = {remainder}."
        )

    # ----- ROI --------------------------------------------------------------
    x0, x1 = _resolve_roi(roi_xmin, roi_xmax, width, roi_index_base, "X")
    y0, y1 = _resolve_roi(roi_ymin, roi_ymax, height, roi_index_base, "Y")
    out_height = y1 - y0 + 1
    out_width = x1 - x0 + 1

    # ----- prepare output ---------------------------------------------------
    if output_path.exists() and not output_path.is_dir():
        raise NotADirectoryError(f"outputDir is a file: {output_path}")

    if output_path.exists():
        existing = list(output_path.iterdir())
        if existing:
            if not overwrite_output:
                raise FileExistsError(
                    f"outputDir is not empty: {output_path}\n"
                    "Set overwrite=True to delete it, or choose another "
                    "outputDir."
                )
            shutil.rmtree(output_path)

    output_path.mkdir(parents=True, exist_ok=True)

    first_page = (start_slice - 1) * num_of_image
    last_page = min(end_slice_value * num_of_image, total_pages)
    selected_pages = last_page - first_page

    if remainder and end_slice_value <= full_slices and verbose:
        print(
            f"WARNING: {remainder} trailing page(s) do not form a complete "
            f"slice and will be ignored. Set allowIncompleteLastSlice=True "
            f"to export them."
        )

    # ----- streaming export -------------------------------------------------
    frame_digits = max(4, len(str(num_of_image)))
    frame_format = f"{{:0{frame_digits}d}}.tif"

    written = 0
    current_out_slice: Optional[int] = None
    current_out_dir: Optional[Path] = None
    started = time.time()

    if verbose:
        print("Streaming multi-page TIFFs to light-sheet layout")
        print(f"  input       : {input_path}")
        print(f"  output      : {output_path}")
        print(f"  files       : {len(file_info)}")
        print(f"  total pages : {total_pages}")
        print(f"  page size   : {width} x {height} (W x H), "
              f"dtype = {reference_dtype}")
        print(f"  ROI         : x {x0 + roi_index_base}..{x1 + roi_index_base}, "
              f"y {y0 + roi_index_base}..{y1 + roi_index_base} "
              f"({out_width} x {out_height}, W x H)")
        print(f"  slices      : {start_slice}..{end_slice_value} "
              f"({selected_pages} pages, {num_of_image} frames/slice)")

    for file_path, n_pages, file_start in file_info:
        file_end = file_start + n_pages

        # Skip files completely before / after the requested range.
        if file_end <= first_page:
            continue
        if file_start >= last_page:
            break

        with tifffile.TiffFile(file_path) as tif:
            for local_index, page in enumerate(tif.pages):
                global_index = file_start + local_index

                if global_index < first_page:
                    continue
                if global_index >= last_page:
                    break

                array = _as_2d(page.asarray())

                if array.shape != (height, width):
                    raise ValueError(
                        f"Unexpected page shape in {file_path.name}, page "
                        f"{local_index + 1}: {array.shape}, expected "
                        f"{(height, width)}."
                    )
                if array.dtype != reference_dtype:
                    raise ValueError(
                        f"Unexpected page dtype in {file_path.name}, page "
                        f"{local_index + 1}: {array.dtype}, expected "
                        f"{reference_dtype}."
                    )

                cropped = array[y0:y1 + 1, x0:x1 + 1]

                slice_index = global_index // num_of_image + 1
                frame_index = global_index % num_of_image + 1

                out_slice = (slice_index - start_slice + 1
                             if renumber_slices else slice_index)

                if out_slice != current_out_slice:
                    current_out_dir = output_path / str(out_slice)
                    current_out_dir.mkdir(parents=True, exist_ok=True)
                    current_out_slice = out_slice

                    if verbose:
                        print(f"  slice {slice_index:4d} -> "
                              f"{current_out_dir}")

                if current_out_dir is None:
                    raise RuntimeError("Internal error: output folder not set.")

                out_file = current_out_dir / frame_format.format(frame_index)
                tifffile.imwrite(
                    out_file,
                    cropped,
                    photometric="minisblack",
                    compression=compression,
                )

                written += 1

                if verbose and written % progress_every == 0:
                    elapsed = max(time.time() - started, 1e-6)
                    print(f"    {written}/{selected_pages} pages "
                          f"({written / elapsed:.1f} pages/s)")

    elapsed = time.time() - started

    if written != selected_pages:
        raise RuntimeError(
            f"Exported {written} pages, expected {selected_pages}. "
            "The page count may have changed while reading."
        )

    # ----- verify the output layout ----------------------------------------
    out_indices = [
        (slice_index - start_slice + 1) if renumber_slices else slice_index
        for slice_index in range(start_slice, end_slice_value + 1)
    ]

    for offset, out_slice in enumerate(out_indices):
        actual_slice = start_slice + offset
        expected_frames = (remainder if actual_slice == full_slices + 1
                           else num_of_image)
        folder = output_path / str(out_slice)
        n_written = len(list(folder.glob("*.tif")))
        if n_written != expected_frames:
            raise RuntimeError(
                f"Slice {actual_slice} -> {folder} contains {n_written} "
                f"frames, expected {expected_frames}."
            )

    if verbose:
        print("Done.")
        print(f"  exported    : {written} pages in "
              f"{len(out_indices)} slice folder(s)")
        print(f"  output shape: {out_width} x {out_height} (W x H), "
              f"dtype = {reference_dtype}")
        print(f"  elapsed     : {elapsed:.1f} s")
        print("  STEP1_init.m: set lsSourcePath = outputDir and "
              "prepareData = false")

    return {
        "output_dir": str(output_path),
        "input_dir": str(input_path),
        "total_pages": total_pages,
        "exported_pages": written,
        "num_of_image": num_of_image,
        "slices": out_indices,
        "roi": (x0, x1, y0, y1),
        "output_shape": (out_height, out_width),  # (H, W)
        "dtype": str(reference_dtype),
        "elapsed_s": elapsed,
    }


def main() -> None:
    run(
        input_dir=inputDir,
        output_dir=outputDir,
        num_of_image=numOfImage,
        roi_xmin=ROIxmin,
        roi_xmax=ROIxmax,
        roi_ymin=ROIymin,
        roi_ymax=ROIymax,
        roi_index_base=roiIndexBase,
        start_slice=startSlice,
        end_slice=endSlice,
        renumber_slices=renumberSlices,
        allow_incomplete_last_slice=allowIncompleteLastSlice,
        overwrite_output=overwrite,
        compression=compression,
        sort_mode=sortMode,
        verbose=verbose,
        progress_every=progressEvery,
    )


if __name__ == "__main__":
    main()





