package com.reapiroo.reapiroo;

import android.media.MediaRecorder;
import android.os.Build;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.reapiroo.reapiroo/audio_recorder";
    private MediaRecorder mediaRecorder;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if (call.method.equals("startRecording")) {
                        String filePath = call.argument("filePath");
                        try {
                            if (mediaRecorder != null) {
                                try { mediaRecorder.stop(); } catch (Exception ignored) {}
                                mediaRecorder.release();
                                mediaRecorder = null;
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                mediaRecorder = new MediaRecorder(this);
                            } else {
                                mediaRecorder = new MediaRecorder();
                            }
                            mediaRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);
                            mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
                            mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
                            mediaRecorder.setAudioSamplingRate(44100);
                            mediaRecorder.setAudioEncodingBitRate(96000);
                            mediaRecorder.setOutputFile(filePath);
                            mediaRecorder.prepare();
                            mediaRecorder.start();
                            result.success(true);
                        } catch (Exception e) {
                            result.error("RECORDING_ERROR", e.getMessage(), null);
                        }
                    } else if (call.method.equals("stopRecording")) {
                        try {
                            if (mediaRecorder != null) {
                                mediaRecorder.stop();
                                mediaRecorder.release();
                                mediaRecorder = null;
                            }
                            result.success(true);
                        } catch (Exception e) {
                            if (mediaRecorder != null) {
                                mediaRecorder.release();
                                mediaRecorder = null;
                            }
                            result.success(false);
                        }
                    } else {
                        result.notImplemented();
                    }
                });
    }
}
