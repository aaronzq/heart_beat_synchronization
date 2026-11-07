# lightsheet_reconstruct

从原始光片（LS）扫描数据重建同步后的 `xyzt` 数据，**完全不使用光场（LF）信息**：

- 不再插入 / 读取光场参考层（原 `lightfieldRef`）；
- 不再做 LF–LS 空间配准（不使用 `trans_matrix.mat`、`mytform`、`upSampleRatio`）；
- 不再输出 LF 相关结果。

本目录只负责把原始代码中的“光片部分”拆出来，**没有新增重建算法**：周期估计、层间相对位移、相位求解全部直接调用 `../utils` 下的现有函数：

| 步骤 | 调用的 utils 函数 |
| --- | --- |
| 周期估计 | `getPeriod_wrapper.m` → `getPeriod.m` → `getPeriodMatchEnergy.m` |
| 层间相对位移 | `getRelativeShift_wrapper.m` → `getRelativeShift.m` → `getRelativeShiftMatchEnergy.m` |
| 相位最小二乘 | 与 `STEP2_sync_ls_lf.m` 相同的 `A/s/W` 模型 |

## 文件说明

| 文件 | 作用 |
| --- | --- |
| `STEP1_init.m` | **所有用户参数**：文件路径、扫描层数、每层帧数、曝光时间、心动周期参数、输出开关 |
| `STEP2_prepare_ls_data.m` | 把原始 LS 各层复制为 `lsSourcePath\1..N`（不插入 LF 层） |
| `STEP3_compute_period.m` | 逐层估计心动周期 `t_p`，取平均 |
| `STEP4_compute_phase.m` | 估计每层相位 `t(i)`（单位：帧），计算 `timePointNum` |
| `STEP5_align_slices.m` | 按 `t(i)` 裁出各层的相位对齐时序 |
| `STEP6_assemble_xyzt.m` | 逐时间状态组装三维体，输出多页 TIFF（xyzt） |
| `assemble_xyzt_from_byState.m` | **只**从已有 `byState` 重新组装 `xyzt`（不重跑周期 / 相位 / 裁切；固定 `mirrorXY=false`、`flipZ=false`） |
| `ls_reconstruct.m` | 一键依次运行 STEP1–STEP6 |
| `preprocess/read_3ds_to_ls_roi.py` | 从多页 TIFF 流式读取、裁 XY ROI、按 `numOfImage` 直接写成 `1..N` 结构（可选预处理） |

## 数据要求

原始光片数据目录结构（每层一个子文件夹，文件夹名连续编号）：

```
rawLsPath\
    11\  *.tif   (每层按时间顺序记录的宽场光片图像)
    12\  *.tif
    ...
    93\  *.tif
```

`rawFirstSlice = 11`，`numOfSlice = 83` 时正好对应 11..93。

注意：

1. 帧文件名在**字典序**下必须与采集时间顺序一致（建议零填充，如 `0001.tif`、`0002.tif`）。`utils` 中的函数使用 `dir()` 的顺序读取帧。
2. `utils/getRelativeShift_wrapper.m` 内部用 `int2str(index)` 拼接路径，所以重建读取的数据根 `lsSourcePath` 必须包含名为 `1,2,...,numOfSlice` 的子文件夹。`STEP2_prepare_ls_data.m` 会自动完成这一重编号。
3. 如果 `lsSourcePath` 已经是 `1..N` 结构，可在 `STEP1_init.m` 中设 `prepareData = false`，跳过复制。

## 从多页 TIFF 流式导出 ROI（可选）

如果原始数据是“一个文件夹里放多个多页 TIFF”（与 `E:/research/utils/readwrite.py` 的 `read_3ds` 输入相同），可以先用 `preprocess/read_3ds_to_ls_roi.py` 把它转换成上面的 `1..N` 结构，并同时裁掉 XY ROI。

与 `read_3ds` 的区别：

