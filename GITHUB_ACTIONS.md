# GitHub Actions 工作流说明

本项目包含三个GitHub Actions工作流，用于构建和推送不同版本的Docker镜像。

## 工作流概览

| Workflow文件 | 镜像名称 | Dockerfile | 用途 | 触发方式 |
|-------------|---------|-----------|------|---------|
| [docker-local-gpu.yml](.github/workflows/docker-local-gpu.yml) | `allinone-local` | `Dockerfile.local.gpu` | 本地GPU运行（推荐） | 手动 + 自动 |
| [docker-audio-analysis-gpu.yml](.github/workflows/docker-audio-analysis-gpu.yml) | `allinone` | `Dockerfile.gcp.gpu` | GCP兼容版本 | 手动 + 自动 |
| [docker-audio-analysis.yml](.github/workflows/docker-audio-analysis.yml) | `allinone` | `Dockerfile.gcp.gpu` | CPU版本（测试） | 仅手动 |

## 镜像版本对比

### 1. allinone-local (本地GPU版本) - 推荐

**特点：**
- ✅ 不含GCP依赖，镜像更小
- ✅ 包含FFmpeg支持
- ✅ 使用allin1作为入口点
- ✅ 适合本地GPU环境

**拉取：**
```bash
docker pull ghcr.io/<你的用户名>/<仓库名>/allinone-local:latest
```

**运行：**
```bash
docker run --gpus all \
  -v $PWD/audio:/app/input \
  -v $PWD/results:/app/output \
  ghcr.io/<你的用户名>/<仓库名>/allinone-local:latest \
  --out-dir /app/output /app/input/your_audio.wav
```

### 2. allinone (GCP版本)

**特点：**
- 包含google-cloud-storage依赖
- 支持GCS存储桶访问
- 兼容GCP Cloud Run Jobs
- 镜像稍大

**拉取：**
```bash
docker pull ghcr.io/<你的用户名>/<仓库名>/allinone:latest
```

**运行：**
```bash
docker run --gpus all \
  -v $PWD/audio:/app/input \
  -v $PWD/results:/app/output \
  ghcr.io/<你的用户名>/<仓库名>/allinone:latest \
  /app/input/your_audio.wav
```

## 触发方式

### 自动触发

当推送到`main`分支并修改以下文件时：

- **本地GPU版本**: `Dockerfile.local.gpu`, `src/**`, `requirements.txt`
- **GCP版本**: `Dockerfile.gcp.gpu`, `src/**`, `requirements.txt`

### 手动触发

1. 进入GitHub仓库的 **Actions** 标签
2. 选择对应的workflow
3. 点击 **Run workflow**
4. 输入镜像标签（可选，默认：latest）
5. 点击运行

## 查看构建的镜像

构建完成后，在仓库的 **Packages** 页面可以看到：
- `allinone-local` - 本地GPU版本
- `allinone` - GCP版本

所有镜像默认设置为公开（Public），可以直接拉取使用。

## 本地使用示例

### 使用本地GPU镜像

```bash
# 拉取镜像
docker pull ghcr.io/<你的用户名>/<仓库名>/allinone-local:latest

# 准备目录
mkdir -p audio results tracks
cp your_song.wav audio/

# 运行分析
docker run --gpus all \
  -v $PWD/audio:/app/input \
  -v $PWD/results:/app/output \
  -v $PWD/tracks:/app/tracks \
  ghcr.io/<你的用户名>/<仓库名>/allinone-local:latest \
  --out-dir /app/output/analysis \
  --viz-dir /app/output/visualizations \
  --sonif-dir /app/output/sonifications \
  --demix-dir /app/tracks \
  --spec-dir /app/output/spectrograms \
  --keep-byproducts \
  /app/input/your_song.wav
```

### 使用GCP镜像

```bash
# 拉取镜像
docker pull ghcr.io/<你的用户名>/<仓库名>/allinone:latest

# 运行（同样的参数）
docker run --gpus all \
  -v $PWD/audio:/app/input \
  -v $PWD/results:/app/output \
  ghcr.io/<你的用户名>/<仓库名>/allinone:latest \
  --out-dir /app/output/analysis \
  /app/input/your_song.wav
```

## 常见问题

### Q: 应该使用哪个镜像？

- **本地开发/测试**: 使用 `allinone-local`（推荐）
- **GCP部署**: 使用 `allinone`
- **需要GCS访问**: 使用 `allinone`

### Q: 镜像大小有差异吗？

是的，`allinone-local` 比 `allinone` 小约100-200MB，因为移除了GCP SDK依赖。

### Q: 如何指定特定版本？

构建时使用不同的标签：
```bash
# 手动触发时输入标签，例如: v1.0.0
docker pull ghcr.io/<你的用户名>/<仓库名>/allinone-local:v1.0.0
```

### Q: GITHUB_TOKEN需要配置吗？

不需要，这是GitHub Actions自动提供的，只要workflow中设置了正确的permissions即可。
