package com.example.audio_kit

import android.app.Activity
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry.Registrar
import io.flutter.plugin.common.MethodChannel.Result
import java.io.*
import java.util.*

/** AudioKitPlugin */
class AudioKitPlugin : FlutterPlugin, MethodCallHandler,
    EventChannel.StreamHandler, ActivityAware {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var isRecording = false
    private var isStreaming = false
    private var output: String = ""
    private var filePath: String = ""

    private var mediaRecorder: MediaRecorder? = null
    private var recordingTime: Long = 0
    private var eventSink: EventSink? = null
    private var channelConfig = AudioFormat.CHANNEL_IN_MONO
    private var encodingFormat = AudioFormat.ENCODING_PCM_16BIT
    private var rateInHz = 44100
    private var bufferSize: Int = AudioRecord.getMinBufferSize(
        rateInHz,
        channelConfig, encodingFormat
    )
    private val maxAmplitude = 32767

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val instance = AudioKitPlugin()
        channel =
            MethodChannel(flutterPluginBinding.binaryMessenger, "audio_kit")
        channel.setMethodCallHandler(instance)

        val eventChannel =
            EventChannel(
                flutterPluginBinding.binaryMessenger,
                "audio_kit.eventChannel"
            )
        eventChannel.setStreamHandler(instance)
    }

    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val instance = AudioKitPlugin()

            val channel =
                MethodChannel(registrar.messenger(), "audio_kit")
            channel.setMethodCallHandler(instance)

            val eventChannel =
                EventChannel(
                    registrar.messenger(),
                    "audio_kit.eventChannel"
                )
            eventChannel.setStreamHandler(instance)

        }
    }

    override fun onMethodCall(
        @NonNull call: MethodCall,
        @NonNull result: Result
    ) {
        when (call.method) {
            "showRecordingStatus" -> showAudioRecordingStatus(result)
            "startRecording" -> startAudioRecording(result)
            "stopRecording" -> stopAudioRecording(result)
            "isRecording" -> isRecording(result)
            "setFilePath" -> setFilePath(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.activity = binding.activity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        this.activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {

    }

    override fun onDetachedFromActivity() {
        this.activity = null
    }

    private fun handleInit(filePath: String) {
        output = filePath;
        mediaRecorder = MediaRecorder()
        mediaRecorder?.setAudioSource(MediaRecorder.AudioSource.MIC)
        mediaRecorder?.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        mediaRecorder?.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        mediaRecorder?.setOutputFile(filePath)
        mediaRecorder?.prepare()
    }

    private fun showAudioRecordingStatus(result: Result) {
        if (mediaRecorder != null) {
            val currentResult: HashMap<String, Any> = HashMap()
            currentResult["duration"] = recordingTime
            currentResult["path"] = output
            currentResult["isRecording"] = isRecording
            currentResult["isStreaming"] = isStreaming
            result.success(currentResult)
        } else {
            result.success(null)
        }
    }

    private fun startAudioRecording(result: Result) {
        isRecording = true
        mediaRecorder?.start()
        showAudioRecordingStatus(result)
    }

    private fun stopAudioRecording(result: Result) {
        this.isRecording = false
        showAudioRecordingStatus(result)
        mediaRecorder?.stop()
        mediaRecorder?.reset();
        mediaRecorder?.release()
        mediaRecorder = null
    }

    private fun isRecording(result: Result) {
        result.success(isRecording)
    }

    private fun setFilePath(call: MethodCall, result: Result) {
        this.filePath = call.argument<Any>("filePath").toString()
        handleInit(this.filePath)
        result.success(true)
    }


    override fun onListen(arguments: Any?, events: EventSink?) {
        this.eventSink = events
        isStreaming = true
        startAudioStream()
    }

    override fun onCancel(arguments: Any?) {
        isStreaming = false
    }

    private fun startAudioStream() {
        Thread(Runnable {
            Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)
            val audioBuffer = ShortArray(bufferSize / 2)
            val record = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                rateInHz,
                channelConfig,
                encodingFormat,
                bufferSize
            )
            if (record.state != AudioRecord.STATE_INITIALIZED) {
                return@Runnable
            }
            /** Start isStreaming loop  */
            record.startRecording()
            while (isStreaming) {
                /** Read data into buffer  */
                record.read(audioBuffer, 0, audioBuffer.size)
                Handler(Looper.getMainLooper()).post {
                    /// Convert to list in order to send via EventChannel.
                    val audioBufferList = ArrayList<Double>()
                    for (impulse in audioBuffer) {
                        val normalizedImpulse =
                            impulse.toDouble() / maxAmplitude.toDouble()
                        audioBufferList.add(normalizedImpulse)
                    }
                    eventSink!!.success(audioBufferList)
                }
            }
            record.stop()
            record.release()
        }).start()
    }
}

