#!/bin/bash
# 本地GPU运行脚本

AUDIO_PATH=$PWD/audio
RESULTS_PATH=$PWD/results
TRACKS_PATH=$PWD/tracks
FILENAME=$1

if [ -z "$FILENAME" ]; then
    echo "用法: ./run_local_gpu.sh <音频文件名>"
    echo "示例: ./run_local_gpu.sh your_song.wav"
    exit 1
fi

# 检查文件是否存在
if [ ! -f "$AUDIO_PATH/$FILENAME" ]; then
    echo "错误: 找不到文件 $AUDIO_PATH/$FILENAME"
    exit 1
fi

echo "=== 使用本地GPU运行音频分析 ==="
echo "输入文件: $FILENAME"
echo ""

docker run --gpus all -it \
    -v $AUDIO_PATH:/app/input \
    -v $RESULTS_PATH:/app/output \
    -v $TRACKS_PATH:/app/tracks \
    allinone-local-gpu \
    --out-dir /app/output/analysis \
    --viz-dir /app/output/visualizations \
    --sonif-dir /app/output/sonifications \
    --demix-dir /app/tracks \
    --spec-dir /app/output/spectrograms \
    --device cuda \
    --keep-byproducts \
    /app/input/$FILENAME

echo ""
echo "=== 分析完成 ==="
echo "结果保存在 $RESULTS_PATH/"
