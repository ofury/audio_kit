import Flutter
import UIKit
import AVFoundation

public class SwiftAudioKitPlugin: NSObject, FlutterPlugin, AVAudioRecorderDelegate, FlutterStreamHandler{
    private var eventSink: FlutterEventSink?
    var engine = AVAudioEngine()
    var audioData: [Float] = []
    var recording = false

    var hasPermissions = false
    internal var isPaused = false


    var audioRecorder: AVAudioRecorder!
    private var path: String?
    internal var recordingSession: AVAudioSession = AVAudioSession.sharedInstance()

    private let settings = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44100,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey:AVAudioQuality.high.rawValue
    ]

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "audio_kit", binaryMessenger: registrar.messenger())
    let instance = SwiftAudioKitPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    // Set flutter communication channel for emitting updates
    let eventChannel = FlutterEventChannel.init(name: "audio_kit.eventChannel", binaryMessenger: registrar.messenger())
    eventChannel.setStreamHandler(instance)
    instance.setupNotifications()
  }

    private func setupNotifications() {
    // Get the default notification center instance.
    NotificationCenter.default.addObserver(self,
                  selector: #selector(handleInterruption(notification:)),
                  name: AVAudioSession.interruptionNotification,
                  object: nil)
  }
  @objc func handleInterruption(notification: Notification) {
      // To be implemented.
    eventSink!(FlutterError(code: "100", message: "AudioKit: recording was interrupted", details: "Another process interrupted recording."))
  }
  // Handle stream emitting (Swift => Flutter)
    private func emitValues(values: [Float]) {
      // If no eventSink to emit events to, do nothing (wait)
      if (eventSink == nil) {
          return
      }
      // Emit values count event to Flutter
      eventSink!(values)
    }

    // Event Channel: On Stream Listen
    public func onListen(withArguments arguments: Any?,
      eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        startAudioStream()
        return nil
    }

    // Event Channel: On Stream Cancelled
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        NotificationCenter.default.removeObserver(self)
        eventSink = nil
        engine.stop()
        return nil
    }

    func startAudioStream() {
        engine = AVAudioEngine()

        try! AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.record)

        let input = engine.inputNode
        let bus = 0

        input.installTap(onBus: bus, bufferSize: 22050, format: input.inputFormat(forBus: bus)) { (buffer, time) -> Void in
            let samples = buffer.floatChannelData?[0]
            // audio callback, samples in samples[0]...samples[buffer.frameLength-1]
            let arr = Array(UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength)))
            self.emitValues(values: arr)
        }

        try! engine.start()
    }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
        case "showRecordingStatus":
            print("showRecordingStatus")
            let recordingResult = showRecordingStatus(call: call)
            result(recordingResult)
        case "stopRecording":
            let recordingResult = stopRecording(call: call)
            result(recordingResult)
            break
        case "startRecording":
            let recordingResult = startRecording(call: call)
            result(recordingResult)
            break
        case "setFilePath":
            let dic = call.arguments as! [String:Any]
            let name = self.setFilePath(filePath: dic["filePath"] as? String ??
             "")
            result(name)
            break
        case "isRecording":
            if let audioRecorder = audioRecorder {
                result(audioRecorder.isRecording)
                print("AudioKit recording=\(audioRecorder.isRecording)")
            }
            break
        default:
            result("iOS " + UIDevice.current.systemVersion)
    }
  }

  func stopRecording(call: FlutterMethodCall) -> [String : Any]?{
      return self.finishRecording(call: call)
  }

  func showRecordingStatus(call: FlutterMethodCall) -> [String : Any]?{
    if let audioRecorder = audioRecorder {
        audioRecorder.updateMeters()
        let duration = Int(audioRecorder.currentTime)
        var recordingResult = [String : Any]()
        recordingResult["path"] = path
        recordingResult["duration"] = duration
        recordingResult["isRecording"] = audioRecorder.isRecording
        return recordingResult
    }else{
        return nil
    }
  }

  func setFilePath(filePath: String)->Bool{
      self.path = filePath
      return true
  }

  func startRecording(call: FlutterMethodCall) -> [String: Any]?{
      if(audioRecorder != nil && audioRecorder.isRecording)
      {
          self.pause()
      }
      else
      {
        if audioRecorder == nil {
            self.startRecorder()
        }else{
            self.resume()
        }
      }
      print("AudioKit startRecording: self.isPaused = \(isPaused)")
      return showRecordingStatus(call: call)
  }

  func isPause() -> Bool {
      if let audioRecorder = audioRecorder {
          return isPaused || !audioRecorder.isRecording
      }else{
          return isPaused
      }
  }

  private func pause() {
      if let audioRecorder = audioRecorder{
          if audioRecorder.isRecording{
              self.isPaused = true
              audioRecorder.pause()
          }
      }
  }

  private func resume() {
      if let audioRecorder = audioRecorder {
          self.isPaused = false
          audioRecorder.record()
      }
  }


  private func startRecorder()
  {
      do
      {
          try recordingSession.setCategory(.record, mode: .default, options: .mixWithOthers)
          try recordingSession.setActive(true)
        let url = URL(string: path!) ?? URL(fileURLWithPath: path!)
        self.audioRecorder = try AVAudioRecorder(url: url, settings: self.settings)
        self.audioRecorder.delegate = self
        self.audioRecorder.isMeteringEnabled = true
        self.audioRecorder.updateMeters()
        self.audioRecorder.record()
      }
      catch let error {
        print("error=\(error.localizedDescription)")
      }
  }

  private func finishRecording(call: FlutterMethodCall) -> [String : Any]?{
    let current = showRecordingStatus(call: call)
    if let recorder = self.audioRecorder{
        recorder.stop()
        audioRecorder = nil

        do{
            try recordingSession.setActive(false)
        }catch let error{
            print("error = \(error.localizedDescription)")
        }
    }
    print("recorded successfully.")
    return current
  }
}

extension TimeInterval{
    func toSeconds() -> Int {
        let time = NSInteger(self)
        let seconds = time % 60
        return seconds
    }
}
