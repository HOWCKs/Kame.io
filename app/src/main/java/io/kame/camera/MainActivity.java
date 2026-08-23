package io.kame.camera;

import android.Manifest;
import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.hardware.Camera;
import android.media.CamcorderProfile;
import android.media.MediaRecorder;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.ParcelFileDescriptor;
import android.provider.MediaStore;
import android.view.Gravity;
import android.view.SurfaceHolder;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.view.SurfaceView;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.HorizontalScrollView;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import java.io.OutputStream;
import java.text.SimpleDateFormat;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.List;
import java.util.Locale;

@SuppressWarnings("deprecation")
public class MainActivity extends Activity implements SurfaceHolder.Callback {
    private static final int REQUEST_PERMISSIONS = 10;

    private SurfaceView surfaceView;
    private TextView statusText;
    private Button photoModeButton;
    private Button videoModeButton;
    private Button switchButton;
    private Button flashButton;
    private Button zoomInButton;
    private Button zoomOutButton;
    private Button exposureDownButton;
    private Button focusButton;
    private Button exposureUpButton;

    private Camera camera;
    private SurfaceHolder surfaceHolder;
    private MediaRecorder mediaRecorder;
    private ParcelFileDescriptor videoFileDescriptor;
    private Uri currentVideoUri;

    private int cameraId = 0;
    private boolean surfaceReady = false;
    private boolean recording = false;
    private boolean torchEnabled = false;
    private boolean videoMode = false;
    private int zoomValue = 0;
    private int exposureValue = 0;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        enableImmersiveMode();
        cameraId = findBackCameraId();
        buildUi();
        if (hasRequiredPermissions()) {
            openCameraWhenReady();
        } else {
            requestPermissions(new String[]{Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO}, REQUEST_PERMISSIONS);
        }
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (recording) stopVideo();
        releaseCamera();
    }

    @Override
    protected void onResume() {
        super.onResume();
        enableImmersiveMode();
        if (hasRequiredPermissions()) openCameraWhenReady();
    }


    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) enableImmersiveMode();
    }

    private void enableImmersiveMode() {
        Window window = getWindow();
        window.setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN);
        View decorView = window.getDecorView();
        decorView.setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        | View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        );
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQUEST_PERMISSIONS && hasRequiredPermissions()) {
            openCameraWhenReady();
        } else {
            toast("Permissões de câmera e microfone são necessárias.");
        }
    }

    @Override
    public void surfaceCreated(SurfaceHolder holder) {
        surfaceReady = true;
        surfaceHolder = holder;
        openCameraWhenReady();
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        startPreview();
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        surfaceReady = false;
    }

    private void buildUi() {
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);

        surfaceView = new SurfaceView(this);
        surfaceView.setClickable(true);
        surfaceView.setOnClickListener(view -> triggerAutoFocus());
        surfaceHolder = surfaceView.getHolder();
        surfaceHolder.addCallback(this);
        root.addView(surfaceView, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
        ));

        statusText = new TextView(this);
        statusText.setText("Kame Camera • qualidade alta nativa");
        statusText.setTextColor(Color.WHITE);
        statusText.setTextSize(14f);
        statusText.setPadding(24, 30, 24, 12);
        statusText.setShadowLayer(4f, 0f, 2f, Color.BLACK);
        root.addView(statusText, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.TOP
        ));

        FrameLayout controls = new FrameLayout(this);
        controls.setPadding(dp(8), dp(7), dp(8), dp(7));
        controls.setBackground(makeCapsuleBackground());
        controls.setElevation(dp(16));
        controls.setTranslationZ(dp(10));

        HorizontalScrollView scrollView = new HorizontalScrollView(this);
        scrollView.setHorizontalScrollBarEnabled(false);
        scrollView.setOverScrollMode(HorizontalScrollView.OVER_SCROLL_NEVER);
        LinearLayout actionsRow = new LinearLayout(this);
        actionsRow.setOrientation(LinearLayout.HORIZONTAL);
        actionsRow.setGravity(Gravity.CENTER_VERTICAL);
        actionsRow.setPadding(dp(8), 0, dp(8), 0);

        photoModeButton = capsuleActionButton("FOTO", () -> {
            setVideoMode(false);
            takePhoto();
        });
        videoModeButton = capsuleActionButton("VÍDEO", () -> {
            setVideoMode(true);
            toggleVideo();
        });
        switchButton = capsuleActionButton("VIRAR", this::switchCamera);
        flashButton = capsuleActionButton("FLASH", this::toggleFlash);
        zoomOutButton = capsuleActionButton("ZOOM -", () -> changeZoom(-1));
        zoomInButton = capsuleActionButton("ZOOM +", () -> changeZoom(1));
        exposureDownButton = capsuleActionButton("EV -", () -> changeExposure(-1));
        focusButton = capsuleActionButton("FOCO", this::triggerAutoFocus);
        exposureUpButton = capsuleActionButton("EV +", () -> changeExposure(1));

        actionsRow.addView(photoModeButton);
        actionsRow.addView(videoModeButton);
        actionsRow.addView(switchButton);
        actionsRow.addView(flashButton);
        actionsRow.addView(zoomOutButton);
        actionsRow.addView(zoomInButton);
        actionsRow.addView(exposureDownButton);
        actionsRow.addView(focusButton);
        actionsRow.addView(exposureUpButton);
        scrollView.addView(actionsRow, new HorizontalScrollView.LayoutParams(
                HorizontalScrollView.LayoutParams.WRAP_CONTENT,
                HorizontalScrollView.LayoutParams.WRAP_CONTENT
        ));

        FrameLayout.LayoutParams scrollParams = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER
        );
        controls.addView(scrollView, scrollParams);

        setVideoMode(false);

        FrameLayout.LayoutParams controlsParams = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                dp(62),
                Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL
        );
        controlsParams.leftMargin = dp(18);
        controlsParams.rightMargin = dp(18);
        controlsParams.bottomMargin = dp(12);
        root.addView(controls, controlsParams);

        setContentView(root);
    }

    private Button capsuleActionButton(String label, Runnable action) {
        Button button = new Button(this);
        button.setText(label);
        button.setTextColor(Color.WHITE);
        button.setTextSize(12f);
        button.setTypeface(Typeface.DEFAULT_BOLD);
        button.setAllCaps(false);
        button.setMinWidth(dp(74));
        button.setMinHeight(dp(42));
        button.setPadding(dp(10), 0, dp(10), 0);
        button.setBackground(makeButtonBackground(false));
        button.setElevation(dp(3));
        button.setTranslationZ(dp(1));
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, dp(42));
        params.leftMargin = dp(3);
        params.rightMargin = dp(3);
        button.setLayoutParams(params);
        button.setOnClickListener(view -> action.run());
        return button;
    }

    private void setVideoMode(boolean enabled) {
        videoMode = enabled;
        if (photoModeButton != null) photoModeButton.setBackground(makeButtonBackground(!enabled));
        if (videoModeButton != null) videoModeButton.setBackground(makeButtonBackground(enabled));
        status(enabled ? "Modo vídeo • toque em VÍDEO para iniciar/parar" : "Modo foto • toque em FOTO para fotografar");
    }

    private GradientDrawable makeCapsuleBackground() {
        GradientDrawable drawable = new GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{0x882F3842, 0x66101820}
        );
        drawable.setCornerRadius(dp(38));
        drawable.setStroke(dp(1), 0x77FFFFFF);
        return drawable;
    }

    private GradientDrawable makeButtonBackground(boolean selected) {
        int top = selected ? 0xAA2E8CFF : 0x553A4652;
        int bottom = selected ? 0xAA0051B8 : 0x44202B35;
        GradientDrawable drawable = new GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{top, bottom}
        );
        drawable.setCornerRadius(dp(22));
        drawable.setStroke(dp(1), selected ? 0xBBFFFFFF : 0x55FFFFFF);
        return drawable;
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private void openCameraWhenReady() {
        if (!surfaceReady || !hasRequiredPermissions() || camera != null) return;
        try {
            camera = Camera.open(cameraId);
            camera.setDisplayOrientation(90);
            applyHighQualityParameters(false);
            startPreview();
            status("Câmera pronta • JPEG 100% • maior resolução disponível");
        } catch (Exception error) {
            status("Erro ao abrir câmera: " + error.getMessage());
        }
    }

    private void startPreview() {
        if (camera == null || surfaceHolder == null) return;
        try {
            camera.stopPreview();
        } catch (Exception ignored) {
        }
        try {
            camera.setPreviewDisplay(surfaceHolder);
            camera.startPreview();
        } catch (Exception error) {
            status("Erro no preview: " + error.getMessage());
        }
    }

    private void applyHighQualityParameters(boolean videoMode) {
        if (camera == null) return;
        try {
            Camera.Parameters parameters = camera.getParameters();
            parameters.setJpegQuality(100);

            List<Camera.Size> pictureSizes = parameters.getSupportedPictureSizes();
            if (pictureSizes != null && !pictureSizes.isEmpty()) {
                Camera.Size best = Collections.max(pictureSizes, Comparator.comparingInt(size -> size.width * size.height));
                parameters.setPictureSize(best.width, best.height);
            }

            List<String> focusModes = parameters.getSupportedFocusModes();
            if (focusModes != null) {
                if (videoMode && focusModes.contains(Camera.Parameters.FOCUS_MODE_CONTINUOUS_VIDEO)) {
                    parameters.setFocusMode(Camera.Parameters.FOCUS_MODE_CONTINUOUS_VIDEO);
                } else if (focusModes.contains(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE)) {
                    parameters.setFocusMode(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE);
                } else if (focusModes.contains(Camera.Parameters.FOCUS_MODE_AUTO)) {
                    parameters.setFocusMode(Camera.Parameters.FOCUS_MODE_AUTO);
                }
            }

            if (parameters.isZoomSupported()) {
                zoomValue = Math.max(0, Math.min(zoomValue, parameters.getMaxZoom()));
                parameters.setZoom(zoomValue);
            }

            int minExposure = parameters.getMinExposureCompensation();
            int maxExposure = parameters.getMaxExposureCompensation();
            if (minExposure != 0 || maxExposure != 0) {
                exposureValue = Math.max(minExposure, Math.min(maxExposure, exposureValue));
                parameters.setExposureCompensation(exposureValue);
            }

            List<String> flashModes = parameters.getSupportedFlashModes();
            if (flashModes != null && flashModes.contains(Camera.Parameters.FLASH_MODE_TORCH)) {
                parameters.setFlashMode(torchEnabled ? Camera.Parameters.FLASH_MODE_TORCH : Camera.Parameters.FLASH_MODE_OFF);
            }

            camera.setParameters(parameters);
        } catch (Exception ignored) {
            // Alguns sensores recusam parte dos parâmetros. Mantemos a câmera funcionando.
        }
    }

    private void takePhoto() {
        if (camera == null || recording) return;
        try {
            applyHighQualityParameters(false);
            camera.takePicture(null, null, (data, cam) -> {
                savePhoto(data);
                try {
                    cam.startPreview();
                } catch (Exception ignored) {
                }
            });
        } catch (Exception error) {
            status("Erro ao fotografar: " + error.getMessage());
        }
    }

    private void savePhoto(byte[] data) {
        String name = timestampName("IMG") + ".jpg";
        ContentValues values = new ContentValues();
        values.put(MediaStore.MediaColumns.DISPLAY_NAME, name);
        values.put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg");
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.put(MediaStore.MediaColumns.RELATIVE_PATH, "Pictures/Kame Camera");
        }

        try {
            Uri uri = getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
            if (uri == null) throw new IllegalStateException("MediaStore sem URI");
            try (OutputStream output = getContentResolver().openOutputStream(uri)) {
                if (output == null) throw new IllegalStateException("Sem saída para arquivo");
                output.write(data);
            }
            status("Foto salva: " + name);
            toast("Foto salva na galeria");
        } catch (Exception error) {
            status("Erro ao salvar foto: " + error.getMessage());
        }
    }

    private void toggleVideo() {
        if (recording) stopVideo(); else startVideo();
    }

    private void startVideo() {
        if (camera == null) return;
        try {
            applyHighQualityParameters(true);
            camera.unlock();

            mediaRecorder = new MediaRecorder();
            mediaRecorder.setCamera(camera);
            mediaRecorder.setAudioSource(MediaRecorder.AudioSource.CAMCORDER);
            mediaRecorder.setVideoSource(MediaRecorder.VideoSource.CAMERA);

            CamcorderProfile profile = getBestProfile();
            mediaRecorder.setProfile(profile);
            mediaRecorder.setOrientationHint(isFrontCamera(cameraId) ? 270 : 90);

            currentVideoUri = createVideoUri();
            videoFileDescriptor = getContentResolver().openFileDescriptor(currentVideoUri, "w");
            if (videoFileDescriptor == null) throw new IllegalStateException("Sem arquivo de vídeo");
            mediaRecorder.setOutputFile(videoFileDescriptor.getFileDescriptor());
            mediaRecorder.setPreviewDisplay(surfaceHolder.getSurface());
            mediaRecorder.prepare();
            mediaRecorder.start();

            recording = true;
            if (videoModeButton != null) videoModeButton.setText("PARAR");
            status("Gravando vídeo em perfil alto...");
        } catch (Exception error) {
            if (videoModeButton != null) videoModeButton.setText("VÍDEO");
            cleanupRecorder();
            reconnectCameraAfterRecording();
            status("Erro ao gravar: " + error.getMessage());
        }
    }

    private void stopVideo() {
        try {
            if (mediaRecorder != null) mediaRecorder.stop();
            status("Vídeo salvo na galeria");
            toast("Vídeo salvo");
        } catch (Exception error) {
            status("Gravação finalizada com aviso: " + error.getMessage());
        } finally {
            recording = false;
            if (videoModeButton != null) videoModeButton.setText("VÍDEO");
            cleanupRecorder();
            reconnectCameraAfterRecording();
        }
    }

    private void cleanupRecorder() {
        try {
            if (mediaRecorder != null) {
                mediaRecorder.reset();
                mediaRecorder.release();
            }
        } catch (Exception ignored) {
        }
        mediaRecorder = null;
        try {
            if (videoFileDescriptor != null) videoFileDescriptor.close();
        } catch (Exception ignored) {
        }
        videoFileDescriptor = null;
        currentVideoUri = null;
    }

    private void reconnectCameraAfterRecording() {
        try {
            if (camera != null) camera.lock();
        } catch (Exception ignored) {
        }
        startPreview();
    }

    private Uri createVideoUri() {
        String name = timestampName("VID") + ".mp4";
        ContentValues values = new ContentValues();
        values.put(MediaStore.MediaColumns.DISPLAY_NAME, name);
        values.put(MediaStore.MediaColumns.MIME_TYPE, "video/mp4");
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/Kame Camera");
        }
        Uri uri = getContentResolver().insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values);
        if (uri == null) throw new IllegalStateException("MediaStore sem URI para vídeo");
        return uri;
    }

    private CamcorderProfile getBestProfile() {
        int[] qualities = new int[]{
                CamcorderProfile.QUALITY_2160P,
                CamcorderProfile.QUALITY_1080P,
                CamcorderProfile.QUALITY_720P,
                CamcorderProfile.QUALITY_HIGH
        };
        for (int quality : qualities) {
            if (CamcorderProfile.hasProfile(cameraId, quality)) {
                return CamcorderProfile.get(cameraId, quality);
            }
        }
        return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_HIGH);
    }

    private void switchCamera() {
        if (recording) {
            toast("Pare a gravação antes de trocar a câmera.");
            return;
        }
        int next = findOtherCameraId();
        if (next == cameraId) {
            toast("Outra câmera não encontrada.");
            return;
        }
        releaseCamera();
        cameraId = next;
        zoomValue = 0;
        exposureValue = 0;
        torchEnabled = false;
        flashButton.setText("Flash");
        openCameraWhenReady();
    }

    private void toggleFlash() {
        if (camera == null) return;
        torchEnabled = !torchEnabled;
        applyHighQualityParameters(false);
        flashButton.setText(torchEnabled ? "Flash ON" : "Flash");
    }

    private void changeZoom(int delta) {
        if (camera == null) return;
        try {
            Camera.Parameters parameters = camera.getParameters();
            if (!parameters.isZoomSupported()) {
                toast("Zoom não suportado neste sensor.");
                return;
            }
            zoomValue = Math.max(0, Math.min(parameters.getMaxZoom(), zoomValue + delta));
            parameters.setZoom(zoomValue);
            camera.setParameters(parameters);
            status("Zoom: passo " + zoomValue + " de " + parameters.getMaxZoom());
        } catch (Exception error) {
            status("Erro no zoom: " + error.getMessage());
        }
    }

    private void changeExposure(int delta) {
        if (camera == null) return;
        try {
            Camera.Parameters parameters = camera.getParameters();
            int min = parameters.getMinExposureCompensation();
            int max = parameters.getMaxExposureCompensation();
            if (min == 0 && max == 0) {
                toast("Exposição manual não suportada neste sensor.");
                return;
            }
            exposureValue = Math.max(min, Math.min(max, exposureValue + delta));
            parameters.setExposureCompensation(exposureValue);
            camera.setParameters(parameters);
            status("Exposição: " + exposureValue + " de " + min + " a " + max);
        } catch (Exception error) {
            status("Erro na exposição: " + error.getMessage());
        }
    }

    private void triggerAutoFocus() {
        if (camera == null || recording) return;
        try {
            Camera.Parameters parameters = camera.getParameters();
            List<String> focusModes = parameters.getSupportedFocusModes();
            if (focusModes != null && focusModes.contains(Camera.Parameters.FOCUS_MODE_AUTO)) {
                parameters.setFocusMode(Camera.Parameters.FOCUS_MODE_AUTO);
                camera.setParameters(parameters);
            }
            camera.cancelAutoFocus();
            camera.autoFocus((success, cam) -> status(success ? "Foco ajustado" : "Foco solicitado"));
        } catch (Exception error) {
            status("Foco indisponível: " + error.getMessage());
        }
    }

    private void releaseCamera() {
        try {
            if (camera != null) {
                camera.stopPreview();
                camera.release();
            }
        } catch (Exception ignored) {
        }
        camera = null;
    }

    private int findBackCameraId() {
        int count = Camera.getNumberOfCameras();
        Camera.CameraInfo info = new Camera.CameraInfo();
        for (int i = 0; i < count; i++) {
            Camera.getCameraInfo(i, info);
            if (info.facing == Camera.CameraInfo.CAMERA_FACING_BACK) return i;
        }
        return 0;
    }

    private int findOtherCameraId() {
        int count = Camera.getNumberOfCameras();
        if (count <= 1) return cameraId;
        return cameraId == 0 ? 1 : 0;
    }

    private boolean isFrontCamera(int id) {
        Camera.CameraInfo info = new Camera.CameraInfo();
        Camera.getCameraInfo(id, info);
        return info.facing == Camera.CameraInfo.CAMERA_FACING_FRONT;
    }

    private boolean hasRequiredPermissions() {
        return checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
                && checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED;
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
