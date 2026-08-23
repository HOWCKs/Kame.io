package io.kame.camera;

import android.Manifest;
import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.res.ColorStateList;
import android.content.res.Configuration;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.ColorMatrix;
import android.graphics.ColorMatrixColorFilter;
import android.graphics.Paint;
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

import java.io.ByteArrayOutputStream;
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
    private Button filterButton;
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
    private FrameLayout filterPanel;
    private SeekBar filterIntensitySlider;

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
    private final Runnable hideFilterPanelRunnable = () -> {
        if (filterPanel != null) filterPanel.setVisibility(View.GONE);
    };
    private int videoQualityMode = 0;
    private int fpsMode = 0;
    private boolean boostedBitrate = false;
    private boolean videoStabilizationEnabled = true;
    private int selectedFilter = 0;
    private int filterIntensity = 100;
    private final String[] filterNames = new String[]{"Natural", "Cinema", "Vivo", "Quente", "Frio", "Mono", "Comida", "Retrato", "HDR", "Drama", "Noir"};

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
        zoomParams.bottomMargin = dp(82);
        root.addView(zoomSlider, zoomParams);

        FrameLayout controls = new FrameLayout(this);
        controls.setPadding(dp(8), dp(6), dp(8), dp(6));
        controls.setBackground(makeCapsuleBackground());
        controls.setElevation(dp(22));
        controls.setTranslationZ(dp(14));

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
        filterButton = capsuleActionButton("FILTRO", this::openFilterPanel);
        exposureDownButton = capsuleActionButton("EV -", () -> changeExposure(-1));
        focusButton = capsuleActionButton("FOCO", this::triggerAutoFocus);
        exposureUpButton = capsuleActionButton("EV +", () -> changeExposure(1));
        settingsButton = capsuleActionButton("⚙", this::openVideoSettings);

        actionsRow.addView(photoModeButton);
        actionsRow.addView(videoModeButton);
        actionsRow.addView(switchButton);
        actionsRow.addView(flashButton);
        actionsRow.addView(filterButton);
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
        controls.addView(scrollView, scrollParams);

        setVideoMode(false);

        FrameLayout.LayoutParams controlsParams = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                dp(60),
                Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL
        );
        controlsParams.leftMargin = dp(18);
        controlsParams.rightMargin = dp(18);
        controlsParams.bottomMargin = dp(14);
        root.addView(controls, controlsParams);

        filterPanel = buildFilterPanel();
        root.addView(filterPanel, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
        ));

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
                    takePhoto();
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
        button.setTextColor(isDarkMode() ? Color.WHITE : 0xFF111111);
        button.setTextSize(12f);
        button.setTypeface(Typeface.DEFAULT_BOLD);
        button.setAllCaps(false);
        button.setMinWidth(dp(78));
        button.setMinHeight(dp(42));
        button.setPadding(dp(10), 0, dp(10), 0);
        button.setBackground(makeButtonBackground(false));
        button.setElevation(dp(3));
        button.setTranslationZ(dp(1));
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, dp(42));
        params.leftMargin = dp(3);
        params.rightMargin = dp(3);
        button.setLayoutParams(params);
        button.setOnClickListener(view -> {
            tactileClick(view);
            action.run();
        });
        return button;
    }

    private void setVideoMode(boolean enabled) {
        videoMode = enabled;
        applyModeButtonState(photoModeButton, !enabled);
        applyModeButtonState(videoModeButton, enabled);
        status(enabled ? "Modo vídeo" : "Modo foto");
    }

    private void applyModeButtonState(Button button, boolean selected) {
        if (button == null) return;
        if (isDarkMode()) {
            button.setTextColor(selected ? Color.WHITE : 0xFFEDEDED);
        } else {
            button.setTextColor(selected ? 0xFF050510 : 0xFF181818);
        }
        button.setBackground(makeButtonBackground(selected));
        button.setElevation(selected ? dp(12) : dp(3));
        button.setTranslationZ(selected ? dp(7) : dp(1));
        button.setScaleX(selected ? 1.05f : 1f);
        button.setScaleY(selected ? 1.05f : 1f);
    }

    private FrameLayout buildFilterPanel() {
        FrameLayout overlay = new FrameLayout(this);
        overlay.setVisibility(View.GONE);
        overlay.setOnClickListener(view -> closeFilterPanel());

        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setPadding(dp(14), dp(12), dp(14), dp(12));
        card.setBackground(makeFloatingPanelBackground());
        card.setElevation(dp(18));
        card.setTranslationZ(dp(12));
        card.setOnClickListener(view -> scheduleHideFilterPanel());

        TextView title = new TextView(this);
        title.setText("Filtros");
        title.setTextColor(isDarkMode() ? Color.WHITE : 0xFF111111);
        title.setTextSize(16f);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        title.setGravity(Gravity.CENTER);
        title.setPadding(0, 0, 0, dp(8));
        card.addView(title, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
        ));

        HorizontalScrollView filtersScroll = new HorizontalScrollView(this);
        filtersScroll.setHorizontalScrollBarEnabled(false);
        filtersScroll.setOverScrollMode(HorizontalScrollView.OVER_SCROLL_NEVER);
        LinearLayout filterRow = new LinearLayout(this);
        filterRow.setOrientation(LinearLayout.HORIZONTAL);
        filterRow.setGravity(Gravity.CENTER_VERTICAL);
        for (int i = 0; i < filterNames.length; i++) {
            final int index = i;
            Button option = capsuleActionButton(filterNames[i].toUpperCase(Locale.US), () -> {
                selectedFilter = index;
                if (filterButton != null) filterButton.setText(index == 0 ? "FILTRO" : filterNames[index].toUpperCase(Locale.US));
                scheduleHideFilterPanel();
            });
            filterRow.addView(option);
        }
        filtersScroll.addView(filterRow, new HorizontalScrollView.LayoutParams(
                HorizontalScrollView.LayoutParams.WRAP_CONTENT,
                HorizontalScrollView.LayoutParams.WRAP_CONTENT
        ));
        card.addView(filtersScroll, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(48)
        ));

        TextView intensityLabel = new TextView(this);
        intensityLabel.setText("Intensidade");
        intensityLabel.setTextColor(isDarkMode() ? Color.WHITE : 0xFF111111);
        intensityLabel.setTextSize(13f);
        intensityLabel.setGravity(Gravity.CENTER);
        intensityLabel.setPadding(0, dp(10), 0, 0);
        card.addView(intensityLabel);

        filterIntensitySlider = new SeekBar(this);
        filterIntensitySlider.setMax(100);
        filterIntensitySlider.setProgress(filterIntensity);
        filterIntensitySlider.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                filterIntensity = progress;
                if (fromUser) scheduleHideFilterPanel();
            }

            @Override
            public void onStartTrackingTouch(SeekBar seekBar) {
                uiHandler.removeCallbacks(hideFilterPanelRunnable);
            }

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {
                scheduleHideFilterPanel();
            }
        });
        card.addView(filterIntensitySlider, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(42)
        ));

        LinearLayout bottom = new LinearLayout(this);
        bottom.setGravity(Gravity.CENTER);
        Button ok = settingsOptionButton("OK", this::closeFilterPanel);
        Button back = settingsOptionButton("VOLTAR", this::closeFilterPanel);
        bottom.addView(back, new LinearLayout.LayoutParams(0, dp(46), 1f));
        bottom.addView(ok, new LinearLayout.LayoutParams(0, dp(46), 1f));
        card.addView(bottom);

        FrameLayout.LayoutParams cardParams = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL
        );
        cardParams.leftMargin = dp(18);
        cardParams.rightMargin = dp(18);
        cardParams.bottomMargin = dp(88);
        overlay.addView(card, cardParams);
        return overlay;
    }

    private void openFilterPanel() {
        if (filterPanel != null) filterPanel.setVisibility(View.VISIBLE);
        scheduleHideFilterPanel();
    }

    private void closeFilterPanel() {
        uiHandler.removeCallbacks(hideFilterPanelRunnable);
        if (filterPanel != null) filterPanel.setVisibility(View.GONE);
        enableImmersiveMode();
    }

    private void scheduleHideFilterPanel() {
        uiHandler.removeCallbacks(hideFilterPanelRunnable);
        uiHandler.postDelayed(hideFilterPanelRunnable, 10000);
    }

    private FrameLayout buildVideoSettingsPanel() {
        FrameLayout overlay = new FrameLayout(this);
        overlay.setBackgroundColor(0x99000000);
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
        title.setTextColor(isDarkMode() ? Color.WHITE : 0xFF111111);
        title.setTextSize(18f);
        title.setTypeface(Typeface.DEFAULT_BOLD);
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
        button.setTextColor(isDarkMode() ? Color.WHITE : 0xFF111111);
        button.setTextSize(14f);
        button.setTypeface(Typeface.DEFAULT_BOLD);
        button.setAllCaps(false);
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

    private GradientDrawable makeFloatingPanelBackground() {
        GradientDrawable drawable;
        if (isDarkMode()) {
            drawable = new GradientDrawable(
                    GradientDrawable.Orientation.TOP_BOTTOM,
                    new int[]{0xEE202020, 0xEE101010}
            );
            drawable.setStroke(dp(1), 0x12FFFFFF);
        } else {
            drawable = new GradientDrawable(
                    GradientDrawable.Orientation.TOP_BOTTOM,
                    new int[]{0xF2FFFFFF, 0xEDEFEFEF}
            );
            drawable.setStroke(dp(1), 0x44FFFFFF);
        }
        drawable.setCornerRadius(dp(30));
        return drawable;
    }

    private GradientDrawable makeSettingsCardBackground() {
        GradientDrawable drawable;
        if (isDarkMode()) {
            drawable = new GradientDrawable(
                    GradientDrawable.Orientation.TOP_BOTTOM,
                    new int[]{0xF0202020, 0xF0101010}
            );
            drawable.setStroke(dp(1), 0x12FFFFFF);
        } else {
            drawable = new GradientDrawable(
                    GradientDrawable.Orientation.TOP_BOTTOM,
                    new int[]{0xF2FFFFFF, 0xEDEFEFEF}
            );
            drawable.setStroke(dp(1), 0x44FFFFFF);
        }
        drawable.setCornerRadius(dp(30));
        return drawable;
    }

    private GradientDrawable makeCapsuleBackground() {
        GradientDrawable drawable;
        if (isDarkMode()) {
            drawable = new GradientDrawable(
                    GradientDrawable.Orientation.TOP_BOTTOM,
                    new int[]{0xEE202020, 0xDD101010}
            );
            drawable.setStroke(dp(1), 0x12FFFFFF);
        } else {
            drawable = new GradientDrawable(
                    GradientDrawable.Orientation.TOP_BOTTOM,
                    new int[]{0xF2FFFFFF, 0xDDEFEFEF}
            );
            drawable.setStroke(dp(1), 0x55FFFFFF);
        }
        drawable.setCornerRadius(dp(30));
        return drawable;
    }

    private GradientDrawable makeButtonBackground(boolean selected) {
        int top;
        int bottom;
        int stroke;
        if (isDarkMode()) {
            top = selected ? 0xFF3A3A3A : 0x22333333;
            bottom = selected ? 0xFF202020 : 0x16101010;
            stroke = selected ? 0x26FFFFFF : 0x08FFFFFF;
        } else {
            top = selected ? 0xFFE8E8E8 : 0x20FFFFFF;
            bottom = selected ? 0xFFD6D6D6 : 0x10FFFFFF;
            stroke = selected ? 0xFFFFFFFF : 0x22FFFFFF;
        }
        GradientDrawable drawable = new GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{top, bottom}
        );
        drawable.setCornerRadius(dp(24));
        drawable.setStroke(dp(1), stroke);
        return drawable;
    }

    private GradientDrawable makeRecordingButtonBackground() {
        GradientDrawable drawable = new GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{0xEEFF4B4B, 0xEEB00020}
        );
        drawable.setCornerRadius(dp(24));
        drawable.setStroke(dp(1), 0x44FF6B6B);
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
        int progress = isDarkMode() ? 0xFFEDEDED : 0xFF222222;
        int background = isDarkMode() ? 0x44FFFFFF : 0x33000000;
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

        byte[] outputData = applySelectedFilter(data);

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
                output.write(outputData);
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

    private byte[] applySelectedFilter(byte[] jpegData) {
        if (selectedFilter == 0 || filterIntensity <= 0) return jpegData;
        Bitmap source = null;
        Bitmap result = null;
        try {
            source = BitmapFactory.decodeByteArray(jpegData, 0, jpegData.length);
            if (source == null) return jpegData;
            result = Bitmap.createBitmap(source.getWidth(), source.getHeight(), Bitmap.Config.ARGB_8888);
            Canvas canvas = new Canvas(result);
            Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
            paint.setColorFilter(new ColorMatrixColorFilter(createFilterMatrix(selectedFilter, filterIntensity / 100f)));
            canvas.drawBitmap(source, 0, 0, paint);
            ByteArrayOutputStream output = new ByteArrayOutputStream(Math.max(jpegData.length, 1024));
            result.compress(Bitmap.CompressFormat.JPEG, 96, output);
            return output.toByteArray();
        } catch (Throwable ignored) {
            return jpegData;
        } finally {
            if (source != null) source.recycle();
            if (result != null) result.recycle();
        }
    }

    private ColorMatrix createFilterMatrix(int filter, float amount) {
        ColorMatrix matrix = new ColorMatrix();
        ColorMatrix effect = new ColorMatrix();
        switch (filter) {
            case 1: // Cinema: contraste forte, sombras levemente frias e pele quente.
                effect.setSaturation(0.72f);
                matrix.postConcat(effect);
                matrix.postConcat(contrastMatrix(1.28f, -8f));
                matrix.postConcat(colorScale(1.14f, 1.03f, 0.88f));
                break;
            case 2: // Vivo: cores fortes e contraste visível.
                effect.setSaturation(1.85f);
                matrix.postConcat(effect);
                matrix.postConcat(contrastMatrix(1.20f, 8f));
                matrix.postConcat(colorScale(1.06f, 1.08f, 1.04f));
                break;
            case 3: // Quente.
                effect.setSaturation(1.18f);
                matrix.postConcat(effect);
                matrix.postConcat(contrastMatrix(1.12f, 5f));
                matrix.postConcat(colorScale(1.30f, 1.10f, 0.78f));
                break;
            case 4: // Frio.
                effect.setSaturation(1.08f);
                matrix.postConcat(effect);
                matrix.postConcat(contrastMatrix(1.10f, 0f));
                matrix.postConcat(colorScale(0.78f, 1.02f, 1.32f));
                break;
            case 5: // Mono.
                effect.setSaturation(0f);
                matrix.postConcat(effect);
                matrix.postConcat(contrastMatrix(1.32f, 4f));
                break;
            case 6: // Comida: quente, saturado, mais claro.
                effect.setSaturation(1.65f);
                matrix.postConcat(effect);
                matrix.postConcat(contrastMatrix(1.18f, 12f));
                matrix.postConcat(colorScale(1.22f, 1.14f, 0.88f));
                break;
            case 7: // Retrato: tons de pele mais quentes e contraste moderado.
                effect.setSaturation(1.20f);
                matrix.postConcat(effect);
                matrix.postConcat(contrastMatrix(1.08f, 10f));
                matrix.postConcat(colorScale(1.14f, 1.06f, 0.96f));
                break;
            case 8: // HDR: contraste e saturação fortes para paisagem.
                effect.setSaturation(1.45f);
                matrix.postConcat(effect);
                matrix.postConcat(contrastMatrix(1.35f, -2f));
                matrix.postConcat(colorScale(1.05f, 1.08f, 1.05f));
                break;
            case 9: // Drama: escuro, cinematográfico e bem diferente.
                effect.setSaturation(0.62f);
                matrix.postConcat(effect);
                matrix.postConcat(contrastMatrix(1.55f, -28f));
                matrix.postConcat(colorScale(1.12f, 0.96f, 0.82f));
                break;
            case 10: // Noir: preto e branco pesado.
                effect.setSaturation(0f);
                matrix.postConcat(effect);
                matrix.postConcat(contrastMatrix(1.65f, -18f));
                break;
            default:
                break;
        }
        if (amount < 0.99f) {
            ColorMatrix identity = new ColorMatrix();
            float[] base = identity.getArray();
            float[] filtered = matrix.getArray();
            float[] mixed = new float[20];
            for (int i = 0; i < 20; i++) {
                mixed[i] = base[i] + ((filtered[i] - base[i]) * amount);
            }
            matrix.set(mixed);
        }
        return matrix;
    }

    private ColorMatrix contrastMatrix(float contrast, float brightness) {
        float translate = (-0.5f * contrast + 0.5f) * 255f + brightness;
        ColorMatrix matrix = new ColorMatrix(new float[]{
                contrast, 0, 0, 0, translate,
                0, contrast, 0, 0, translate,
                0, 0, contrast, 0, translate,
                0, 0, 0, 1, 0
        });
        return matrix;
    }

    private ColorMatrix colorScale(float red, float green, float blue) {
        ColorMatrix matrix = new ColorMatrix();
        matrix.setScale(red, green, blue, 1f);
        return matrix;
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
        } catch (Exception error) {
            if (videoModeButton != null) {
                videoModeButton.setText("VÍDEO");
                applyModeButtonState(videoModeButton, videoMode);
            }
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
        openCameraWhenReady();
    }

    private void toggleFlash() {
        if (camera == null) return;
        torchEnabled = !torchEnabled;
        applyHighQualityParameters(false);
        flashButton.setText(torchEnabled ? "FLASH ON" : "FLASH");
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
