#!/usr/bin/env bash
# 直接用本机代码启动 Web（FastAPI Swagger: /docs），不使用 Docker 镜像

set -euo pipefail

HOST=${HOST:-0.0.0.0}
PORT=${PORT:-8000}
API_KEYS=${API_KEYS:-secret-key-1}
VENV_DIR=${VENV_DIR:-.venv}
RELOAD=${RELOAD:-1}
INSTALL_DEPS=1

usage() {
  echo "用法:"
  echo "  ./run_local_web_code.sh"
  echo "  API_KEYS=\"k1,k2\" ./run_local_web_code.sh"
  echo "  ./run_local_web_code.sh -k \"k1,k2\" -p 8000 -H 127.0.0.1"
  echo ""
  echo "参数:"
  echo "  -k  API_KEYS（逗号分隔）"
  echo "  -H  监听地址（默认 0.0.0.0）"
  echo "  -p  端口（默认 8000）"
  echo "  -v  venv 目录（默认 ./.venv）"
  echo "  -r  是否开启 --reload（0/1，默认 1）"
  echo "  -n  不自动安装依赖（跳过 pip install）"
  echo "  -h  显示帮助信息"
}

while getopts ":k:H:p:v:r:nh" opt; do
  case "${opt}" in
    k) API_KEYS="${OPTARG}" ;;
    H) HOST="${OPTARG}" ;;
    p) PORT="${OPTARG}" ;;
    v) VENV_DIR="${OPTARG}" ;;
    r) RELOAD="${OPTARG}" ;;
    n) INSTALL_DEPS=0 ;;
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

if ! command -v python3 >/dev/null 2>&1; then
  echo "错误: 未找到 python3，请先安装 Python 3。"
  exit 1
fi

if [ ! -d "${VENV_DIR}" ]; then
  echo "=== 创建 venv: ${VENV_DIR} ==="
  python3 -m venv "${VENV_DIR}"
fi

# shellcheck disable=SC1090
source "${VENV_DIR}/bin/activate"

python -m pip install -q --upgrade pip >/dev/null

if [ "${INSTALL_DEPS}" -eq 1 ]; then
  echo "=== 安装 API 依赖: requirements_api.txt ==="
  pip install -r requirements_api.txt
fi

echo "=== 启动 Web（FastAPI） ==="
echo "地址: http://localhost:${PORT}/docs"
echo "API_KEYS: ${API_KEYS}"
echo ""

# pydantic-settings(2.6.x) 会把 list 类型环境变量按 JSON 解析，这里统一转成 JSON 数组字符串
API_KEYS_JSON="["
IFS=',' read -ra KEYS <<< "${API_KEYS}"
for i in "${!KEYS[@]}"; do
  key=$(echo "${KEYS[$i]}" | xargs)
  if [ $i -gt 0 ]; then
    API_KEYS_JSON="${API_KEYS_JSON},"
  fi
  API_KEYS_JSON="${API_KEYS_JSON}\"${key}\""
done
API_KEYS_JSON="${API_KEYS_JSON}]"

export API_KEYS="${API_KEYS_JSON}"

reload_args=()
if [ "${RELOAD}" = "1" ]; then
  reload_args+=(--reload)
fi

exec uvicorn api.main:app --host "${HOST}" --port "${PORT}" "${reload_args[@]}"
