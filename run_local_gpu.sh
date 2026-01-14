#!/bin/bash
# 本地GPU运行脚本

set -euo pipefail

IMAGE_NAME=${IMAGE_NAME:-ghcr.io/future-insight/all-in-one-docker-gpu-job/allinone-local:latest}
AUDIO_PATH=${AUDIO_PATH:-$PWD/audio}
RESULTS_PATH=${RESULTS_PATH:-$PWD/results}
TRACKS_PATH=${TRACKS_PATH:-$PWD/tracks}
CACHE_PATH=${CACHE_PATH:-$PWD/cache}
BUILD=0

usage() {
  echo "用法:"
  echo "  ./run_local_gpu.sh <音频文件名> [选项]"
  echo "  ./run_local_gpu.sh your_song.wav"
  echo "  ./run_local_gpu.sh your_song.wav -i allinone-local-gpu -b"
  echo ""
  echo "参数:"
  echo "  -i  镜像名（默认 allinone-local-gpu）"
  echo "  -b  先构建镜像（Dockerfile.local.gpu）"
  echo "  -a  音频文件目录（默认 ./audio）"
  echo "  -r  结果输出目录（默认 ./results）"
  echo "  -t  音轨输出目录（默认 ./tracks）"
  echo "  -c  模型缓存目录（默认 ./cache）"
  echo "  -h  显示帮助信息"
}

# 提取文件名参数（第一个参数）
FILENAME=""
if [ $# -gt 0 ] && [[ ! "$1" =~ ^- ]]; then
  FILENAME="$1"
  shift
fi

# 解析选项参数
while getopts ":i:a:r:t:c:bh" opt; do
  case "${opt}" in
    i) IMAGE_NAME="${OPTARG}" ;;
    a) AUDIO_PATH="${OPTARG}" ;;
    r) RESULTS_PATH="${OPTARG}" ;;
    t) TRACKS_PATH="${OPTARG}" ;;
    c) CACHE_PATH="${OPTARG}" ;;
    b) BUILD=1 ;;
    h)
      usage
      exit 0
      ;;
    \?)
      echo "未知参数: -${OPTARG}"
      usage
      exit 1
      ;;
    :)
      echo "参数 -${OPTARG} 需要值"
      usage
      exit 1
      ;;
  esac
done

# 检查是否提供了文件名
if [ -z "$FILENAME" ]; then
    echo "错误: 未提供音频文件名"
    echo ""
    usage
    exit 1
fi

# 检查文件是否存在
if [ ! -f "$AUDIO_PATH/$FILENAME" ]; then
    echo "错误: 找不到文件 $AUDIO_PATH/$FILENAME"
    exit 1
fi

echo "=== 使用本地GPU运行音频分析 ==="
echo "镜像: ${IMAGE_NAME}"
echo "输入文件: $FILENAME"
echo "音频目录: $AUDIO_PATH"
echo "结果目录: $RESULTS_PATH"
echo "音轨目录: $TRACKS_PATH"
echo "缓存目录: $CACHE_PATH"
echo ""

if [ "${BUILD}" -eq 1 ]; then
  echo "=== 构建镜像: ${IMAGE_NAME} ==="
  docker build -f Dockerfile.local.gpu -t "${IMAGE_NAME}" .
  echo ""
fi

# 确保缓存目录存在
mkdir -p "$CACHE_PATH"

docker run --gpus all -it --rm \
    -v "$AUDIO_PATH":/app/input \
    -v "$RESULTS_PATH":/app/output \
    -v "$TRACKS_PATH":/app/tracks \
    -v "$CACHE_PATH":/root/.cache \
    "${IMAGE_NAME}" \
    --out-dir /app/output/analysis \
    --viz-dir /app/output/visualizations \
    --sonif-dir /app/output/sonifications \
    --demix-dir /app/tracks \
    --spec-dir /app/output/spectrograms \
    --device cuda \
    --keep-byproducts \
    /app/input/"$FILENAME"

echo ""
echo "=== 分析完成 ==="
echo "结果保存在 $RESULTS_PATH/"
