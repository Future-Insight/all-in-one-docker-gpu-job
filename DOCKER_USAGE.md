# Docker镜像构建和运行指南

## 项目概述

All-In-One 音乐结构分析工具，基于深度学习分析音频的：
- 节拍 (Beats)
- 节奏 (Tempo/BPM)
- 下拍 (Downbeats)
- 功能分段 (Segments: intro, verse, chorus, bridge, outro等)

---

## 本地Docker使用

### 1. 构建镜像

**本地GPU版本（推荐）：**
```bash
docker build -f Dockerfile.local.gpu -t allinone-local-gpu .
```

**GCP兼容版本：**
```bash
docker build -f Dockerfile.gcp.gpu -t allinone .
```

**镜像技术栈：**
- 基础镜像: `pytorch/pytorch:2.5.0-cuda12.1-cudnn9-runtime`
- PyTorch 2.5.0 + CUDA 12.1 + cuDNN9
- NATTEN 0.17.5 (neighborhood attention库)
- Madmom (音频处理库)
- 预下载8个Harmonix训练模型
- 本地版本不包含GCP依赖，镜像更小

### 2. 准备目录结构

```bash
mkdir -p audio results tracks

# 将待处理的音频文件放入audio目录
cp your_song.wav audio/
```

### 3. 运行容器

```bash
docker run -it \
  -v $PWD/audio:/app/input \
  -v $PWD/results:/app/output \
  -v $PWD/tracks:/app/tracks \
  allinone \
  --out-dir /app/output/analysis \
  --viz-dir /app/output/visualizations \
  --sonif-dir /app/output/sonifications \
  --demix-dir /app/tracks \
  --spec-dir /app/output/spectrograms \
  --keep-byproducts \
  /app/input/your_song.wav
```

**挂载目录说明：**
- `-v $PWD/audio:/app/input` - 输入音频文件目录
- `-v $PWD/results:/app/output` - 输出结果目录
- `-v $PWD/tracks:/app/tracks` - 音轨分离结果目录

**参数说明：**
- `--out-dir` - JSON分析结果保存路径
- `--viz-dir` - PDF可视化图表保存路径
- `--sonif-dir` - 带节拍标记的音频文件保存路径
- `--demix-dir` - 音轨分离结果保存路径（bass, drums, other, vocals）
- `--spec-dir` - 频谱图保存路径
- `--keep-byproducts` - 保留中间文件（不加此参数会自动删除demix和spec）

### 4. 输出结果

运行后在 `results/` 目录生成：

```
results/
├── analysis/
│   └── your_song.json           # JSON格式的分析结果
├── visualizations/
│   └── your_song.pdf             # 可视化图表
├── sonifications/
│   └── your_song.sonif.wav       # 带节拍点击音的音频
└── spectrograms/
    └── your_song.*.npy           # 频谱数据

tracks/
└── htdemucs/
    └── your_song/
        ├── bass.wav
        ├── drums.wav
        ├── other.wav
        └── vocals.wav
```

**JSON结果示例：**
```json
{
  "path": "/app/input/your_song.wav",
  "bpm": 120,
  "beats": [0.33, 0.83, 1.33, ...],
  "downbeats": [0.33, 2.33, 4.33, ...],
  "beat_positions": [1, 2, 3, 4, 1, 2, 3, 4, ...],
  "segments": [
    {"start": 0.0, "end": 0.33, "label": "start"},
    {"start": 0.33, "end": 15.5, "label": "intro"},
    {"start": 15.5, "end": 45.2, "label": "verse"},
    {"start": 45.2, "end": 75.8, "label": "chorus"}
  ]
}
```

### 5. 简化运行脚本

**本地GPU版本（推荐）：**
参考 [run_local_gpu.sh](run_local_gpu.sh) 使用：

```bash
# 构建镜像
docker build -f Dockerfile.local.gpu -t allinone-local-gpu .

# 运行单个文件
./run_local_gpu.sh your_song.wav
```

**GCP兼容版本：**
参考 [run_docker_cmd_example.sh](run_docker_cmd_example.sh) 使用：

```bash
# 运行单个文件
./run_docker_cmd_example.sh your_song.wav
```

---

## Web API 使用（HTTP上传分析）

### 1. 直接复用现有 GPU 镜像（推荐）

API 已集成进 `Dockerfile.local.gpu` / `Dockerfile.gcp.gpu` 构建的镜像中，无需单独镜像。

构建本地 GPU 镜像：
```bash
docker build -f Dockerfile.local.gpu -t allinone-local-gpu .
```

启动 API：
```bash
docker run --gpus all \
  -p 8000:8000 \
  -e API_KEYS="secret-key-1,secret-key-2" \
  allinone-local-gpu api
```

也可以使用脚本一键启动：
```bash
API_KEYS="secret-key-1,secret-key-2" ./run_local_api.sh
```

### 2. 调用示例

健康检查：
```bash
curl http://localhost:8000/health
```

分析上传（multipart/form-data）：
```bash
curl -X POST http://localhost:8000/analyze \
  -H "X-API-Key: secret-key-1" \
  -F "file=@test.mp3" \
  -F "model=harmonix-all"
```

模型列表：
```bash
curl http://localhost:8000/models
```

### 3. API 文档

启动后访问：
- Swagger UI: `http://localhost:8000/docs`
- OpenAPI JSON: `http://localhost:8000/openapi.json`

