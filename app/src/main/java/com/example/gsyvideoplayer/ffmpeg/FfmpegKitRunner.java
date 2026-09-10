package com.example.gsyvideoplayer.ffmpeg;

import android.content.Context;
import android.util.Log;

import com.arthenica.ffmpegkit.FFmpegKit;
import com.arthenica.ffmpegkit.FFmpegSession;
import com.arthenica.ffmpegkit.FFmpegSessionCompleteCallback;
import com.arthenica.ffmpegkit.Log;
import com.arthenica.ffmpegkit.LogCallback;
import com.arthenica.ffmpegkit.ReturnCode;
import com.arthenica.ffmpegkit.Statistics;
import com.arthenica.ffmpegkit.StatisticsCallback;

import java.io.File;

/**
 * FFmpegKitNext 封装工具类：在 Android 端执行 ffmpeg 命令。
 *
 * <p>与 GSYVideoPlayer 播放内核（ijk/FFmpeg 解码库）完全解耦：
 * 播放走 libijkffmpeg.so，命令行走 FFmpegKitNext 自带的 ffmpeg .so。</p>
 */
public final class FfmpegKitRunner {

    private static final String TAG = "FfmpegKitRunner";

    private FfmpegKitRunner() {
    }

    /** 进度/结果回调（回调线程为 FFmpegKit 内部线程，UI 更新需自行切主线程）。 */
    public interface FrameExtractCallback {
        void onLog(String line);

        void onDone(boolean success, String summary);
    }

    /**
     * 视频每 1 秒截取 1 帧。
     *
     * <p>命令等价于：</p>
     * <pre>
     * ffmpeg -y -i &lt;input&gt; -vf fps=1 -q:v 2 &lt;outputDir&gt;/frame_%03d.jpg
     * </pre>
     * <ul>
     *   <li>{@code fps=1}：每 1 秒输出 1 帧（fps 滤镜按时间轴等间隔取样）</li>
     *   <li>{@code -q:v 2}：JPEG 质量（2≈高质量，范围 2~31，越小越好）</li>
     *   <li>{@code frame_%03d.jpg}：输出序列帧 frame_001.jpg、frame_002.jpg …</li>
     * </ul>
     *
     * @param inputPath 输入视频：本地绝对路径（如 /storage/emulated/0/Movies/a.mp4）或 http(s) 网络地址
     * @param outputDir 输出目录（不存在会自动创建）
     * @param callback  日志与完成回调
     */
    public static void extractFramePerSecond(String inputPath,
                                             File outputDir, FrameExtractCallback callback) {
        if (outputDir != null && !outputDir.exists()) {
            //noinspection ResultOfMethodCallIgnored
            outputDir.mkdirs();
        }

        String outPattern = new File(outputDir, "frame_%03d.jpg").getAbsolutePath();
        // 路径含空格时用引号包裹；FFmpegKit 命令行解析支持引号
        String command = "-y -i " + quote(inputPath)
                + " -vf fps=1 -q:v 2 " + quote(outPattern);
        Log.d(TAG, "ffmpeg cmd: " + command);

        FFmpegKit.executeAsync(command,
                new FFmpegSessionCompleteCallback() {
                    @Override
                    public void apply(FFmpegSession session) {
                        boolean success = ReturnCode.isSuccess(session.getReturnCode());
                        String summary;
                        if (success) {
                            File[] files = outputDir == null ? new File[0]
                                    : outputDir.listFiles((dir, name) -> name.endsWith(".jpg"));
                            summary = "成功：共生成 " + (files == null ? 0 : files.length)
                                    + " 张图片，目录 " + outputDir;
                        } else {
                            String detail = session.getFailStackTrace();
                            summary = "失败：exitCode=" + session.getReturnCode()
                                    + (detail == null || detail.isEmpty() ? "" : "\n" + detail);
                        }
                        if (callback != null) {
                            callback.onDone(success, summary);
                        }
                    }
                },
                new LogCallback() {
                    @Override
                    public void apply(Log log) {
                        if (callback != null && log != null && log.getMessage() != null) {
                            callback.onLog(log.getMessage());
                        }
                    }
                },
                new StatisticsCallback() {
                    @Override
                    public void apply(Statistics statistics) {
                        // 可选：statistics.getVideoFrameNumber() / getVideoFps() 可做进度
                    }
                });
    }

    /** 取消正在运行的命令（同步/异步均可）。 */
    public static void cancel() {
        FFmpegKit.cancel();
    }

    private static String quote(String s) {
        if (s == null) {
            return "\"\"";
        }
        return "\"" + s.replace("\"", "\\\"") + "\"";
    }
}
