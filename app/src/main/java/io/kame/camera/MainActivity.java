package io.kame.camera;

import android.Manifest;
import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.res.ColorStateList;
import android.content.res.Configuration;
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
import android.os.Handler;
import android.os.Looper;
import android.provider.MediaStore;
import android.view.Gravity;
import android.view.HapticFeedbackConstants;
import android.view.MotionEvent;
import android.view.ScaleGestureDetector;
import android.view.SurfaceHolder;
import android.view.Surface;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.view.SurfaceView;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.HorizontalScrollView;
import android.widget.LinearLayout;
import android.widget.SeekBar;
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
    private TextView analogLeftText;
    private TextView analogCenterText;
    private TextView analogRightText;
    private TextView dataStripText;
    private Button shutterButton;
    private Button videoModeButton;
    private Button switchButton;
    private Button flashButton;
    private Button exposureDownButton;
    private Button focusButton;
    private Button exposureUpButton;
    private Button settingsButton;
    private SeekBar zoomSlider;
    private Button qualitySettingButton;
    private Button bitrateSettingButton;
    private Button fpsSettingButton;
    private Button stabilizationSettingButton;
    private FrameLayout settingsPanel;

    private Camera camera;
    private SurfaceHolder surfaceHolder;
    private MediaRecorder mediaRecorder;
    private ParcelFileDescriptor videoFileDescriptor;
    private Uri currentVideoUri;

    private int cameraId = 0;
    private boolean surfaceReady = false;
    private boolean recording = false;
    private boolean photoInProgress = false;
    private boolean torchEnabled = false;
    private boolean videoMode = false;
    private int zoomValue = 0;
    private int exposureValue = 0;
    private float touchStartX = 0f;
    private float touchStartY = 0f;
    private boolean gestureConsumed = false;
    private long lastPinchAtMs = 0L;
    private ScaleGestureDetector scaleGestureDetector;
    private final Handler uiHandler = new Handler(Looper.getMainLooper());
    private final Runnable hideZoomSliderRunnable = () -> {
        if (zoomSlider != null) zoomSlider.setVisibility(View.GONE);
    };
    private int videoQualityMode = 0;
    private int fpsMode = 0;
    private boolean boostedBitrate = false;
    private boolean videoStabilizationEnabled = true;

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
        root.setClipChildren(false);
        root.setClipToPadding(false);

        surfaceView = new SurfaceView(this);
        surfaceView.setClickable(true);
        scaleGestureDetector = new ScaleGestureDetector(this, new ScaleGestureDetector.SimpleOnScaleGestureListener() {
            @Override
            public boolean onScale(ScaleGestureDetector detector) {
                gestureConsumed = true;
                lastPinchAtMs = System.currentTimeMillis();
                showZoomSlider();
                if (detector.getScaleFactor() > 1.03f) {
                    changeZoom(1);
                } else if (detector.getScaleFactor() < 0.97f) {
                    changeZoom(-1);
                }
                return true;
            }
        });
        surfaceView.setOnTouchListener(this::handleSurfaceTouch);
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
        statusText.setVisibility(View.GONE);
        root.addView(statusText, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.TOP
        ));

        zoomSlider = new SeekBar(this);
        zoomSlider.setMax(100);
        zoomSlider.setProgress(0);
        zoomSlider.setVisibility(View.GONE);
        zoomSlider.setPadding(dp(28), 0, dp(28), 0);
        tintZoomSlider();
        zoomSlider.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                if (fromUser) setZoomFromSlider(progress);
            }

            @Override
            public void onStartTrackingTouch(SeekBar seekBar) {
                uiHandler.removeCallbacks(hideZoomSliderRunnable);
            }

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {
                scheduleHideZoomSlider();
            }
        });
        FrameLayout.LayoutParams zoomParams = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                dp(46),
                Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL
        );
        zoomParams.leftMargin = dp(28);
        zoomParams.rightMargin = dp(28);
        zoomParams.bottomMargin = dp(92);
        root.addView(zoomSlider, zoomParams);

        FrameLayout controls = new FrameLayout(this);
        controls.setClipChildren(false);
        controls.setClipToPadding(false);
        controls.setPadding(dp(8), dp(8), dp(8), dp(8));
        controls.setBackground(makeCapsuleBackground());
        controls.setElevation(dp(20));
        controls.setTranslationZ(dp(12));

        HorizontalScrollView scrollView = new HorizontalScrollView(this);
        scrollView.setHorizontalScrollBarEnabled(false);
        scrollView.setOverScrollMode(HorizontalScrollView.OVER_SCROLL_NEVER);
        LinearLayout actionsRow = new LinearLayout(this);
        actionsRow.setOrientation(LinearLayout.HORIZONTAL);
        actionsRow.setGravity(Gravity.CENTER_VERTICAL);
        actionsRow.setPadding(dp(10), 0, dp(10), 0);

        shutterButton = capsuleActionButton("FOTO", () -> {
            setVideoMode(false);
            takePhoto();
        });
        videoModeButton = capsuleActionButton("VÍDEO", () -> {
            setVideoMode(true);
            toggleVideo();
        });
        switchButton = capsuleActionButton("VIRAR", this::switchCamera);
        flashButton = capsuleActionButton("FLASH", this::toggleFlash);
        exposureDownButton = capsuleActionButton("EV -", () -> changeExposure(-1));
        focusButton = capsuleActionButton("FOCO", this::triggerAutoFocus);
        exposureUpButton = capsuleActionButton("EV +", () -> changeExposure(1));
        settingsButton = capsuleActionButton("⚙", this::openVideoSettings);

        actionsRow.addView(shutterButton);
        actionsRow.addView(videoModeButton);
        actionsRow.addView(switchButton);
        actionsRow.addView(flashButton);
        actionsRow.addView(exposureDownButton);
        actionsRow.addView(focusButton);
        actionsRow.addView(exposureUpButton);
        actionsRow.addView(settingsButton);
        scrollView.addView(actionsRow, new HorizontalScrollView.LayoutParams(
                HorizontalScrollView.LayoutParams.WRAP_CONTENT,
                HorizontalScrollView.LayoutParams.WRAP_CONTENT
        ));

        FrameLayout.LayoutParams scrollParams = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER
        );
        scrollParams.leftMargin = dp(8);
        scrollParams.rightMargin = dp(8);
        controls.addView(scrollView, scrollParams);

        setVideoMode(false);

        FrameLayout.LayoutParams controlsParams = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                dp(64),
                Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL
        );
        controlsParams.leftMargin = dp(8);
        controlsParams.rightMargin = dp(8);
        controlsParams.bottomMargin = dp(8);
        root.addView(controls, controlsParams);


        settingsPanel = buildVideoSettingsPanel();
        root.addView(settingsPanel, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
        ));

        setContentView(root);
    }

    private boolean handleSurfaceTouch(View view, MotionEvent event) {
        if (scaleGestureDetector != null) scaleGestureDetector.onTouchEvent(event);
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
                touchStartX = event.getX();
                touchStartY = event.getY();
                gestureConsumed = event.getPointerCount() > 1;
                return true;
            case MotionEvent.ACTION_POINTER_DOWN:
            case MotionEvent.ACTION_MOVE:
                if (event.getPointerCount() > 1) {
                    gestureConsumed = true;
                    lastPinchAtMs = System.currentTimeMillis();
                }
                return true;
            case MotionEvent.ACTION_UP:
                float dx = Math.abs(event.getX() - touchStartX);
                float dy = Math.abs(event.getY() - touchStartY);
                boolean recentPinch = System.currentTimeMillis() - lastPinchAtMs < 650;
                if (!gestureConsumed && !recentPinch && dx < dp(18) && dy < dp(18)) {
                    triggerAutoFocus();
                }
                gestureConsumed = false;
                return true;
            case MotionEvent.ACTION_CANCEL:
                gestureConsumed = false;
                return true;
            default:
                return true;
        }
    }

    private Button capsuleActionButton(String label, Runnable action) {
        Button button = new Button(this);
        button.setText(label);
        button.setTextColor(0xFFB7C6C2);
        button.setTextSize(12.2f);
        button.setTypeface(Typeface.create("sans-serif", Typeface.BOLD));
        button.setAllCaps(false);
        button.setLetterSpacing(0.02f);
        button.setMinWidth(dp(80));
        button.setMinHeight(dp(48));
        button.setPadding(dp(12), 0, dp(12), dp(1));
        button.setBackground(makeButtonBackground(false));
        button.setElevation(dp(5));
        button.setTranslationZ(dp(2));
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, dp(48));
        params.leftMargin = dp(2);
        params.rightMargin = dp(2);
        button.setLayoutParams(params);
        button.setOnClickListener(view -> {
            tactileClick(view);
            action.run();
        });
        return button;
    }

    private void setVideoMode(boolean enabled) {
        videoMode = enabled;
        applyPhotoButtonState(!enabled);
        applyModeButtonState(videoModeButton, enabled);
        status(enabled ? "Modo vídeo" : "Modo foto");
        updateAnalogInterface();
    }

    private void applyPhotoButtonState(boolean selected) {
        if (shutterButton == null) return;
        shutterButton.setTextColor(selected ? Color.WHITE : 0xFFB7C6C2);
        shutterButton.setBackground(selected ? makePrimaryButtonBackground() : makeButtonBackground(false));
        shutterButton.setElevation(selected ? dp(12) : dp(5));
        shutterButton.setTranslationZ(selected ? dp(7) : dp(2));
        shutterButton.setScaleX(selected ? 1.035f : 1f);
        shutterButton.setScaleY(selected ? 1.035f : 1f);
    }

    private void applyModeButtonState(Button button, boolean selected) {
        if (button == null) return;
        button.setTextColor(selected ? Color.WHITE : 0xFFB7C6C2);
        button.setBackground(makeButtonBackground(selected));
        button.setElevation(selected ? dp(14) : dp(5));
        button.setTranslationZ(selected ? dp(8) : dp(2));
        button.setScaleX(selected ? 1.045f : 1f);
        button.setScaleY(selected ? 1.045f : 1f);
    }

    private FrameLayout buildVideoSettingsPanel() {
        FrameLayout overlay = new FrameLayout(this);
        overlay.setBackgroundColor(0x99171E19);
        overlay.setVisibility(View.GONE);
        overlay.setOnClickListener(view -> closeVideoSettings());

        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setPadding(dp(20), dp(18), dp(20), dp(18));
        card.setBackground(makeSettingsCardBackground());
        card.setElevation(dp(18));
        card.setTranslationZ(dp(12));
        card.setOnClickListener(view -> { });

        TextView title = new TextView(this);
        title.setText("Configurações de vídeo");
        title.setTextColor(0xFF171E19);
        title.setTextSize(20f);
        title.setTypeface(Typeface.create("sans-serif-black", Typeface.BOLD));
        title.setLetterSpacing(0.015f);
        title.setGravity(Gravity.CENTER);
        title.setPadding(0, 0, 0, dp(12));
        card.addView(title, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
        ));

        qualitySettingButton = settingsOptionButton("", this::cycleVideoQuality);
        bitrateSettingButton = settingsOptionButton("", this::toggleBoostedBitrate);
        fpsSettingButton = settingsOptionButton("", this::cycleFpsMode);
        stabilizationSettingButton = settingsOptionButton("", this::toggleVideoStabilization);
        Button closeButton = settingsOptionButton("FECHAR", this::closeVideoSettings);
        card.addView(qualitySettingButton);
        card.addView(bitrateSettingButton);
        card.addView(fpsSettingButton);
        card.addView(stabilizationSettingButton);
        card.addView(closeButton);
        updateVideoSettingsLabels();

        FrameLayout.LayoutParams cardParams = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL
        );
        cardParams.leftMargin = dp(22);
        cardParams.rightMargin = dp(22);
        cardParams.bottomMargin = dp(96);
        overlay.addView(card, cardParams);
        return overlay;
    }

    private Button settingsOptionButton(String label, Runnable action) {
        Button button = new Button(this);
        button.setText(label);
        button.setTextColor(0xFF171E19);
        button.setTextSize(14f);
        button.setTypeface(Typeface.create("sans-serif", Typeface.BOLD));
        button.setAllCaps(false);
        button.setLetterSpacing(0.015f);
        button.setPadding(dp(12), 0, dp(12), 0);
        button.setBackground(makeButtonBackground(false));
        button.setOnClickListener(view -> {
            tactileClick(view);
            action.run();
        });
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(48)
        );
        params.topMargin = dp(8);
        button.setLayoutParams(params);
        return button;
    }

    private void openVideoSettings() {
        updateVideoSettingsLabels();
        if (settingsPanel != null) settingsPanel.setVisibility(View.VISIBLE);
    }

    private void closeVideoSettings() {
        if (settingsPanel != null) settingsPanel.setVisibility(View.GONE);
        enableImmersiveMode();
    }

    private void cycleVideoQuality() {
        videoQualityMode = (videoQualityMode + 1) % 4;
        updateVideoSettingsLabels();
    }

    private void toggleBoostedBitrate() {
        boostedBitrate = !boostedBitrate;
        updateVideoSettingsLabels();
    }

    private void cycleFpsMode() {
        fpsMode = (fpsMode + 1) % 3;
        updateVideoSettingsLabels();
    }

    private void toggleVideoStabilization() {
        videoStabilizationEnabled = !videoStabilizationEnabled;
        updateVideoSettingsLabels();
    }

    private void updateVideoSettingsLabels() {
        if (qualitySettingButton != null) qualitySettingButton.setText("Qualidade: " + videoQualityLabel());
        if (bitrateSettingButton != null) bitrateSettingButton.setText("Bitrate: " + (boostedBitrate ? "REFORÇADO (teste)" : "NORMAL"));
        if (fpsSettingButton != null) fpsSettingButton.setText("FPS: " + fpsLabel() + " (seguro)");
        if (stabilizationSettingButton != null) stabilizationSettingButton.setText("Estabilização: " + (videoStabilizationEnabled ? "ON" : "OFF"));
        updateAnalogInterface();
    }

    private String videoQualityLabel() {
        switch (videoQualityMode) {
            case 1: return "4K se suportado";
            case 2: return "Full HD 1080p";
            case 3: return "HD 720p";
            default: return "Automática máxima";
        }
    }

    private String fpsLabel() {
        switch (fpsMode) {
            case 1: return "30";
            case 2: return "60 se suportado";
            default: return "Automático";
        }
    }

    private int selectedFps() {
        switch (fpsMode) {
            case 1: return 30;
            case 2: return 60;
            default: return 0;
        }
    }

    private View buildAnalogDashboard() {
        LinearLayout dashboard = new LinearLayout(this);
        dashboard.setOrientation(LinearLayout.HORIZONTAL);
        dashboard.setGravity(Gravity.CENTER);
        dashboard.setPadding(dp(14), dp(10), dp(14), dp(10));
        dashboard.setBackground(makeDashboardBackground());
        dashboard.setElevation(dp(18));
        dashboard.setTranslationZ(dp(10));

        analogLeftText = dashboardText("∞      5\n 3      1\n.7   .4m", 13f, false);
        analogLeftText.setGravity(Gravity.CENTER);
        analogCenterText = dashboardText("AF      ◷ 5s\nAUTO  EV\n+2 +1  0  -1 -2", 12f, true);
        analogCenterText.setGravity(Gravity.CENTER);
        analogCenterText.setBackground(makeSmallPillBackground());
        analogRightText = dashboardText("2.8   4\n5.6   8\n11   16", 13f, false);
        analogRightText.setGravity(Gravity.CENTER);

        dashboard.addView(analogLeftText, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f));
        LinearLayout.LayoutParams centerParams = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1.25f);
        centerParams.leftMargin = dp(8);
        centerParams.rightMargin = dp(8);
        dashboard.addView(analogCenterText, centerParams);
        dashboard.addView(analogRightText, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f));
        updateAnalogInterface();
        return dashboard;
    }

    private void updateAnalogInterface() {
        // Interface analógica removida para manter a câmera limpa.
    }

    private String currentZoomLabel() {
        try {
            if (camera != null) {
                Camera.Parameters parameters = camera.getParameters();
                List<Integer> ratios = parameters.getZoomRatios();
                if (ratios != null && zoomValue >= 0 && zoomValue < ratios.size()) {
                    return String.format(Locale.US, "%.1fx", ratios.get(zoomValue) / 100f);
                }
            }
        } catch (Exception ignored) {
        }
        return "Z" + zoomValue;
    }

    private String shortQualityLabel() {
        switch (videoQualityMode) {
            case 1: return "4K";
            case 2: return "FHD";
            case 3: return "HD";
            default: return "HI";
        }
    }

    private TextView dashboardText(String text, float size, boolean strong) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextColor(strong ? Color.WHITE : 0xFFB7C6C2);
        view.setTextSize(size);
        view.setTypeface(Typeface.MONOSPACE, strong ? Typeface.BOLD : Typeface.NORMAL);
        view.setIncludeFontPadding(false);
        view.setShadowLayer(3f, 0f, 1f, 0xCC000000);
        return view;
    }

    private View buildFocusReticle() {
        TextView reticle = new TextView(this);
        reticle.setText("—   ▭   —");
        reticle.setTextColor(0xDDB7C6C2);
        reticle.setTextSize(34f);
        reticle.setGravity(Gravity.CENTER);
        reticle.setTypeface(Typeface.DEFAULT_BOLD);
        reticle.setShadowLayer(8f, 0f, 2f, 0xAA000000);
        reticle.setAlpha(0.82f);
        return reticle;
    }

    private GradientDrawable makeFloatingPanelBackground() {
        GradientDrawable drawable = new GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                new int[]{0xF8EEEBE3, 0xF7FFFFFF, 0xF0EEEBE3}
        );
        drawable.setCornerRadius(dp(40));
        drawable.setStroke(dp(1), 0x55B7C6C2);
        return drawable;
    }

    private GradientDrawable makeSettingsCardBackground() {
        return makeFloatingPanelBackground();
    }

    private GradientDrawable makeDashboardBackground() {
        GradientDrawable drawable = new GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                new int[]{0xF0171E19, 0xE8171E19, 0xF0202822}
        );
        drawable.setCornerRadius(dp(40));
        drawable.setStroke(dp(1), 0x44B7C6C2);
        return drawable;
    }

    private GradientDrawable makeSmallPillBackground() {
        GradientDrawable drawable = new GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                new int[]{0x33FFFFFF, 0x18B7C6C2}
        );
        drawable.setCornerRadius(dp(24));
        drawable.setStroke(dp(1), 0x44B7C6C2);
        return drawable;
    }

    private GradientDrawable makeCapsuleBackground() {
        GradientDrawable drawable = new GradientDrawable(
                GradientDrawable.Orientation.LEFT_RIGHT,
                new int[]{0xF0171E19, 0xEA171E19, 0xF01D2520}
        );
        drawable.setCornerRadius(dp(40));
        drawable.setStroke(dp(1), 0x44B7C6C2);
        return drawable;
    }

    private GradientDrawable makeButtonBackground(boolean selected) {
        GradientDrawable drawable;
        if (selected) {
            drawable = new GradientDrawable(
                    GradientDrawable.Orientation.LEFT_RIGHT,
                    new int[]{0xFF171E19, 0xFF222B25}
            );
            drawable.setStroke(dp(1), 0x66B7C6C2);
        } else {
            drawable = new GradientDrawable(
                    GradientDrawable.Orientation.TOP_BOTTOM,
                    new int[]{0x20FFFFFF, 0x08FFFFFF}
            );
            drawable.setStroke(dp(1), 0x33B7C6C2);
        }
        drawable.setCornerRadius(dp(24));
        return drawable;
    }

    private GradientDrawable makePrimaryButtonBackground() {
        GradientDrawable drawable = new GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                new int[]{0xFFCA0013, 0xFFE0182A}
        );
        drawable.setCornerRadius(dp(24));
        drawable.setStroke(dp(1), 0x66EEEBE3);
        return drawable;
    }

    private GradientDrawable makeRecordingButtonBackground() {
        GradientDrawable drawable = new GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                new int[]{0xFFCA0013, 0xFF8F000D}
        );
        drawable.setCornerRadius(dp(24));
        drawable.setStroke(dp(1), 0x66EEEBE3);
        return drawable;
    }

    private boolean isDarkMode() {
        return (getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK)
                == Configuration.UI_MODE_NIGHT_YES;
    }

    private void tactileClick(View view) {
        view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY);
        view.animate().scaleX(0.96f).scaleY(0.96f).setDuration(70).withEndAction(() ->
                view.animate().scaleX(1f).scaleY(1f).setDuration(90).start()
        ).start();
    }

    private void tintZoomSlider() {
        if (zoomSlider == null) return;
        int progress = 0xFFCA0013;
        int background = 0x55B7C6C2;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            zoomSlider.setProgressTintList(ColorStateList.valueOf(progress));
            zoomSlider.setThumbTintList(ColorStateList.valueOf(progress));
            zoomSlider.setProgressBackgroundTintList(ColorStateList.valueOf(background));
        }
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
            updateAnalogInterface();
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
            if (!videoMode) {
                parameters.setRotation(calculateMediaOrientation());
            }

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

            if (videoMode && parameters.isVideoStabilizationSupported()) {
                parameters.setVideoStabilization(videoStabilizationEnabled);
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
        if (camera == null || recording || photoInProgress) return;
        photoInProgress = true;
        try {
            applyHighQualityParameters(false);
            final boolean[] captured = new boolean[]{false};
            Runnable fallbackCapture = () -> {
                if (!captured[0] && photoInProgress) {
                    captured[0] = true;
                    captureStillPicture();
                }
            };

            try {
                Camera.Parameters parameters = camera.getParameters();
                List<String> focusModes = parameters.getSupportedFocusModes();
                if (focusModes != null && focusModes.contains(Camera.Parameters.FOCUS_MODE_AUTO)) {
                    parameters.setFocusMode(Camera.Parameters.FOCUS_MODE_AUTO);
                    camera.setParameters(parameters);
                }
                camera.cancelAutoFocus();
                camera.autoFocus((success, cam) -> {
                    if (!captured[0]) {
                        captured[0] = true;
                        uiHandler.removeCallbacks(fallbackCapture);
                        captureStillPicture();
                    }
                });
                uiHandler.postDelayed(fallbackCapture, 900);
            } catch (Exception focusError) {
                captured[0] = true;
                captureStillPicture();
            }
        } catch (Exception error) {
            photoInProgress = false;
            status("Erro ao fotografar: " + error.getMessage());
        }
    }

    private void captureStillPicture() {
        try {
            camera.takePicture(null, null, (data, cam) -> {
                savePhoto(data);
                try {
                    cam.startPreview();
                } catch (Exception ignored) {
                }
                photoInProgress = false;
            });
        } catch (Exception error) {
            photoInProgress = false;
            status("Erro ao fotografar: " + error.getMessage());
        }
    }

    private void savePhoto(byte[] data) {
        if (data == null || data.length < 4 || (data[0] & 0xFF) != 0xFF || (data[1] & 0xFF) != 0xD8) {
            status("Foto inválida recebida do sensor");
            toast("Falha ao capturar foto");
            return;
        }

        String name = timestampName("IMG") + ".jpg";
        ContentValues values = new ContentValues();
        values.put(MediaStore.MediaColumns.DISPLAY_NAME, name);
        values.put(MediaStore.MediaColumns.TITLE, name.replace(".jpg", ""));
        values.put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg");
        values.put(MediaStore.MediaColumns.DATE_TAKEN, System.currentTimeMillis());
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.put(MediaStore.MediaColumns.RELATIVE_PATH, "Pictures/Kame Camera");
            values.put(MediaStore.MediaColumns.IS_PENDING, 1);
        }

        Uri uri = null;
        try {
            uri = getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
            if (uri == null) throw new IllegalStateException("MediaStore sem URI");
            try (OutputStream output = getContentResolver().openOutputStream(uri, "w")) {
                if (output == null) throw new IllegalStateException("Sem saída para arquivo");
                output.write(data);
                output.flush();
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ContentValues done = new ContentValues();
                done.put(MediaStore.MediaColumns.IS_PENDING, 0);
                getContentResolver().update(uri, done, null, null);
            }
            status("Foto salva: " + name);
            toast("Foto salva na galeria");
        } catch (Exception error) {
            if (uri != null) {
                try {
                    getContentResolver().delete(uri, null, null);
                } catch (Exception ignored) {
                }
            }
            status("Erro ao salvar foto: " + error.getMessage());
            toast("Erro ao salvar foto");
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
            // Mantemos bitrate e FPS no perfil nativo para evitar arquivos quebrados em aparelhos
            // que rejeitam combinações manuais. As opções continuam no menu para evolução gradual.
            mediaRecorder.setOrientationHint(calculateMediaOrientation());

            currentVideoUri = createVideoUri();
            videoFileDescriptor = getContentResolver().openFileDescriptor(currentVideoUri, "w");
            if (videoFileDescriptor == null) throw new IllegalStateException("Sem arquivo de vídeo");
            mediaRecorder.setOutputFile(videoFileDescriptor.getFileDescriptor());
            mediaRecorder.setPreviewDisplay(surfaceHolder.getSurface());
            mediaRecorder.prepare();
            mediaRecorder.start();

            recording = true;
            if (videoModeButton != null) {
                videoModeButton.setText("PARAR");
                videoModeButton.setTextColor(Color.WHITE);
                videoModeButton.setBackground(makeRecordingButtonBackground());
                videoModeButton.setElevation(dp(10));
            }
            status("Gravando vídeo em perfil alto...");
            updateAnalogInterface();
        } catch (Exception error) {
            if (videoModeButton != null) {
                videoModeButton.setText("VÍDEO");
                applyModeButtonState(videoModeButton, videoMode);
            }
            updateAnalogInterface();
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
            if (videoModeButton != null) {
                videoModeButton.setText("VÍDEO");
                applyModeButtonState(videoModeButton, videoMode);
            }
            updateAnalogInterface();
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
        values.put(MediaStore.MediaColumns.TITLE, name.replace(".mp4", ""));
        values.put(MediaStore.MediaColumns.MIME_TYPE, "video/mp4");
        values.put(MediaStore.MediaColumns.DATE_TAKEN, System.currentTimeMillis());
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/Kame Camera");
        }
        Uri uri = getContentResolver().insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values);
        if (uri == null) throw new IllegalStateException("MediaStore sem URI para vídeo");
        return uri;
    }

    private CamcorderProfile getBestProfile() {
        int[] qualities;
        switch (videoQualityMode) {
            case 1:
                qualities = new int[]{CamcorderProfile.QUALITY_2160P, CamcorderProfile.QUALITY_1080P, CamcorderProfile.QUALITY_HIGH};
                break;
            case 2:
                qualities = new int[]{CamcorderProfile.QUALITY_1080P, CamcorderProfile.QUALITY_720P, CamcorderProfile.QUALITY_HIGH};
                break;
            case 3:
                qualities = new int[]{CamcorderProfile.QUALITY_720P, CamcorderProfile.QUALITY_HIGH};
                break;
            default:
                qualities = new int[]{CamcorderProfile.QUALITY_2160P, CamcorderProfile.QUALITY_1080P, CamcorderProfile.QUALITY_720P, CamcorderProfile.QUALITY_HIGH};
                break;
        }
        for (int quality : qualities) {
            if (CamcorderProfile.hasProfile(cameraId, quality)) {
                return CamcorderProfile.get(cameraId, quality);
            }
        }
        return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_HIGH);
    }

    private int calculateMediaOrientation() {
        Camera.CameraInfo info = new Camera.CameraInfo();
        Camera.getCameraInfo(cameraId, info);
        int rotation = getWindowManager().getDefaultDisplay().getRotation();
        int degrees;
        switch (rotation) {
            case Surface.ROTATION_90:
                degrees = 90;
                break;
            case Surface.ROTATION_180:
                degrees = 180;
                break;
            case Surface.ROTATION_270:
                degrees = 270;
                break;
            case Surface.ROTATION_0:
            default:
                degrees = 0;
                break;
        }
        if (info.facing == Camera.CameraInfo.CAMERA_FACING_FRONT) {
            int result = (info.orientation + degrees) % 360;
            return (360 - result) % 360;
        }
        return (info.orientation - degrees + 360) % 360;
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
        flashButton.setText("FLASH");
        updateAnalogInterface();
        openCameraWhenReady();
    }

    private void toggleFlash() {
        if (camera == null) return;
        torchEnabled = !torchEnabled;
        applyHighQualityParameters(false);
        flashButton.setText(torchEnabled ? "FLASH ON" : "FLASH");
        updateAnalogInterface();
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
            updateZoomSlider(parameters);
            status("Zoom: passo " + zoomValue + " de " + parameters.getMaxZoom());
            updateAnalogInterface();
        } catch (Exception error) {
            status("Erro no zoom: " + error.getMessage());
        }
    }

    private void setZoomFromSlider(int progress) {
        if (camera == null) return;
        try {
            Camera.Parameters parameters = camera.getParameters();
            if (!parameters.isZoomSupported()) return;
            int max = parameters.getMaxZoom();
            zoomValue = Math.max(0, Math.min(max, Math.round(max * (progress / 100f))));
            parameters.setZoom(zoomValue);
            camera.setParameters(parameters);
            updateZoomSlider(parameters);
            scheduleHideZoomSlider();
            updateAnalogInterface();
        } catch (Exception error) {
            status("Erro no zoom: " + error.getMessage());
        }
    }

    private void updateZoomSlider(Camera.Parameters parameters) {
        if (zoomSlider == null || parameters == null || !parameters.isZoomSupported()) return;
        int max = Math.max(1, parameters.getMaxZoom());
        int progress = Math.round((zoomValue * 100f) / max);
        zoomSlider.setProgress(Math.max(0, Math.min(100, progress)));
    }

    private void showZoomSlider() {
        if (zoomSlider != null) {
            zoomSlider.setVisibility(View.VISIBLE);
            uiHandler.removeCallbacks(hideZoomSliderRunnable);
            scheduleHideZoomSlider();
        }
    }

    private void scheduleHideZoomSlider() {
        uiHandler.removeCallbacks(hideZoomSliderRunnable);
        uiHandler.postDelayed(hideZoomSliderRunnable, 1800);
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
            updateAnalogInterface();
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
            camera.autoFocus((success, cam) -> {
                status(success ? "Foco ajustado" : "Foco solicitado");
                updateAnalogInterface();
            });
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
