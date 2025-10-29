package com.example.req_demo

import android.graphics.*
import android.os.Bundle
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import ai.onnxruntime.*

// for long microphone detection
import android.view.KeyEvent
import android.os.SystemClock

import java.io.File
import java.nio.FloatBuffer
import java.util.UUID
import kotlin.math.max
import kotlin.math.min
private val COCO_CLASSES = listOf(
    "person", "bicycle", "car", "motorcycle", "airplane", "bus",
    "train", "truck", "boat", "traffic light", "fire hydrant",
    "stop sign", "parking meter", "bench", "bird", "cat", "dog",
    "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe",
    "backpack", "umbrella", "handbag", "tie", "suitcase", "frisbee",
    "skis", "snowboard", "sports ball", "kite", "baseball bat",
    "baseball glove", "skateboard", "surfboard", "tennis racket",
    "bottle", "wine glass", "cup", "fork", "knife", "spoon", "bowl",
    "banana", "apple", "sandwich", "orange", "broccoli", "carrot",
    "hot dog", "pizza", "donut", "cake", "chair", "couch",
    "potted plant", "bed", "dining table", "toilet", "tv", "laptop",
    "mouse", "remote", "keyboard", "cell phone", "microwave",
    "oven", "toaster", "sink", "refrigerator", "book", "clock",
    "vase", "scissors", "teddy bear", "hair drier", "toothbrush"
)

class MainActivity : FlutterActivity() {
    private val CHANNEL = "onnx_channel"
    private lateinit var ortEnv: OrtEnvironment
    private lateinit var ortSession: OrtSession