- `read_3ds` 先把所有页读成 `(Total_Z, Y, X)` 大数组；
- 本脚本逐页读取、逐帧裁 ROI、逐帧写盘，**峰值内存约等于一张图**；
- 每 `numOfImage` 页视为一层，输出 `outputDir/1/0001.tif ... 0NNN.tif`。

参数（脚本开头）：

```python
inputDir  = r"...\gfp_3ds"    # 多页 TIFF 所在文件夹
outputDir = r"...\RawData_LS" # 输出根目录，直接作为 lsSourcePath
numOfImage = 450              # 每层帧数

roiIndexBase = 1              # 1 = MATLAB 风格（1-based，包含两端）
ROIxmin = 101
ROIxmax = 700                 # None = 到最后一列
ROIymin = 1
ROIymax = None                # None = 到最后一行
```

运行：

```powershell
python lightsheet_reconstruct\preprocess\read_3ds_to_ls_roi.py
```

然后在 `STEP1_init.m` 中设置：

```matlab
lsSourcePath = outputDir;
prepareData  = false;
```

注意：

1. 脚本假设全局页序是 **层优先、时间在后**：第 1 层 450 帧、第 2 层 450 帧……如果数据是“每个时间点一个多页 TIFF（页 = z）”，不能直接使用。
2. 文件名按自然序排序（`scan_2.tif` 在 `scan_10.tif` 前），与 `read_3ds` 一致。
3. 输出帧名零填充为 `0001.tif` 起，保证 `utils` 里 `dir()` 的顺序正确。
4. 若总页数不是 `numOfImage` 的整数倍，默认忽略末尾不足一层的页；`allowIncompleteLastSlice = True` 可保留。
5. `ROIxmin/ROIxmax` 默认 1-based 且包含两端；若想用 numpy 的 0-based，设 `roiIndexBase = 0`。
6. ROI 坐标基于原始 TIFF；下游 `STEP1_init.m` 的 `mirrorXY/flipZ` 只改变输出方向，不会改变 ROI 的位置。
7. 输出保持原始 dtype（例如 `uint16` 仍是 16-bit），不做归一化或类型转换。

## 使用方法

1. 打开 `STEP1_init.m`，修改以下参数：

```matlab
rawLsPath     = '...\data\fish5\ls\gfp';  % 原始光片根目录
rawFirstSlice = 11;                       % 第一层对应的原始文件夹编号
lsSourcePath  = 'D:\...\RawData_LS';      % 重编号后的工作目录
outputPath    = 'D:\...\LS_recon';        % 输出目录

numOfSlice = 83;   % 扫描了多少层
numOfImage = 450;  % 每层采集了多少张
h_T        = 5;    % 每张的时间间隔 / 曝光时间 (ms)

numOfPeriod        = 2;    % 输出几个心动周期
maxSliceConsidered = 2;    % 相位拟合时考虑的最大层间距
systolicPoint_1st  = 94;   % 第 1 个收缩峰所在帧
systolicPoint_4st  = 359;  % 第 4 个收缩峰所在帧
```

2. 运行：

```matlab
cd lightsheet_reconstruct
ls_reconstruct
```

或者按 `STEP1_init` → `STEP2_prepare_ls_data` → ... → `STEP6_assemble_xyzt` 逐步运行。

## 输出结构

```
outputPath\
    bySlice\
        1\ 0001.tif 0002.tif ...  （第 1 层对齐后的时序）
        2\ ...
        ...
    byState\                    （saveByState = true 时）
        0001\ slice_1.tif slice_2.tif ...
        0002\ ...
        ...
    xyzt\                       （saveVolumes = true 时）
        state_0001.tif          （多页 TIFF，一页 = 一个 z 层）
        state_0002.tif
        ...
```

- `xyzt` 的维度含义：`x` = 图像列，`y` = 图像行，`z` = TIFF 页号，`t` = `state_XXXX` 编号。
- `timePointNum = floor(numOfPeriod * floor(t_p / h_T))`，即输出的时间状态数。
- 可用 `utils/imread3d.m` 读取单个状态：

