import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();

  AudioService() {
    _initTTS();
  }

  Future<void> _initTTS() async {
    await _tts.setSharedInstance(true);
    await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback,
        [IosTextToSpeechAudioCategoryOptions.defaultToSpeaker]);
  }

  Future<void> speak(String text, String languageCode) async {
    await _tts.setLanguage(languageCode);
    await _tts.setPitch(1.0);
    await _tts.speak(text);
  }

  Future<void> stopTTS() async {
    await _tts.stop();
  }

  Stream<Amplitude> amplitudeStream() {
    return _recorder.onAmplitudeChanged(const Duration(milliseconds: 100));
  }

  Future<bool> hasPermission() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      print("[AudioService] Permission for microphone denied.");
    }
    return status.isGranted;
  }

  Future<void> playRecording(String path) async {
    try {
      print("[AudioService] Playing recording: $path");
      await _player.play(DeviceFileSource(path));
    } catch (e) {
      print("[AudioService] Error playing: $e");
    }
  }

  Future<String?> startRecording() async {
    try {
      if (await hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path = p.join(tempDir.path, 'translate_${DateTime.now().millisecondsSinceEpoch}.wav');
        print("[AudioService] Starting recording at: $path");
        
        // Gemma 4 E2B expects 16kHz Mono 16-bit PCM WAV
        const config = RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        );

        await _recorder.start(config, path: path);
        return path;
      }
    } catch (e) {
      print('[AudioService] Error starting recording: $e');
    }
    return null;
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          final size = await file.length();
          print("[AudioService] Recording stopped. File size: $size bytes");
        }
      }
      return path;
    } catch (e) {
      print('[AudioService] Error stopping recording: $e');
    }
    return null;
  }

  void dispose() {
    _recorder.dispose();
  }
}
