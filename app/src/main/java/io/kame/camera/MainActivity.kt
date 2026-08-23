package io.kame.camera

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.graphics.Color
import android.hardware.camera2.CaptureRequest
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.camera2.interop.Camera2Interop
import androidx.camera.camera2.interop.ExperimentalCamera2Interop
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.FallbackStrategy
import androidx.camera.video.MediaStoreOutputOptions
import androidx.camera.video.PendingRecording
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.video.VideoRecordEvent
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.Date
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.roundToInt

class MainActivity : ComponentActivity() {
    private lateinit var previewView: PreviewView
    private lateinit var statusText: TextView
    private lateinit var zoomText: TextView
    private lateinit var exposureText: TextView
    private lateinit var captureButton: Button
    private lateinit var recordButton: Button
    private lateinit var flashButton: Button
    private lateinit var switchButton: Button
    private lateinit var zoomSeek: SeekBar
    private lateinit var exposureSeek: SeekBar

    private lateinit var cameraExecutor: ExecutorService

    private var imageCapture: ImageCapture? = null
    private var videoCapture: VideoCapture<Recorder>? = null
    private var camera: Camera? = null
    private var recording: Recording? = null

    private var lensFacing = CameraSelector.LENS_FACING_BACK
    private var torchEnabled = false

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { result ->
        val cameraGranted = result[Manifest.permission.CAMERA] == true
        if (cameraGranted) {
            startCamera()
        } else {
            toast("Permissão da câmera é obrigatória para usar o Kame Camera.")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        cameraExecutor = Executors.newSingleThreadExecutor()
        buildUi()

        if (hasCameraPermission()) {
            startCamera()
        } else {
            permissionLauncher.launch(requiredPermissions())
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        recording?.stop()
        cameraExecutor.shutdown()
    }

    private fun buildUi() {
        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.BLACK)
        }

        previewView = PreviewView(this).apply {
            implementationMode = PreviewView.ImplementationMode.PERFORMANCE
            scaleType = PreviewView.ScaleType.FILL_CENTER
        }
        root.addView(previewView, FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)

        statusText = TextView(this).apply {
            text = "Kame Camera • qualidade automática máxima"
            setTextColor(Color.WHITE)
            textSize = 14f
            setShadowLayer(4f, 0f, 2f, Color.BLACK)
            setPadding(24, 28, 24, 12)
        }
        root.addView(
            statusText,
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.TOP)
        )