```matlab
addpath('../utils');
vol = imread3d(fullfile(outputPath,'xyzt','state_0001.tif'));
```

## 仅重新生成 xyzt（不重跑重建）

如果 `byState` 已经存在，只是想改变输出方向（`mirrorXY` / `flipZ`），**不需要重跑 STEP1–STEP6**（周期估计、相位求解、逐层裁切都很耗时）。直接运行：

```matlab
cd lightsheet_reconstruct
assemble_xyzt_from_byState
```

或者命令行：

```powershell
matlab -batch "cd('E:\论文\事件-斜光片\heart_beat_synchronization-master\lightsheet_reconstruct'); assemble_xyzt_from_byState"
```

行为：

1. 只**读** `outputPath\byState\<state>\slice_<i>.tif`，**只写** `outputPath\xyzt\state_XXXX.tif`；`byState`、`bySlice` 以及原始数据都不会被修改。
2. 固定 `mirrorXY = false`、`flipZ = false`：按 `slice_1 … slice_N` 的顺序原样写入页，得到光片自身的原始方向，即对每个状态
   `state_XXXX.tif` 第 `k` 页 == `byState\XXXX\slice_k.tif`（逐像素相等）。
   旧流程（`mirrorXY = true` + `flipZ = true`）的输出满足第 `k` 页 == `fliplr(slice_{N+1-k})`。
3. 状态数与层数自动从 `byState` 推断（`numOfSlice` 留空即可），路径默认取自 `ls_recon_para.mat` 的 `outputPath`。
4. 每个体先写到 `tmp_state_XXXX.tif`，成功后再改名，因此中途中断不会留下残缺的 `state_XXXX.tif`；旧的多余 `state_*.tif` 会被清掉。
5. 默认会读回第一个状态逐页与 `byState` 比较，若不相等（即方向出错）会直接报错。

脚本开头的可调参数：

```matlab
reconRoot   = '';    % 空 = 使用 ls_recon_para.mat 中的 outputPath
byStatePath = '';    % 空 = <reconRoot>\byState
volPath     = '';    % 空 = <reconRoot>\xyzt
overwriteVolumes = true;
numOfSlice       = [];   % 空 = 从 byState 自动推断
verifyFirstState = true;
```

### 关于方向和相位

- `mirrorXY` / `flipZ` 沿用原 `STEP2_sync_ls_lf.m` 中的几何约定（原本用于和光场对齐）。当前流程统一使用 `false / false`（光片自身的原始方向）；若需要与旧的光场–光片融合流程一致，才设为 `true`。
- `mirrorXY` / `flipZ` 只影响 `xyzt` 的体组装，不影响 `bySlice` / `byState`。因此改这两个开关后，用 `assemble_xyzt_from_byState.m` 重新组装即可，不必重跑重建。
- 相位求解中 `t(1) = 0`，即第 1 层定义相位零点。体数据内部的 z 层相位关系是正确的，但绝对心动相位是任意的（原算法如此）。

## 与原始流程的对应关系

| 原始文件 | 本目录 |
| --- | --- |
| `STEP1_rename_folders_pre_run.m`（插入 LF 参考层） | `STEP2_prepare_ls_data.m`（只复制 LS，不插入 LF） |
| `STEP2_sync_ls_lf.m` 的周期估计 | `STEP3_compute_period.m` |
| `STEP2_sync_ls_lf.m` 的相位估计 | `STEP4_compute_phase.m` |
| `STEP2_sync_ls_lf.m` 的逐层裁切 | `STEP5_align_slices.m` |
| `STEP2_sync_ls_lf.m` 的 `byState` + 体组装 | `STEP6_assemble_xyzt.m` |
| `STEP3_apply_registration.m`（LF 配准） | 已移除 |

## 内存提示

`utils/getPeriod_wrapper.m` 和 `getRelativeShift_wrapper.m` 会把整层序列读成 `double` 三维数组。`useParallel = true` 时每个 worker 都会占用一份完整数据，内存需求成倍增加；若内存不足，请保持 `useParallel = false`（默认）。
