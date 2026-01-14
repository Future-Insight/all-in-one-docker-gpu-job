#!/bin/bash
# 本地GPU启动 Web API（FastAPI）

set -euo pipefail

IMAGE_NAME=${IMAGE_NAME:-allinone-local-gpu}
PORT=${PORT:-8000}
API_KEYS=${API_KEYS:-secret-key-1}
BUILD=0

usage() {
  echo "用法:"
  echo "  API_KEYS=\"k1,k2\" ./run_local_api.sh"
  echo "  ./run_local_api.sh -k \"k1,k2\" -p 8000 -i allinone-local-gpu -b"
  echo ""
  echo "参数:"
  echo "  -k  API_KEYS（逗号分隔）"
  echo "  -p  本地监听端口（默认 8000）"
  echo "  -i  镜像名（默认 allinone-local-gpu）"
  echo "  -b  先构建镜像（Dockerfile.local.gpu）"
}

while getopts ":k:p:i:bh" opt; do
  case "${opt}" in
    k) API_KEYS="${OPTARG}" ;;
    p) PORT="${OPTARG}" ;;
    i) IMAGE_NAME="${OPTARG}" ;;
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

echo "=== 启动 Music Analysis Web API ==="
echo "镜像: ${IMAGE_NAME}"
echo "端口: ${PORT}"
echo "API_KEYS: ${API_KEYS}"
echo ""

if [ "${BUILD}" -eq 1 ]; then
  echo "=== 构建镜像: ${IMAGE_NAME} ==="
  docker build -f Dockerfile.local.gpu -t "${IMAGE_NAME}" .
  echo ""
fi

docker run --gpus all -it --rm \
  -p ${PORT}:8000 \
  -e API_KEYS="${API_KEYS}" \
  ${IMAGE_NAME} api