        val proPanel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(18, 8, 18, 8)
            setBackgroundColor(0x66000000)
        }
        zoomText = panelLabel("Zoom: automático")
        zoomSeek = SeekBar(this).apply {
            max = 100
            progress = 0
            setOnSeekBarChangeListener(object : SimpleSeekBarChangeListener() {
                override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                    if (fromUser) applyZoom(progress)
                }
            })
        }
        exposureText = panelLabel("Exposição: automática")
        exposureSeek = SeekBar(this).apply {
            max = 0
            progress = 0
            setOnSeekBarChangeListener(object : SimpleSeekBarChangeListener() {
                override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                    if (fromUser) applyExposure(progress)
                }
            })
        }
        proPanel.addView(zoomText)
        proPanel.addView(zoomSeek)
        proPanel.addView(exposureText)
        proPanel.addView(exposureSeek)

        val controls = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(18, 12, 18, 28)
            setBackgroundColor(0x44000000)
        }
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }

        flashButton = cameraButton("Flash") { toggleTorch() }
        switchButton = cameraButton("Virar") { switchCamera() }
        captureButton = cameraButton("Foto") { takePhoto() }
        recordButton = cameraButton("Gravar") { toggleRecording() }

        row.addView(flashButton)
        row.addView(switchButton)
        row.addView(captureButton)
        row.addView(recordButton)
        controls.addView(proPanel)
        controls.addView(row)

        root.addView(
            controls,
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM)
        )

        setContentView(root)
    }

    private fun panelLabel(textValue: String) = TextView(this).apply {
        text = textValue
        setTextColor(Color.WHITE)
        textSize = 12f
        setShadowLayer(3f, 0f, 1f, Color.BLACK)
    }

    private fun cameraButton(label: String, action: () -> Unit): Button = Button(this).apply {
        text = label
        setTextColor(Color.WHITE)
        setBackgroundColor(0xAA102030.toInt())
        setOnClickListener { action() }
        val size = resources.displayMetrics.density
        minWidth = (74 * size).roundToInt()
        minHeight = (48 * size).roundToInt()
    }

    @OptIn(ExperimentalCamera2Interop::class)
    private fun startCamera() {
        val providerFuture = ProcessCameraProvider.getInstance(this)
        providerFuture.addListener({
            val provider = providerFuture.get()
            val cameraSelector = CameraSelector.Builder()
                .requireLensFacing(lensFacing)
                .build()

            val preview = Preview.Builder().applyHighQualityCamera2Options().build().also {
                it.setSurfaceProvider(previewView.surfaceProvider)
            }

            imageCapture = ImageCapture.Builder()
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
                .setJpegQuality(100)
                .applyHighQualityCamera2Options()
                .build()

            val qualitySelector = QualitySelector.fromOrderedList(
                listOf(Quality.UHD, Quality.FHD, Quality.HD, Quality.SD),
                FallbackStrategy.lowerQualityOrHigherThan(Quality.FHD)
            )
            val recorder = Recorder.Builder()
                .setQualitySelector(qualitySelector)
                .build()
            videoCapture = VideoCapture.withOutput(recorder)

            try {
                provider.unbindAll()
                camera = provider.bindToLifecycle(this, cameraSelector, preview, imageCapture, videoCapture)
                torchEnabled = false
                updateCameraControls()
                status("Câmera pronta • foto JPEG 100% • vídeo em maior qualidade suportada")
            } catch (exc: Exception) {
                status("Erro ao iniciar câmera: ${exc.message}")
                toast("Falha ao abrir câmera neste modo.")
            }
        }, ContextCompat.getMainExecutor(this))
    }

    @OptIn(ExperimentalCamera2Interop::class)
    private fun Preview.Builder.applyHighQualityCamera2Options(): Preview.Builder {
        Camera2Interop.Extender(this).apply {
            setCaptureRequestOption(
                CaptureRequest.CONTROL_CAPTURE_INTENT,
                CaptureRequest.CONTROL_CAPTURE_INTENT_PREVIEW
            )
            setCaptureRequestOption(
                CaptureRequest.NOISE_REDUCTION_MODE,
                CaptureRequest.NOISE_REDUCTION_MODE_HIGH_QUALITY
            )
            setCaptureRequestOption(
                CaptureRequest.COLOR_CORRECTION_MODE,
                CaptureRequest.COLOR_CORRECTION_MODE_HIGH_QUALITY
            )
            setCaptureRequestOption(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_HIGH_QUALITY)
        }
        return this
    }

    @OptIn(ExperimentalCamera2Interop::class)
    private fun ImageCapture.Builder.applyHighQualityCamera2Options(): ImageCapture.Builder {
        Camera2Interop.Extender(this).apply {
            setCaptureRequestOption(
                CaptureRequest.CONTROL_CAPTURE_INTENT,
                CaptureRequest.CONTROL_CAPTURE_INTENT_STILL_CAPTURE
            )
            setCaptureRequestOption(CaptureRequest.EDGE_MODE, CaptureRequest.EDGE_MODE_HIGH_QUALITY)
            setCaptureRequestOption(
                CaptureRequest.NOISE_REDUCTION_MODE,
                CaptureRequest.NOISE_REDUCTION_MODE_HIGH_QUALITY
            )
            setCaptureRequestOption(
                CaptureRequest.COLOR_CORRECTION_MODE,
                CaptureRequest.COLOR_CORRECTION_MODE_HIGH_QUALITY
            )
            setCaptureRequestOption(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_HIGH_QUALITY)
        }
        return this
    }

    private fun updateCameraControls() {
        val currentCamera = camera ?: return
        val zoomState = currentCamera.cameraInfo.zoomState.value
        val maxZoom = zoomState?.maxZoomRatio ?: 1f
        zoomSeek.progress = 0
        zoomText.text = "Zoom: 1.0x até ${"%.1f".format(maxZoom)}x"

        val exposureState = currentCamera.cameraInfo.exposureState
        val range = exposureState.exposureCompensationRange
        if (exposureState.isExposureCompensationSupported && range.upper >= range.lower) {
            exposureSeek.max = range.upper - range.lower
            exposureSeek.progress = exposureState.exposureCompensationIndex - range.lower
            exposureSeek.isEnabled = true
            exposureText.text = "Exposição: ${exposureState.exposureCompensationIndex} EV steps"
        } else {
            exposureSeek.max = 0
            exposureSeek.progress = 0
            exposureSeek.isEnabled = false
            exposureText.text = "Exposição: não suportada neste sensor"
        }
        flashButton.text = if (torchEnabled) "Flash ON" else "Flash"
    }

    private fun applyZoom(progress: Int) {
        val currentCamera = camera ?: return
        val zoomState = currentCamera.cameraInfo.zoomState.value ?: return
        val minZoom = zoomState.minZoomRatio
        val maxZoom = zoomState.maxZoomRatio
        val ratio = minZoom + ((maxZoom - minZoom) * progress / 100f)
        currentCamera.cameraControl.setZoomRatio(ratio)
        zoomText.text = "Zoom: ${"%.1f".format(ratio)}x"
    }

    private fun applyExposure(progress: Int) {
        val currentCamera = camera ?: return
        val exposureState = currentCamera.cameraInfo.exposureState
        val range = exposureState.exposureCompensationRange
        if (!exposureState.isExposureCompensationSupported || range.upper < range.lower) return
        val index = range.lower + progress
        currentCamera.cameraControl.setExposureCompensationIndex(index)
        exposureText.text = "Exposição: $index EV steps"
    }

    private fun takePhoto() {
        val capture = imageCapture ?: return
        captureButton.isEnabled = false
        val name = timestampName("IMG")
        val contentValues = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.MediaColumns.RELATIVE_PATH, "Pictures/Kame Camera")
            }
        }
        val outputOptions = ImageCapture.OutputFileOptions.Builder(
            contentResolver,
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            contentValues
        ).build()

        capture.takePicture(
            outputOptions,
            ContextCompat.getMainExecutor(this),
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
                    captureButton.isEnabled = true
                    status("Foto salva com qualidade máxima: $name")
                    toast("Foto salva na galeria")
                }

                override fun onError(exception: ImageCaptureException) {
                    captureButton.isEnabled = true
                    status("Erro na foto: ${exception.message}")
                    toast("Não foi possível salvar a foto")
                }
            }
        )
    }

    private fun toggleRecording() {
        val activeRecording = recording
        if (activeRecording != null) {
            activeRecording.stop()
            recording = null
            recordButton.text = "Gravar"
            return
        }

        val capture = videoCapture ?: return
        val name = timestampName("VID")
        val contentValues = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, "video/mp4")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/Kame Camera")
            }
        }
        val outputOptions = MediaStoreOutputOptions.Builder(
            contentResolver,
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        ).setContentValues(contentValues).build()

        var pending: PendingRecording = capture.output.prepareRecording(this, outputOptions)
        if (hasAudioPermission()) {
            pending = pending.withAudioEnabled()
        }
        recording = pending.start(ContextCompat.getMainExecutor(this)) { event ->
            when (event) {
                is VideoRecordEvent.Start -> {
                    recordButton.text = "Parar"
                    status("Gravando vídeo em qualidade automática máxima...")
                }
                is VideoRecordEvent.Finalize -> {
                    recording = null
                    recordButton.text = "Gravar"
                    if (!event.hasError()) {
                        status("Vídeo salvo: $name")
                        toast("Vídeo salvo na galeria")
                    } else {
                        status("Erro no vídeo: ${event.error}")
                        toast("Falha ao salvar vídeo")
                    }
                }
            }
        }
    }

    private fun switchCamera() {
        if (recording != null) {
            toast("Pare a gravação antes de trocar a câmera.")
            return
        }
        lensFacing = if (lensFacing == CameraSelector.LENS_FACING_BACK) {
            CameraSelector.LENS_FACING_FRONT
        } else {
            CameraSelector.LENS_FACING_BACK
        }
        startCamera()
    }

    private fun toggleTorch() {
        val currentCamera = camera ?: return
        if (!currentCamera.cameraInfo.hasFlashUnit()) {
            toast("Flash não disponível nesta câmera.")
            return
        }
        torchEnabled = !torchEnabled
        currentCamera.cameraControl.enableTorch(torchEnabled)
        flashButton.text = if (torchEnabled) "Flash ON" else "Flash"
    }

    private fun requiredPermissions(): Array<String> = arrayOf(
        Manifest.permission.CAMERA,
        Manifest.permission.RECORD_AUDIO
    )

    private fun hasCameraPermission(): Boolean = ContextCompat.checkSelfPermission(
        this,
        Manifest.permission.CAMERA
    ) == PackageManager.PERMISSION_GRANTED

    private fun hasAudioPermission(): Boolean = ContextCompat.checkSelfPermission(
        this,
        Manifest.permission.RECORD_AUDIO
    ) == PackageManager.PERMISSION_GRANTED

    private fun timestampName(prefix: String): String = "$prefix-${SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())}"

    private fun status(message: String) {
        statusText.text = message
    }

    private fun toast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    }
}

private abstract class SimpleSeekBarChangeListener : SeekBar.OnSeekBarChangeListener {
    override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) = Unit
    override fun onStartTrackingTouch(seekBar: SeekBar?) = Unit
    override fun onStopTrackingTouch(seekBar: SeekBar?) = Unit
}
