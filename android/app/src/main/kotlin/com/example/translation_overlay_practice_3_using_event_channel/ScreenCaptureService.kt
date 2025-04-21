package com.example.translation_overlay_practice_3_using_event_channel

import android.app.Service
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Notification
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.IBinder
import android.os.Build
import android.util.Base64
import android.util.Log
import io.flutter.plugin.common.EventChannel
import java.io.ByteArrayOutputStream
import androidx.core.app.NotificationCompat

class ScreenCaptureService : Service() {
    private var mediaProjection: MediaProjection? = null
    private var imageReader: ImageReader? = null
    private val CHANNEL_ID = "screen_capture_service"
    //private var eventSink: EventChannel.EventSink? = null

    companion object {
        private var eventSink: EventChannel.EventSink? = null
        fun setEventSink(sink: EventChannel.EventSink?) {
            eventSink = sink
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(1, getNotification())  // Make sure this is called AFTER creating the channel
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Start as a foreground service
        //startForeground(1, getNotification())
        val mediaProjectionManager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val resultCode = intent?.getIntExtra("resultCode", Activity.RESULT_CANCELED) ?: Activity.RESULT_CANCELED
        val data: Intent? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent?.getParcelableExtra("data", Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent?.getParcelableExtra("data")
        }

        if (resultCode == Activity.RESULT_OK && data != null) {
            mediaProjection = mediaProjectionManager.getMediaProjection(resultCode, data)
            startScreenCapture()
        }

        return START_STICKY
    }

    private fun startScreenCapture() {
        // val width = 720
        // val height = 1280
        // val dpi = 320
        // ✅ Get WindowManager to retrieve screen dimensions dynamically
        val windowManager = getSystemService(WINDOW_SERVICE) as android.view.WindowManager

        // ✅ Handle different methods for getting screen size based on Android version
        val width: Int
        val height: Int

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // ✅ For Android 11+ (API 30+), use currentWindowMetrics
            val metrics = windowManager.currentWindowMetrics
            val bounds = metrics.bounds
            width = bounds.width()
            height = bounds.height()
        } else {
            // ✅ For Android < 11, use deprecated method with DisplayMetrics
            val displayMetrics = android.util.DisplayMetrics()
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getRealMetrics(displayMetrics)
            width = displayMetrics.widthPixels
            height = displayMetrics.heightPixels
        }

        // ✅ Dynamically fetch screen DPI instead of hardcoding
        val dpi = resources.displayMetrics.densityDpi


        imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
        mediaProjection?.createVirtualDisplay(
            "ScreenCapture",
            width,
            height,
            dpi,
            // DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_PRESENTATION,
            imageReader?.surface,
            null,
            null
        )

        imageReader?.setOnImageAvailableListener({ reader ->
            val image = reader.acquireLatestImage() ?: return@setOnImageAvailableListener
            val planes = image.planes
            val buffer = planes[0].buffer
            val pixelStride = planes[0].pixelStride
            val rowStride = planes[0].rowStride
            val rowPadding = rowStride - pixelStride * width

            val bitmap = Bitmap.createBitmap(
                width + rowPadding / pixelStride,
                height,
                Bitmap.Config.ARGB_8888
            )
            bitmap.copyPixelsFromBuffer(buffer)
            image.close()

            val outputStream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
            val byteArray = outputStream.toByteArray()
            val base64Image = Base64.encodeToString(byteArray, Base64.DEFAULT)

            eventSink?.success(base64Image)
        }, null)
    }

    override fun onDestroy() {
        super.onDestroy()
        mediaProjection?.stop()
        mediaProjection = null
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Screen Capture Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            if (manager != null) {
                manager.createNotificationChannel(channel)
            } else {
                throw RuntimeException("NotificationManager is null")
            }
        }
    }

    private fun getNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Screen Capture Running")
            .setContentText("Your screen is being shared.")
            .setSmallIcon(android.R.drawable.ic_menu_camera)  // Make sure you have this icon in res/mipmap
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
