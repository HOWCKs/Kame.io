package io.kame.camera

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.view.Gravity
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.MediaStoreOutputOptions
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.video.VideoRecordEvent
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : ComponentActivity() {
    private lateinit var previewView: PreviewView
    private lateinit var statusText: TextView
    private lateinit var photoButton: Button
    private lateinit var videoButton: Button
    private lateinit var switchButton: Button
    private lateinit var flashButton: Button
    private lateinit var zoomInButton: Button
    private lateinit var zoomOutButton: Button

    private var camera: Camera? = null
    private var imageCapture: ImageCapture? = null
    private var videoCapture: VideoCapture<Recorder>? = null
    private var recording: Recording? = null
    private var lensFacing = CameraSelector.LENS_FACING_BACK
    private var torchEnabled = false
    private var zoomRatio = 1f

    private val permissionsLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { grants ->
        if (grants[Manifest.permission.CAMERA] == true) startCamera()
        else toast("Permissão da câmera é obrigatória.")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        buildUi()
        if (hasPermission(Manifest.permission.CAMERA)) startCamera() else permissionsLauncher.launch(requiredPermissions())
    }

    override fun onDestroy() {
        recording?.stop()
        super.onDestroy()
    }

    private fun buildUi() {
        val root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        previewView = PreviewView(this).apply {
            scaleType = PreviewView.ScaleType.FILL_CENTER
            implementationMode = PreviewView.ImplementationMode.PERFORMANCE
        }
        root.addView(previewView, FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)

        statusText = TextView(this).apply {
            text = "Kame Camera • qualidade automática máxima"
            setTextColor(Color.WHITE)
            textSize = 14f
            setPadding(24, 30, 24, 12)
            setShadowLayer(4f, 0f, 2f, Color.BLACK)
        }
        root.addView(statusText, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.TOP))

        val controls = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(16, 12, 16, 26)
            setBackgroundColor(0x55000000)
        }
        val row1 = LinearLayout(this).apply { gravity = Gravity.CENTER }
        val row2 = LinearLayout(this).apply { gravity = Gravity.CENTER }

        photoButton = cameraButton("Foto") { takePhoto() }
        videoButton = cameraButton("Gravar") { toggleVideo() }
        switchButton = cameraButton("Virar") { switchCamera() }
        flashButton = cameraButton("Flash") { toggleFlash() }
        zoomOutButton = cameraButton("Zoom -") { changeZoom(-0.25f) }
        zoomInButton = cameraButton("Zoom +") { changeZoom(0.25f) }

        row1.addView(photoButton)
        row1.addView(videoButton)
        row1.addView(switchButton)
        row2.addView(flashButton)
        row2.addView(zoomOutButton)
        row2.addView(zoomInButton)
        controls.addView(row1)
        controls.addView(row2)
        root.addView(controls, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM))
        setContentView(root)
    }

    private fun cameraButton(label: String, action: () -> Unit): Button = Button(this).apply {
        text = label
        setTextColor(Color.WHITE)
        setBackgroundColor(0xAA102030.toInt())
        setOnClickListener { action() }
    }

    private fun startCamera() {
        val providerFuture = ProcessCameraProvider.getInstance(this)
        providerFuture.addListener({
            val provider = providerFuture.get()
            val selector = CameraSelector.Builder().requireLensFacing(lensFacing).build()

            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(previewView.surfaceProvider)
            }
            imageCapture = ImageCapture.Builder()
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
                .setJpegQuality(100)
                .build()
            val recorder = Recorder.Builder()
                .setQualitySelector(QualitySelector.from(Quality.HIGHEST))
                .build()
            videoCapture = VideoCapture.withOutput(recorder)

            try {
                provider.unbindAll()
                camera = provider.bindToLifecycle(this, selector, preview, imageCapture, videoCapture)
                torchEnabled = false
                zoomRatio = 1f
                status("Câmera pronta • foto máxima • vídeo na melhor qualidade suportada")
            } catch (error: Exception) {
                status("Erro ao abrir câmera: ${error.message}")
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun takePhoto() {
        val capture = imageCapture ?: return
        val name = timestampName("IMG")
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) put(MediaStore.MediaColumns.RELATIVE_PATH, "Pictures/Kame Camera")
        }
        val options = ImageCapture.OutputFileOptions.Builder(contentResolver, MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values).build()
        capture.takePicture(options, ContextCompat.getMainExecutor(this), object : ImageCapture.OnImageSavedCallback {
            override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
                status("Foto salva: $name")
                toast("Foto salva na galeria")
            }

            override fun onError(exception: ImageCaptureException) {
                status("Erro ao salvar foto: ${exception.message}")
            }
        })
    }

    private fun toggleVideo() {
        val active = recording
        if (active != null) {
            active.stop()
            recording = null
            videoButton.text = "Gravar"
            return
        }

        val capture = videoCapture ?: return
        val name = timestampName("VID")
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, "video/mp4")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/Kame Camera")
        }
        val options = MediaStoreOutputOptions.Builder(contentResolver, MediaStore.Video.Media.EXTERNAL_CONTENT_URI)
            .setContentValues(values)
            .build()

        var pending = capture.output.prepareRecording(this, options)
        if (hasPermission(Manifest.permission.RECORD_AUDIO)) pending = pending.withAudioEnabled()
        recording = pending.start(ContextCompat.getMainExecutor(this)) { event ->
            when (event) {
                is VideoRecordEvent.Start -> {
                    videoButton.text = "Parar"
                    status("Gravando vídeo...")
                }
                is VideoRecordEvent.Finalize -> {
                    recording = null
                    videoButton.text = "Gravar"
                    if (event.hasError()) status("Erro no vídeo: ${event.error}") else status("Vídeo salvo: $name")
                }
            }
        }
    }

    private fun switchCamera() {
        if (recording != null) {
            toast("Pare a gravação antes de trocar a câmera.")
            return
        }
        lensFacing = if (lensFacing == CameraSelector.LENS_FACING_BACK) CameraSelector.LENS_FACING_FRONT else CameraSelector.LENS_FACING_BACK
        startCamera()
    }

    private fun toggleFlash() {
        val current = camera ?: return
        if (!current.cameraInfo.hasFlashUnit()) {
            toast("Flash indisponível nesta câmera.")
            return
        }
        torchEnabled = !torchEnabled
        current.cameraControl.enableTorch(torchEnabled)
        flashButton.text = if (torchEnabled) "Flash ON" else "Flash"
    }

    private fun changeZoom(delta: Float) {
        val current = camera ?: return
        val state = current.cameraInfo.zoomState.value ?: return
        zoomRatio = (zoomRatio + delta).coerceIn(state.minZoomRatio, state.maxZoomRatio)
        current.cameraControl.setZoomRatio(zoomRatio)
        status("Zoom: ${String.format(Locale.US, "%.1f", zoomRatio)}x")
    }

    private fun requiredPermissions(): Array<String> = arrayOf(Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO)

    private fun hasPermission(permission: String): Boolean = ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED

    private fun timestampName(prefix: String): String = "$prefix-${SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())}"

    private fun status(message: String) {
        statusText.text = message
    }

    private fun toast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    }
}
