#!/usr/bin/env bash
# ============================================================================
# build-ffmpegkitnext.sh — 一键构建 FFmpegKitNext Android AAR 并拷入本仓库
#
# 用法（在 Linux / macOS / WSL2 中执行）：
#   export ANDROID_SDK_ROOT=$HOME/Android/Sdk
#   export ANDROID_NDK_ROOT=$HOME/Android/Sdk/ndk/27.2.12479018
#   ./build-ffmpegkitnext.sh
#
# 可调环境变量：
#   FFMPEG_KIT_VERSION  构建/检出版本 tag，默认 9.0.1（需与 gradle/dependencies.gradle 对齐）
#   FFMPEG_KIT_BUILD_DIR  构建工作目录，默认 $HOME/ffmpeg-kit-next-build
#   FFMPEG_KIT_API_LEVEL  minSdk，默认 26（与本仓库 app 模块一致）
#   FFMPEG_KIT_JOBS      并行任务数，默认 nproc
#   FFMPEG_KIT_GPL=1     启用 GPL（--enable-gpl --enable-x264 --enable-x265），整包变 GPL v3.0
#   FFMPEG_KIT_DISABLE_OPENSSL=1  不编 HTTPS（减小体积）
# ============================================================================
set -euo pipefail

FFMPEG_KIT_VERSION="${FFMPEG_KIT_VERSION:-9.0.1}"
FFMPEG_KIT_REPO="https://github.com/arthenica/ffmpeg-kit-next.git"
WORK_DIR="${FFMPEG_KIT_BUILD_DIR:-$HOME/ffmpeg-kit-next-build}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREBUILT_DIR="${REPO_DIR}/ffmpeg-kit-prebuilt"
API_LEVEL="${FFMPEG_KIT_API_LEVEL:-26}"
JOBS="${FFMPEG_KIT_JOBS:-$(nproc 2>/dev/null || echo 4)}"
GPL="${FFMPEG_KIT_GPL:-0}"
OPENSSL="${FFMPEG_KIT_DISABLE_OPENSSL:-0}"

log() { echo -e "\033[1;32m[build-ffmpegkitnext]\033[0m $*"; }
die() { echo -e "\033[1;31m[build-ffmpegkitnext][ERROR]\033[0m $*" >&2; exit 1; }

# ---------- 1. 环境检查 ----------
[[ -n "${ANDROID_SDK_ROOT:-}" ]] || die "ANDROID_SDK_ROOT 未设置"
[[ -n "${ANDROID_NDK_ROOT:-}" ]] || die "ANDROID_NDK_ROOT 未设置"
[[ -d "${ANDROID_SDK_ROOT}" ]] || die "ANDROID_SDK_ROOT 不存在: ${ANDROID_SDK_ROOT}"
[[ -d "${ANDROID_NDK_ROOT}" ]] || die "ANDROID_NDK_ROOT 不存在: ${ANDROID_NDK_ROOT}"
command -v git >/dev/null || die "缺少 git"
command -v java >/dev/null || die "缺少 java（构建 AAR 需要 Gradle）"
command -v make >/dev/null || die "缺少 make"
log "SDK: ${ANDROID_SDK_ROOT}"
log "NDK: ${ANDROID_NDK_ROOT}"

# ---------- 2. 准备源码 ----------
if [[ ! -d "${WORK_DIR}/.git" ]]; then
  log "克隆 ffmpeg-kit-next → ${WORK_DIR}"
  mkdir -p "${WORK_DIR}"
  git clone "${FFMPEG_KIT_REPO}" "${WORK_DIR}"
else
  log "复用已有源码 ${WORK_DIR}（如需全新构建可删除该目录）"
fi
cd "${WORK_DIR}"
git fetch --tags --force origin
if git rev-parse -q --verify "refs/tags/${FFMPEG_KIT_VERSION}" >/dev/null; then
  git checkout -f "tags/${FFMPEG_KIT_VERSION}"
elif git rev-parse -q --verify "refs/tags/v${FFMPEG_KIT_VERSION}" >/dev/null; then
  git checkout -f "tags/v${FFMPEG_KIT_VERSION}"
else
  log "警告：未找到 tag ${FFMPEG_KIT_VERSION}，使用默认分支（产物版本可能 ≠ ${FFMPEG_KIT_VERSION}）"
  git checkout -f main
fi

# ---------- 3. 组装 android.sh 参数 ----------
ARGS=()
ARGS+=(--api-level=${API_LEVEL})
ARGS+=(--jobs=${JOBS})
ARGS+=(--force)
# 与本仓库 app 模块 abiFilters 对齐：只编 arm64-v8a + x86_64
ARGS+=(--disable-arm-v7a --disable-arm-v7a-neon --disable-x86)
# HTTPS（openssl）与 GPL 库
if [[ "${OPENSSL}" == "1" ]]; then ARGS+=(--disable-openssl); else ARGS+=(--enable-openssl); fi
if [[ "${GPL}" == "1" ]]; then
  ARGS+=(--enable-gpl --enable-x264 --enable-x265)
  log "已启用 GPL（x264/x265），产物整包为 GPL v3.0，商用前请评估合规"
fi

log "执行: ./android.sh ${ARGS[*]}"
log "构建耗时通常 20~90 分钟，日志在 ${WORK_DIR}/build.log"
./android.sh "${ARGS[@]}"

# ---------- 4. 拷贝 AAR/POM 到仓库 ----------
SRC_ROOT="${WORK_DIR}/prebuilt"
if [[ ! -d "${SRC_ROOT}" ]]; then
  die "构建完成但未找到 ${SRC_ROOT}，请查看 ${WORK_DIR}/build.log"
fi

FOUND=$(find "${SRC_ROOT}" -type d -path "*com/arthenica/ffmpeg-kit-next*" | head -1)
[[ -n "${FOUND}" ]] || die "未在 prebuilt 下找到 com/arthenica/ffmpeg-kit-next 产物"

PRODUCT_VERSION=$(basename "${FOUND}")
mkdir -p "${PREBUILT_DIR}/com/arthenica/ffmpeg-kit-next/${PRODUCT_VERSION}"
cp -f "${FOUND}/"* "${PREBUILT_DIR}/com/arthenica/ffmpeg-kit-next/${PRODUCT_VERSION}/"
log "已拷贝 AAR → ${PREBUILT_DIR}/com/arthenica/ffmpeg-kit-next/${PRODUCT_VERSION}/"
ls -lh "${PREBUILT_DIR}/com/arthenica/ffmpeg-kit-next/${PRODUCT_VERSION}/"

# ---------- 5. 版本一致性提示 ----------
GRADLE_VER=$(grep -oE 'ffmpegKitNextVersion = "[^"]+"' "${REPO_DIR}/gradle/dependencies.gradle" || true)
if [[ -n "${GRADLE_VER}" && "${GRADLE_VER}" != *"${PRODUCT_VERSION}"* ]]; then
  log "注意：gradle/dependencies.gradle 当前为 ${GRADLE_VER}，与产物版本 ${PRODUCT_VERSION} 不一致"
  log "请手动改为：ffmpegKitNextVersion = \"${PRODUCT_VERSION}\""
else
  log "版本一致：ffmpegKitNextVersion = ${PRODUCT_VERSION}"
fi

log "完成。现在可回到仓库执行：gradlew :app:assembleDebug"
