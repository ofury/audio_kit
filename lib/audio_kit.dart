import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

export 'audio_kit.dart';

class AudioKit {
  static const MethodChannel _channel = const MethodChannel('audio_kit');
  static const String EVENT_CHANNEL_NAME = 'audio_kit.eventChannel';

  Stream<List<double>> _audioStream;
  StreamSubscription<List<double>> _subscription;
  bool _isStreaming = false;

  static const EventChannel _noiseEventChannel =
      EventChannel(EVENT_CHANNEL_NAME);

  static Future<AudioOutput> startRecording() async {
    var result = await _channel.invokeMethod('startRecording');
    return _showRecordingStatus(result);
  }

  static Future<AudioOutput> stopRecording() async {
    var result = await _channel.invokeMethod('stopRecording');
    return _showRecordingStatus(result);
  }

  static Future<bool> setFilePath(String filePath) async {
    return await _channel.invokeMethod('setFilePath', {"filePath": filePath});
  }

  static Future<bool> get isRecording async {
    bool isRecording = await _channel.invokeMethod('isRecording');
    return isRecording;
  }

  static Future<AudioOutput> recordingStatus() async {
    var result = await _channel.invokeMethod('showRecordingStatus');
    return _showRecordingStatus(result);
  }

  static AudioOutput _showRecordingStatus(result) {
    if (result != null) {
      Map<String, Object> response = Map.from(result);
      AudioOutput recording = AudioOutput();
      recording.path = response["path"];
      recording.duration = Duration(seconds: response['duration']);
      recording.isRecording = response["isRecording"];
      return recording;
    } else {
      return null;
    }
  }

  Future<bool> startAudioStream(Function onData, Function onError) async {
    if (_isStreaming) {
      return _isStreaming;
    } else {
      try {
        _audioStream = _noiseEventChannel
            .receiveBroadcastStream()
            .handleError((error) {
          _isStreaming = false;
          _audioStream = null;
          onError(error);
        })
            .map((buffer) => buffer as List<dynamic>)
            .map((list) => list.map((e) => double.parse('$e')).toList());
        _subscription = _audioStream.listen(onData);
        _isStreaming = true;
      } catch (err) {
        debugPrint('AudioKit: startAudioStream error: $err');
      } finally{
        debugPrint('AudioKit: streaming : $_isStreaming');
      }
    }
    return _isStreaming;
  }

  Future<bool> stopAudioStream() async {
    try {
      if (_subscription != null) {
        _subscription.cancel();
        _subscription = null;
      }
      _isStreaming = false;
    } catch (err) {
      debugPrint('AudioKit: stopAudioStream() error: $err');
    } finally{
      debugPrint('AudioKit: streaming : $_isStreaming');
    }
    return _isStreaming;
  }
}


class AudioOutput {
  bool isRecording;
  bool isStreaming;
  String path;
  Duration duration;
}