---

## GCP云端部署

### 1. 初始化GCP环境

```bash
gcloud init
gcloud auth configure-docker
gcloud services enable run.googleapis.com cloudbuild.googleapis.com
```

### 2. 构建并推送镜像到GCR

```bash
# 构建GPU版本镜像
gcloud builds submit \
  --config=cloudbuild_gpu.yaml \
  --project {YOUR_PROJECT_ID} \
  --substitutions=_MY_TAG=gpu

# 查看已构建的镜像
gcloud container images list --repository=gcr.io/{YOUR_PROJECT_ID}
```

构建配置见 [cloudbuild_gpu.yaml](cloudbuild_gpu.yaml)，使用层缓存加速构建。

### 3. 配置GCP Job环境变量

在Cloud Run Job配置中设置：

| 环境变量 | 说明 | 默认值 |
|---------|------|--------|
| `BUCKET_NAME` | GCS存储桶名称 | 必填 |
| `INPUT_PATH` | 输入音频路径 | `input/` |
| `OUTPUT_PATH` | 输出结果路径 | `output-allinone/` |

### 4. 执行GPU Job

```bash
gcloud beta run jobs execute allinone-gpu-job --region=us-east4
```

**Job资源配置：**
- 内存: 16GB+
- CPU: 4核
- GPU: NVIDIA L4 或 T4
- 超时: 10分钟
- 重试: 1次

### 5. GPU配额申请

GCP Cloud Run GPU需要申请配额：
- 访问: https://g.co/cloudrun/gpu-quota
- 建议选择单区域部署降低成本

### 6. 下载处理结果

```bash
# 下载整个输出目录
gsutil -m cp -r gs://{BUCKET_NAME}/output-allinone/ ./results/

# 下载特定文件
gsutil cp gs://{BUCKET_NAME}/output-allinone/analysis/*.json ./
```

---

## 系统要求

### 硬件要求
- **GPU**: NVIDIA GPU with CUDA 12.1+ support
- **内存**: 最低 16GB RAM
- **CPU**: 4核以上
- **存储**: 20GB+（包含模型文件）

### 软件依赖
- Docker 20.10+
- NVIDIA Docker runtime（GPU支持）
- CUDA 12.1+
- cuDNN 9+

### 检查GPU支持

```bash
# 检查NVIDIA驱动
nvidia-smi

# 测试Docker GPU支持
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

---

## 注意事项

1. **Dockerfile版本选择**:
   - `Dockerfile.local.gpu`: 本地GPU运行，不含GCP依赖，镜像更小
   - `Dockerfile.gcp.gpu`: GCP兼容版本，包含google-cloud-storage，用于GCS访问
   - `Dockerfile.gcp.cpu`: CPU版本，仅用于测试（不推荐生产使用）
2. **模型预下载**: Dockerfile已预下载8个模型文件到镜像中，避免运行时下载延迟
3. **MP3格式**: 建议先用FFmpeg转为WAV格式，避免解码器差异导致的时间偏移
4. **Demucs模型**: 首次运行会下载Demucs音轨分离模型（约350MB）
5. **中间文件**: 不加`--keep-byproducts`会自动清理demix和spec文件节省空间
6. **GCP版本**: 目前仅GPU版本Dockerfile在GCP Job上稳定运行，CPU版本尚不可用

---

## 故障排查

### 问题1: CUDA版本不匹配

```bash
# 检查CUDA版本
nvidia-smi  # 查看驱动支持的CUDA版本

# 如需其他CUDA版本，修改Dockerfile.gcp.gpu基础镜像
# 并安装对应版本的NATTEN
```

### 问题2: 内存不足

```bash
# 减少并发处理或增加系统内存
# 修改process_audio.py中的batch size
```

### 问题3: 权限问题

```bash
# 确保挂载目录有读写权限
chmod -R 755 audio results tracks
```

---

## 参考文档

- [README.md](README.md) - 项目主文档
- [README_GCP_JOB.md](README_GCP_JOB.md) - GCP部署详细说明
- [TRAINING.md](TRAINING.md) - 模型训练指南
- [GITHUB_ACTIONS.md](GITHUB_ACTIONS.md) - GitHub Actions自动构建说明
- [run_local_gpu.sh](run_local_gpu.sh) - 本地GPU运行脚本
- [run_docker_cmd_example.sh](run_docker_cmd_example.sh) - GCP兼容运行脚本

---

## GitHub Actions 自动构建

本项目配置了GitHub Actions自动构建Docker镜像并推送到GitHub Container Registry。

### 可用镜像

- `ghcr.io/<用户名>/<仓库名>/allinone-local:latest` - 本地GPU版本（推荐）
- `ghcr.io/<用户名>/<仓库名>/allinone:latest` - GCP兼容版本

### 直接使用预构建镜像

无需本地构建，直接拉取使用：

```bash
# 拉取本地GPU版本
docker pull ghcr.io/<用户名>/<仓库名>/allinone-local:latest

# 运行
docker run --gpus all \
  -v $PWD/audio:/app/input \
  -v $PWD/results:/app/output \
  ghcr.io/<用户名>/<仓库名>/allinone-local:latest \
  --out-dir /app/output /app/input/your_audio.wav
```

详细说明请查看 [GITHUB_ACTIONS.md](GITHUB_ACTIONS.md)
