package com.example.gsyvideoplayer.ffmpeg;

import android.os.Bundle;
import android.text.TextUtils;
import android.view.View;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;

import com.example.gsyvideoplayer.R;
import com.example.gsyvideoplayer.databinding.ActivityFfmpegFrameExtractBinding;

import java.io.File;

/**
 * FFmpegKitNext 示例：视频每 1 秒截取 1 帧。
 *
 * <p>用法：输入本地视频绝对路径（或 http/https 地址），点击"开始截帧"，
 * 输出到 App 外部目录 Android/data/com.example.gsyvideoplayer/files/ffmpeg_frames/。</p>
 */
public class FfmpegFrameExtractActivity extends AppCompatActivity {

    private ActivityFfmpegFrameExtractBinding binding;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        binding = ActivityFfmpegFrameExtractBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());

        binding.btnStart.setOnClickListener(v -> startExtract());
        binding.btnCancel.setOnClickListener(v -> {
            FfmpegKitRunner.cancel();
            appendLog(">>> 已发送取消");
        });
    }

    private void startExtract() {
        String input = binding.etInput.getText().toString().trim();
        if (TextUtils.isEmpty(input)) {
            Toast.makeText(this, "请输入视频路径或 URL", Toast.LENGTH_SHORT).show();
            return;
        }

        File outputDir = new File(getExternalFilesDir(null), "ffmpeg_frames");
        //noinspection ResultOfMethodCallIgnored
        outputDir.mkdirs();
        binding.tvLog.setText(""); // 清空日志

        appendLog(">>> 输入: " + input);
        appendLog(">>> 输出: " + outputDir.getAbsolutePath());
        appendLog(">>> 命令: ffmpeg -y -i " + input + " -vf fps=1 -q:v 2 " + outputDir + "/frame_%03d.jpg");
        appendLog(">>> 开始执行（每 1 秒截取 1 帧）...");

        FfmpegKitRunner.extractFramePerSecond(input, outputDir,
                new FfmpegKitRunner.FrameExtractCallback() {
                    @Override
                    public void onLog(String line) {
                        runOnUiThread(() -> appendLog(line));
                    }

                    @Override
                    public void onDone(boolean success, String summary) {
                        runOnUiThread(() -> {
                            appendLog(">>> " + (success ? "完成" : "失败") + "：" + summary);
                            Toast.makeText(FfmpegFrameExtractActivity.this,
                                    success ? "截帧完成" : "截帧失败", Toast.LENGTH_LONG).show();
                        });
                    }
                });
    }

    private void appendLog(String line) {
        // 限制最大行数，避免长命令日志卡 UI
        String current = binding.tvLog.getText().toString();
        String next = current + line + "\n";
        String[] lines = next.split("\n", -1);
        if (lines.length > 400) {
            StringBuilder sb = new StringBuilder();
            for (int i = lines.length - 400; i < lines.length; i++) {
                sb.append(lines[i]).append('\n');
            }
            next = sb.toString();
        }
        binding.tvLog.setText(next);
        binding.scrollLog.post(() -> binding.scrollLog.fullScroll(View.FOCUS_DOWN));
    }
}
