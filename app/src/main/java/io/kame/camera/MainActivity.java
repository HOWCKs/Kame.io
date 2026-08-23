package io.kame.camera;

import android.Manifest;
import android.content.ContentValues;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.provider.MediaStore;
import android.view.Gravity;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.activity.ComponentActivity;
import androidx.annotation.NonNull;
import androidx.camera.core.Camera;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ImageCapture;
import androidx.camera.core.ImageCaptureException;
import androidx.camera.core.Preview;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.video.MediaStoreOutputOptions;
import androidx.camera.video.PendingRecording;
import androidx.camera.video.Recorder;
import androidx.camera.video.Recording;
import androidx.camera.video.VideoCapture;
import androidx.camera.video.VideoRecordEvent;
import androidx.camera.view.PreviewView;
import androidx.core.content.ContextCompat;

import com.google.common.util.concurrent.ListenableFuture;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

public class MainActivity extends ComponentActivity {
    private static final int REQUEST_PERMISSIONS = 7;

    private PreviewView previewView;
    private TextView statusText;
    private Button photoButton;
    private Button videoButton;
    private Button switchButton;
    private Button flashButton;
    private Button zoomInButton;
    private Button zoomOutButton;

    private Camera camera;
    private ImageCapture imageCapture;
    private VideoCapture<Recorder> videoCapture;
    private Recording recording;
    private int lensFacing = CameraSelector.LENS_FACING_BACK;
    private boolean torchEnabled = false;
    private float zoomRatio = 1f;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        buildUi();
        if (hasCameraPermission()) {
            startCamera();
        } else {
            requestPermissions(new String[]{Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO}, REQUEST_PERMISSIONS);
        }
    }

    @Override
    protected void onDestroy() {
        if (recording != null) recording.stop();
        super.onDestroy();
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQUEST_PERMISSIONS && hasCameraPermission()) {
            startCamera();
        } else {
            toast("Permissão da câmera é obrigatória.");
        }
    }

    private void buildUi() {
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);

        previewView = new PreviewView(this);
        previewView.setScaleType(PreviewView.ScaleType.FILL_CENTER);
        previewView.setImplementationMode(PreviewView.ImplementationMode.PERFORMANCE);
        root.addView(previewView, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
        ));

        statusText = new TextView(this);
        statusText.setText("Kame Camera • qualidade automática máxima");
        statusText.setTextColor(Color.WHITE);
        statusText.setTextSize(14f);
        statusText.setPadding(24, 30, 24, 12);
        statusText.setShadowLayer(4f, 0f, 2f, Color.BLACK);
        root.addView(statusText, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.TOP
        ));

        LinearLayout controls = new LinearLayout(this);
        controls.setOrientation(LinearLayout.VERTICAL);
        controls.setGravity(Gravity.CENTER);
        controls.setPadding(16, 12, 16, 26);
        controls.setBackgroundColor(0x55000000);

        LinearLayout row1 = new LinearLayout(this);
        row1.setGravity(Gravity.CENTER);
        LinearLayout row2 = new LinearLayout(this);
        row2.setGravity(Gravity.CENTER);

        photoButton = cameraButton("Foto", this::takePhoto);
        videoButton = cameraButton("Gravar", this::toggleVideo);
        switchButton = cameraButton("Virar", this::switchCamera);
        flashButton = cameraButton("Flash", this::toggleFlash);
        zoomOutButton = cameraButton("Zoom -", () -> changeZoom(-0.25f));
        zoomInButton = cameraButton("Zoom +", () -> changeZoom(0.25f));

        row1.addView(photoButton);
        row1.addView(videoButton);
        row1.addView(switchButton);
        row2.addView(flashButton);
        row2.addView(zoomOutButton);
        row2.addView(zoomInButton);
        controls.addView(row1);
        controls.addView(row2);

        root.addView(controls, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM
        ));
        setContentView(root);
    }

    private Button cameraButton(String label, Runnable action) {
        Button button = new Button(this);
        button.setText(label);
        button.setTextColor(Color.WHITE);
        button.setBackgroundColor(0xAA102030);
        button.setOnClickListener(view -> action.run());
        return button;
    }

    private void startCamera() {
        ListenableFuture<ProcessCameraProvider> providerFuture = ProcessCameraProvider.getInstance(this);
        providerFuture.addListener(() -> {
            try {
                ProcessCameraProvider provider = providerFuture.get();
                CameraSelector selector = new CameraSelector.Builder().requireLensFacing(lensFacing).build();

                Preview preview = new Preview.Builder().build();
                preview.setSurfaceProvider(previewView.getSurfaceProvider());

                imageCapture = new ImageCapture.Builder()
                        .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
                        .setJpegQuality(100)
                        .build();

                Recorder recorder = new Recorder.Builder().build();
                videoCapture = VideoCapture.withOutput(recorder);

                provider.unbindAll();
                camera = provider.bindToLifecycle(this, selector, preview, imageCapture, videoCapture);
                torchEnabled = false;
                zoomRatio = 1f;
                status("Câmera pronta • foto máxima • vídeo automático");
            } catch (Exception error) {
                status("Erro ao abrir câmera: " + error.getMessage());
            }
        }, ContextCompat.getMainExecutor(this));
    }

    private void takePhoto() {
        if (imageCapture == null) return;
        String name = timestampName("IMG");
        ContentValues values = new ContentValues();
        values.put(MediaStore.MediaColumns.DISPLAY_NAME, name);
        values.put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg");
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.put(MediaStore.MediaColumns.RELATIVE_PATH, "Pictures/Kame Camera");
        }

        ImageCapture.OutputFileOptions options = new ImageCapture.OutputFileOptions.Builder(
                getContentResolver(),
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                values
        ).build();

        imageCapture.takePicture(options, ContextCompat.getMainExecutor(this), new ImageCapture.OnImageSavedCallback() {
            @Override
            public void onImageSaved(@NonNull ImageCapture.OutputFileResults outputFileResults) {
                status("Foto salva: " + name);
                toast("Foto salva na galeria");
            }

            @Override
            public void onError(@NonNull ImageCaptureException exception) {
                status("Erro ao salvar foto: " + exception.getMessage());
            }
        });
    }

    private void toggleVideo() {
        if (recording != null) {
            recording.stop();
            recording = null;
            videoButton.setText("Gravar");
            return;
        }
        if (videoCapture == null) return;

        String name = timestampName("VID");
        ContentValues values = new ContentValues();
        values.put(MediaStore.MediaColumns.DISPLAY_NAME, name);
        values.put(MediaStore.MediaColumns.MIME_TYPE, "video/mp4");
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/Kame Camera");
        }

        MediaStoreOutputOptions options = new MediaStoreOutputOptions.Builder(
                getContentResolver(),
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        ).setContentValues(values).build();

        PendingRecording pending = videoCapture.getOutput().prepareRecording(this, options);
        if (hasAudioPermission()) {
            pending = pending.withAudioEnabled();
        }

        recording = pending.start(ContextCompat.getMainExecutor(this), event -> {
            if (event instanceof VideoRecordEvent.Start) {
                videoButton.setText("Parar");
                status("Gravando vídeo...");
            } else if (event instanceof VideoRecordEvent.Finalize) {
                VideoRecordEvent.Finalize finalizeEvent = (VideoRecordEvent.Finalize) event;
                recording = null;
                videoButton.setText("Gravar");
                if (finalizeEvent.hasError()) {
                    status("Erro no vídeo: " + finalizeEvent.getError());
                } else {
                    status("Vídeo salvo: " + name);
                    toast("Vídeo salvo na galeria");
                }
            }
        });
    }

    private void switchCamera() {
        if (recording != null) {
            toast("Pare a gravação antes de trocar a câmera.");
            return;
        }
        lensFacing = lensFacing == CameraSelector.LENS_FACING_BACK
                ? CameraSelector.LENS_FACING_FRONT
                : CameraSelector.LENS_FACING_BACK;
        startCamera();
    }

    private void toggleFlash() {
        if (camera == null) return;
        if (!camera.getCameraInfo().hasFlashUnit()) {
            toast("Flash indisponível nesta câmera.");
            return;
        }
        torchEnabled = !torchEnabled;
        camera.getCameraControl().enableTorch(torchEnabled);
        flashButton.setText(torchEnabled ? "Flash ON" : "Flash");
    }

    private void changeZoom(float delta) {
        if (camera == null || camera.getCameraInfo().getZoomState().getValue() == null) return;
        float min = camera.getCameraInfo().getZoomState().getValue().getMinZoomRatio();
        float max = camera.getCameraInfo().getZoomState().getValue().getMaxZoomRatio();
        zoomRatio = Math.max(min, Math.min(max, zoomRatio + delta));
        camera.getCameraControl().setZoomRatio(zoomRatio);
        status("Zoom: " + String.format(Locale.US, "%.1f", zoomRatio) + "x");
    }

    private boolean hasCameraPermission() {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED;
    }

    private boolean hasAudioPermission() {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED;
    }

    private String timestampName(String prefix) {
        return prefix + "-" + new SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(new Date());
    }

    private void status(String message) {
        statusText.setText(message);
    }

    private void toast(String message) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
    }
}
