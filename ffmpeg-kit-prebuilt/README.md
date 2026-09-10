# ffmpeg-kit-prebuilt（本地 Maven 仓库）

存放 **FFmpegKitNext** 构建机产出的 AAR 与 POM，供本仓库 Gradle 直接引用。

## 目录结构（构建机 `prebuilt/` 目录原样拷贝）

```
ffmpeg-kit-prebuilt/
└── com/arthenica/ffmpeg-kit-next/<version>/
    ├── ffmpeg-kit-next-<version>.aar
    └── ffmpeg-kit-next-<version>.pom
```

根 `build.gradle` 已注册：`maven { url = uri("$rootDir/ffmpeg-kit-prebuilt") }`
版本号在 `gradle/dependencies.gradle` 的 `ffmpegKitNextVersion` 中配置，需与这里目录名一致。

## 如何产出（构建机，一次性）

参考《GSYVideoPlayer_ffmpegkitnext_guide.md》：

```bash
git clone https://github.com/arthenica/ffmpeg-kit-next.git
cd ffmpeg-kit-next
export ANDROID_SDK_ROOT=$HOME/Android/Sdk
export ANDROID_NDK_ROOT=$HOME/Android/Sdk/ndk/27.2.12479018
# 架构说明：arm-v7a-neon（armeabi-v7a）默认启用；arm-v7a 与 arm-v7a-neon 共用
# armeabi-v7a ABI（官方 main release 只含 neon 版），故仅显式禁用非 neon 的 arm-v7a 与 32 位 x86。
# 最终产物 ABI：arm64-v8a + armeabi-v7a + x86_64。
./android.sh --disable-arm-v7a --disable-x86 \
             --enable-openssl --api-level=26 --jobs=8
# 产物：prebuilt/<type>/com/arthenica/ffmpeg-kit-next/<version>/...
```

构建成功后把 `prebuilt/<type>/` 下内容拷贝到本目录，并同步修改
`gradle/dependencies.gradle` 中的 `ffmpegKitNextVersion`。

## 依赖说明

- POM 声明 runtime 依赖 `com.arthenica:smart-exception-java:0.2.1`，由 Maven Central 解析（根 `build.gradle` 已配置 `mavenCentral()`）。
- 若未放入 AAR 前执行构建，`app` 模块会报 `Could not find com.arthenica:ffmpeg-kit-next:<version>`，属预期。