    // media_button
    private var lastDownTime: Long = 0L
    private val LONG_PRESS_THRESHOLD = 1000L
    private val MEDIA_CHANNEL = "com.class_echo/media_button"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Load the ONNX model
        ortEnv = OrtEnvironment.getEnvironment()
        val modelBytes = assets.open("yolov5n.onnx").readBytes()
        ortSession = ortEnv.createSession(modelBytes)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
    .setMethodCallHandler { call, result ->
        when (call.method) {
            "runYOLO" -> {
                val imagePath = call.argument<String>("path")
                if (imagePath != null) {
                    try {
                        val processedImagePath = runInference(imagePath)
                        result.success(processedImagePath)
                    } catch (e: Exception) {
                        result.error("ONNX_ERROR", e.localizedMessage, null)
                    }
                } else {
                    result.error("INVALID_PATH", "Image path is null", null)
                }
            }

            "callWithSim" -> {
                 val phone = call.argument<String>("phone") ?: ""
            val simSlot = call.argument<Int>("simSlot") ?: 0
            val handler = SosCallHandler(this)
            handler.callWithSim(phone, simSlot)
            result.success("Calling $phone using SIM $simSlot")
            }

            "detectObstacle" -> {
                val imagePath = call.argument<String>("path")
                if (imagePath != null) {
                    val obstacleDetected = detectObstacle(imagePath)
                    result.success(obstacleDetected)
                } else {
                    result.error("INVALID_PATH", "Image path is null", null)
                }
            }


           

            else -> result.notImplemented()
        }
    }

    }


    // media_button
        override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        // Filter relevant key codes for headset buttons
        val keyCode = event.keyCode
        if (keyCode == KeyEvent.KEYCODE_HEADSETHOOK ||
            keyCode == KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE ||
            keyCode == KeyEvent.KEYCODE_MEDIA_PLAY ||
            keyCode == KeyEvent.KEYCODE_MEDIA_PAUSE) {

            when (event.action) {
                KeyEvent.ACTION_DOWN -> {
                    // Avoid multiple ACTION_DOWN repeats triggering repeatedly
                    if (event.repeatCount == 0) {
                        lastDownTime = SystemClock.uptimeMillis()
                        // optional: send a "down" event to Flutter
                        sendToFlutter("button_down", null)
                    }
                    return true // consume the event
                }
                KeyEvent.ACTION_UP -> {
                    val upTime = SystemClock.uptimeMillis()
                    val duration = upTime - lastDownTime
                    if (duration >= LONG_PRESS_THRESHOLD) {
                        // Long press detected
                        sendToFlutter("long_press", mapOf("duration" to duration))
                    } else {
                        // Short press / single tap detected
                        sendToFlutter("single_tap", mapOf("duration" to duration))
                    }
                    lastDownTime = 0L
                    return true // consume the event
                }
            }
        }

        return super.dispatchKeyEvent(event)
    }


     private fun sendToFlutter(method: String, args: Any?) {
        val engine = flutterEngine ?: return
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, MEDIA_CHANNEL)
        channel.invokeMethod(method, args)
    }





   // YOLO 

    private fun runInference(imagePath: String): List<String> {
        Log.d("ONNX", "Running inference on: $imagePath")

        // Load and resize image
        val bitmap = BitmapFactory.decodeFile(imagePath)
        val inputSize = 640 // YOLOv5 expects 640x640
        val resizedBitmap = Bitmap.createScaledBitmap(bitmap, inputSize, inputSize, true)

        // Preprocess image to float tensor
        val inputTensor = preprocessImage(resizedBitmap)

        // Run inference
        val output = ortSession.run(mapOf("images" to inputTensor))
        val outputTensor = output[0].value as Array<Array<FloatArray>>

        // Postprocess detections (no NMS drawing)
        val detections = postProcess(outputTensor[0], resizedBitmap.width, resizedBitmap.height)

        // Return list of detected object names
        val detectedClasses = detections.map {
            COCO_CLASSES.getOrElse(it.classId) { "Unknown" }
        }.distinct()

        Log.i("ONNX", "Detected Objects: $detectedClasses")

        return detectedClasses
    }

    private fun detectObstacle(imagePath: String): Boolean {
        val bitmap = BitmapFactory.decodeFile(imagePath)
        val inputSize = 640
        val resizedBitmap = Bitmap.createScaledBitmap(bitmap, inputSize, inputSize, true)

        val inputTensor = preprocessImage(resizedBitmap)
        val output = ortSession.run(mapOf("images" to inputTensor))
        val outputTensor = output[0].value as Array<Array<FloatArray>>
        val detections = postProcess(outputTensor[0], resizedBitmap.width, resizedBitmap.height)

        // Detect cars or trucks
        val obstacleDetections = detections.filter {
            val cls = COCO_CLASSES[it.classId]
            (cls == "car" || cls == "truck") && it.confidence > 0.5
        }

        for (det in obstacleDetections) {
            val boxWidth = det.x2 - det.x1
            val boxHeight = det.y2 - det.x1
            val boxArea = boxWidth * boxHeight

            // How much of the screen the detected object occupies
            val areaRatio = boxArea / (resizedBitmap.width * resizedBitmap.height).toFloat()

            // Center position of the object
            val boxCenterX = (det.x1 + det.x2) / 2f
            val boxCenterY = (det.y1 + det.y2) / 2f

            // Define "central danger zone"
            val centerMarginX = resizedBitmap.width * 0.25f
            val centerMarginY = resizedBitmap.height * 0.35f
            val centerLeft = resizedBitmap.width / 2f - centerMarginX
            val centerRight = resizedBitmap.width / 2f + centerMarginX
            val centerTop = resizedBitmap.height / 2f - centerMarginY
            val centerBottom = resizedBitmap.height / 2f + centerMarginY

            val isCentered = boxCenterX in centerLeft..centerRight && boxCenterY in centerTop..centerBottom

            // Conditions for obstacle:
            // - Object is large (close)
            // - Object is in front (centered)
            // - High confidence detection
            if (areaRatio > 0.10 && isCentered && det.confidence > 0.6) {
                Log.w("ONNX_OBSTACLE", "🚧 Obstacle detected: ${COCO_CLASSES[det.classId]} close and centered!")
                return true
            }
        }

        Log.d("ONNX_OBSTACLE", "✅ No car/truck obstacles detected.")
        return false
    }




    private fun preprocessImage(bitmap: Bitmap): OnnxTensor {
        val inputWidth = bitmap.width
        val inputHeight = bitmap.height
        val floatBuffer = FloatArray(3 * inputWidth * inputHeight)

        var rIndex = 0
        var gIndex = inputWidth * inputHeight
        var bIndex = 2 * inputWidth * inputHeight

        for (y in 0 until inputHeight) {
            for (x in 0 until inputWidth) {
                val pixel = bitmap.getPixel(x, y)
                floatBuffer[rIndex++] = (Color.red(pixel) / 255.0f)
                floatBuffer[gIndex++] = (Color.green(pixel) / 255.0f)
                floatBuffer[bIndex++] = (Color.blue(pixel) / 255.0f)
            }
        }

        val shape = longArrayOf(1, 3, inputHeight.toLong(), inputWidth.toLong()) // NCHW format
        return OnnxTensor.createTensor(ortEnv, FloatBuffer.wrap(floatBuffer), shape)
    }

    private fun postProcess(
        predictions: Array<FloatArray>,
        imgWidth: Int,
        imgHeight: Int,
        confThreshold: Float = 0.25f,
        iouThreshold: Float = 0.45f
    ): List<Detection> {
        val rawDetections = mutableListOf<Detection>()

        // Convert predictions into Detection objects
        for (pred in predictions) {
            var xCenter = pred[0]
            var yCenter = pred[1]
            var width = pred[2]
            var height = pred[3]
            val objConf = pred[4]

            // Normalize to [0,1] assuming YOLO output is in 640 space
            xCenter /= 640f
            yCenter /= 640f
            width /= 640f
            height /= 640f

            val scores = pred.copyOfRange(5, pred.size)
            val (maxClass, maxScore) = scores.withIndex().maxByOrNull { it.value } ?: continue
            val confidence = objConf * maxScore

            if (confidence > confThreshold) {
                val x1 = ((xCenter - width / 2) * imgWidth).coerceIn(0f, imgWidth.toFloat())
                val y1 = ((yCenter - height / 2) * imgHeight).coerceIn(0f, imgHeight.toFloat())
                val x2 = ((xCenter + width / 2) * imgWidth).coerceIn(0f, imgWidth.toFloat())
                val y2 = ((yCenter + height / 2) * imgHeight).coerceIn(0f, imgHeight.toFloat())

                rawDetections.add(Detection(x1, y1, x2, y2, confidence, maxClass))
            }
        }

        // Apply Non-Maximum Suppression (NMS)
        val finalDetections = mutableListOf<Detection>()
        val sorted = rawDetections.sortedByDescending { it.confidence }.toMutableList()

        while (sorted.isNotEmpty()) {
            val best = sorted.removeAt(0)
            finalDetections.add(best)

            val iterator = sorted.iterator()
            while (iterator.hasNext()) {
                val other = iterator.next()
                val iou = calculateIoU(best, other)
                if (iou > iouThreshold) {
                    iterator.remove() // Remove overlapping boxes
                }
            }
        }

        Log.d("ONNX", "Final detections after NMS: ${finalDetections.size}")
        return finalDetections
    }

    private fun calculateIoU(a: Detection, b: Detection): Float {
        val x1 = max(a.x1, b.x1)
        val y1 = max(a.y1, b.y1)
        val x2 = min(a.x2, b.x2)
        val y2 = min(a.y2, b.y2)

        val intersection = max(0f, x2 - x1) * max(0f, y2 - y1)
        val areaA = (a.x2 - a.x1) * (a.y2 - a.y1)
        val areaB = (b.x2 - b.x1) * (b.y2 - b.y1)
        val union = areaA + areaB - intersection

        return if (union <= 0) 0f else intersection / union
    }

    private fun drawDetections(bitmap: Bitmap, detections: List<Detection>): Bitmap {
        val mutableBitmap = bitmap.copy(Bitmap.Config.ARGB_8888, true)
        val canvas = Canvas(mutableBitmap)
        val boxPaint = Paint().apply {
            color = Color.RED
            style = Paint.Style.STROKE
            strokeWidth = 4f
        }
        val textPaint = Paint().apply {
            color = Color.YELLOW
            textSize = 32f
            style = Paint.Style.FILL
        }

        for (det in detections) {
            canvas.drawRect(det.x1, det.y1, det.x2, det.y2, boxPaint)
            val className = if (det.classId in COCO_CLASSES.indices) COCO_CLASSES[det.classId] else "Unknown"
            canvas.drawText("$className (${String.format("%.2f", det.confidence)})", det.x1, det.y1 - 10, textPaint)

        }
        return mutableBitmap
    }

    data class Detection(
        val x1: Float, val y1: Float,
        val x2: Float, val y2: Float,
        val confidence: Float,
        val classId: Int
    )
}
