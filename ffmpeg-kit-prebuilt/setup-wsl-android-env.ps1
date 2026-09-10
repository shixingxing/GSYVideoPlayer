# ============================================================================
# setup-wsl-android-env.ps1 — 在本机 Windows 上搭建 WSL2 + Android SDK/NDK，
#                            并一键构建 FFmpegKitNext AAR（需以管理员运行）
#
# 用法：
#   1. 右键 PowerShell → 以管理员身份运行
#   2. 执行：powershell -ExecutionPolicy Bypass -File .\setup-wsl-android-env.ps1
#
# 注意：
#   - 首次启用 WSL 通常需要【重启 Windows】（脚本会提示）
#   - 全程下载约 2~4 GB（Ubuntu + SDK + NDK r27d + ffmpeg 源码）
#   - 构建耗时约 20~90 分钟，可在后台挂机
# ============================================================================
$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Distro = "Ubuntu"
$SdkInWsl = '~/android-sdk'
$NdkVersion = "27.2.12479018"
$ApiLevel = "26"
$RepoWin = "F:\work\GSYVideoPlayer"
$BuildScriptWsl = "/mnt/f/work/GSYVideoPlayer/ffmpeg-kit-prebuilt/build-ffmpegkitnext.sh"

function Write-Step([string]$msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }

# ---------- 1. 检查/安装 WSL ----------
Write-Step "检查 WSL"
$wslStatus = wsl.exe --status 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
    Write-Host "WSL 未就绪，开始安装（可能提示重启）..."
    wsl.exe --install -d $Distro --no-launch
    if ($LASTEXITCODE -ne 0) { throw "wsl --install 失败，请检查 Windows 版本（需 Win10 2004+ / Win11）" }
    Write-Host "WSL 安装完成。若系统提示重启，请重启后重新运行本脚本。" -ForegroundColor Yellow
    exit 0
}
Write-Host "WSL 已安装："
wsl.exe -l -v

# ---------- 2. 在 WSL 内安装系统依赖 + Android SDK/NDK ----------
Write-Step "在 $Distro 内安装依赖与 SDK/NDK（首次约 1~3 GB 下载）"
$setupBash = @'
set -e
echo ">>> apt 安装基础依赖"
sudo apt-get update -qq
sudo apt-get install -y -qq git make yasm pkg-config autoconf automake libtool \
    openjdk-17-jdk-headless unzip curl >/dev/null

SDK="$HOME/android-sdk"
export ANDROID_SDK_ROOT="$SDK"
export ANDROID_NDK_ROOT="$SDK/ndk/__NDK__"

if [ ! -d "$SDK/cmdline-tools/latest" ]; then
  echo ">>> 下载 Android cmdline-tools"
  mkdir -p "$SDK/cmdline-tools"
  curl -sSL -o /tmp/clt.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
  unzip -q /tmp/clt.zip -d "$SDK/cmdline-tools"
  mv "$SDK/cmdline-tools/cmdline-tools" "$SDK/cmdline-tools/latest"
fi

echo ">>> sdkmanager 安装 platform-tools / platforms;android-__API__ / ndk;__NDK__"
yes | "$SDK/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK" \
    "platform-tools" "platforms;android-__API__" "ndk;__NDK__" >/dev/null
echo ">>> WSL 环境就绪: $SDK"
'@
$setupBash = $setupBash.Replace("__NDK__", $NdkVersion).Replace("__API__", $ApiLevel)

wsl.exe -d $Distro -e bash -lc $setupBash
if ($LASTEXITCODE -ne 0) { throw "WSL 内环境准备失败" }

# ---------- 3. 运行构建脚本 ----------
Write-Step "开始构建 FFmpegKitNext AAR（20~90 分钟，日志在 WSL 内 build.log）"
wsl.exe -d $Distro -e bash -lc "export ANDROID_SDK_ROOT='$SdkInWsl' && export ANDROID_NDK_ROOT='$SdkInWsl/ndk/$NdkVersion' && bash $BuildScriptWsl"
if ($LASTEXITCODE -ne 0) { throw "构建失败，请查看 WSL 内 ~/ffmpeg-kit-next-build/build.log" }

Write-Step "完成"
Write-Host "AAR 已拷贝到 $RepoWin\ffmpeg-kit-prebuilt\com\arthenica\ffmpeg-kit-next\" -ForegroundColor Green
Write-Host "接下来在仓库执行: .\gradlew.bat :app:assembleDebug"
