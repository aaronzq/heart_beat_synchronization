# MATLAB helper reference

These helpers retain their existing implementations. The root workflow uses the period and shift functions below; its phase fit and image assembly remain in the STEP scripts. Array dimensions are MATLAB order: `[height, width, frame]`, not `[x, y, t]`.

## Functions used by the core workflow

```text
STEP2_compute_period
  getPeriod_wrapper → getPeriod → getPeriodMatchEnergy

STEP3_compute_phase
  getRelativeShift_wrapper → getRelativeShift → getRelativeShiftMatchEnergy

Reading saved volumes (optional)
  imread3d
```

| Function | Inputs | Output and side effects |
| --- | --- | --- |
| `getPeriod_wrapper(path, h_T_1, th1, th2)` | One layer folder, frame interval in ms, lower/upper period bounds in ms | Period in ms; loads **all** `.tif` frames as doubles into globals `images`, `h_T` |
| `getPeriod(th1, th2)` | Search bounds in ms; requires the globals set above | Period minimizing `getPeriodMatchEnergy`, using `fminbnd` |
| `getPeriodMatchEnergy(T_p)` | Candidate period in ms; globals `images`, `h_T` | Scalar image-dispersion objective after sorting frames by folded phase |
| `getRelativeShift_wrapper(baseDir, index1, index2, t_p, h_T)` | Numbered layer roots, layer indices, period and frame interval in ms | Signed integer frame shift; loads globals `images1`, `images2` |
| `getRelativeShift(startIndex_1)` | Comparison start frame `floor(t_p/h_T)+1`; globals `images1`, `images2` | Minimum-cost integer shift; sets global `startIndex` |
| `getRelativeShiftMatchEnergy(s)` | Signed integer shift; globals `images1`, `images2`, `startIndex` | Sum of squared pixel differences over the comparison window |
| `imread3d(file)` | Multipage TIFF filename | Double array `[height, width, depth]`, in TIFF page order |

The wrapper paths use Windows separators. Input frames must have matching dimensions and sort chronologically under `dir()`. The loaders do not enforce these conventions or limit their reads to the root script's `numOfImage` value. `getPeriod_wrapper` retains an unused second output, `images_resampled`, which is never assigned; request only the first output.

Positive pair shift `s` matches frame `j` in the first sequence to frame `j+s` in the second. The candidate range is `-floor((B-1)/2):floor(B/2)` for `B = startIndex`; equal costs retain the first candidate encountered. The energy window is `B:3*B-1`. Terms beyond the end of the second sequence are skipped, with no comparison-count normalization. See the root README for recording-length guidance.

Global arrays connect the historical optimizer functions. They remain allocated in the MATLAB process and are replaced by subsequent calls. Do not assume the functions are independent of previously initialized globals when calling them directly.

## Historical utilities outside the core workflow

| File | Purpose and status |
| --- | --- |
| `findPeriod.m` | Interactive one-layer period estimate with editable example folder, interval, and search bounds; add `utils` to the MATLAB path first |
| `ProcessImageSequence.m` | Incomplete historical entry point: calls `getPeriod` and `getRelativeShift` without their required arguments, and does not assign its advertised resampled output. Use the root runner instead |
| `getResample.m` | Historical linear interpolation into `N_t` samples over `N_T` periods; returns `uint16`. Not called by the core, which retains acquired frames |
| `regulizeData_wrapper.m` | Historical crop-and-resample exporter using `getResample`; preserves its original spelling and frame-selection convention. Can delete its output directory after a prompt |
| `output_wrapper.m` | Historical rearrangement from unpadded slice/frame filenames into `byState`; replaces an existing `byState` directory |

These utilities remain for compatibility and provenance. Their output naming and sampling conventions differ from the root workflow; they are not interchangeable replacements for its STEP scripts. Documentation changes do not repair or change their historical behavior.
