import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_service.dart';
import '../services/gemma_service.dart';
import 'package:file_picker/file_picker.dart';
class TranslationState {
  final String inputText;
  final String outputText;
  final bool isRecording;
  final bool isInitializing;
  final bool isInitialized;
  final String? error;
  final String sourceLanguage;
  final String targetLanguage;
  final String? lastAudioPath;
  final bool isLiveMode;
  final String historyInputText;
  final String historyOutputText;

  TranslationState({
    this.inputText = "",
    this.outputText = "",
    this.historyInputText = "",
    this.historyOutputText = "",
    this.isRecording = false,
    this.isInitializing = false,
    this.isInitialized = false,
    this.error,
    this.sourceLanguage = "Auto",
    this.targetLanguage = "English",
    this.lastAudioPath,
    this.isLiveMode = false,
  });

  TranslationState copyWith({
    String? inputText,
    String? outputText,
    bool? isRecording,
    bool? isInitializing,
    bool? isInitialized,
    String? error,
    String? sourceLanguage,
    String? targetLanguage,
    String? lastAudioPath,
    bool? isLiveMode,
    String? historyInputText,
    String? historyOutputText,
  }) {
    return TranslationState(
      inputText: inputText ?? this.inputText,
      outputText: outputText ?? this.outputText,
      historyInputText: historyInputText ?? this.historyInputText,
      historyOutputText: historyOutputText ?? this.historyOutputText,
      isRecording: isRecording ?? this.isRecording,
      isInitializing: isInitializing ?? this.isInitializing,
      isInitialized: isInitialized ?? this.isInitialized,
      error: error,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      lastAudioPath: lastAudioPath ?? this.lastAudioPath,
      isLiveMode: isLiveMode ?? this.isLiveMode,
    );
  }
}

class TranslationNotifier extends Notifier<TranslationState> {
  final _audioService = AudioService();
  final _gemmaService = GemmaService();
  StreamSubscription? _amplitudeSub;
  Timer? _silenceTimer;
  static const double _silenceThreshold = -40.0;
  static const int _silenceDurationMs = 2000;

  @override
  TranslationState build() {
    return TranslationState();
  }

  Future<void> initModel() async {
    if (state.isInitialized || state.isInitializing) return;
    print("[TranslationNotifier] Initializing Gemma model...");
    state = state.copyWith(isInitializing: true);
    final status = await _gemmaService.initModel(supportAudio: true);
    print("[TranslationNotifier] Model status: $status");
    if (status == "INITIALIZED") {
      state = state.copyWith(isInitializing: false, isInitialized: true);
    } else {
      state = state.copyWith(isInitializing: false, error: status);
    }
  }

  void setSourceLanguage(String lang) {
    state = state.copyWith(sourceLanguage: lang);
  }

  void setTargetLanguage(String lang) {
    state = state.copyWith(targetLanguage: lang);
  }

  void toggleLiveMode() {
    if (state.isLiveMode) {
      if (state.isRecording) {
        toggleRecording(); // Manual stop breaks loop
      } else {
        state = state.copyWith(isLiveMode: false);
      }
    } else {
      state = state.copyWith(isLiveMode: true);
      if (!state.isRecording) {
        toggleRecording();
      }
    }
  }

  Future<void> toggleRecording({bool isAutoStop = false}) async {
    if (!state.isInitialized && !state.isInitializing) {
      await initModel();
    }

    if (state.isInitializing) {
      print("[TranslationNotifier] Still initializing...");
      return;
    }

    if (state.isRecording) {
      print("[TranslationNotifier] Stopping recording...");
      if (!isAutoStop) {
        state = state.copyWith(isLiveMode: false);
      }
      _stopSilenceDetection();
      final path = await _audioService.stopRecording();
      final sourceLang = state.sourceLanguage == "Auto" ? null : state.sourceLanguage;
      final targetLang = state.targetLanguage;

      if (path != null) {
        print("[TranslationNotifier] Audio saved to: $path");
        state = state.copyWith(isRecording: false, lastAudioPath: path);
        _startTranslation(path, sourceLang, targetLang);
      } else {
        state = state.copyWith(isRecording: false);
      }
    } else {
      print("[TranslationNotifier] Starting recording...");
      if (await _audioService.hasPermission()) {
        final path = await _audioService.startRecording();
        if (path != null) {
          state = state.copyWith(isRecording: true, outputText: "Listening...", inputText: "");
          _startSilenceDetection();
        } else {
          print("[TranslationNotifier] Failed to start recording.");
        }
      } else {
        print("[TranslationNotifier] Permission denied.");
        state = state.copyWith(error: "Microphone permission denied.");
      }
    }
  }

  bool _hasSpoken = false;

  void _startSilenceDetection() {
    _amplitudeSub?.cancel();
    _silenceTimer?.cancel();
    _hasSpoken = false;
    
    _amplitudeSub = _audioService.amplitudeStream().listen((amp) {
      if (amp.current > _silenceThreshold) {
        // Sound detected, mark that speech started and reset timer
        _hasSpoken = true;
        _silenceTimer?.cancel();
      } else {
        // Silence detected (volume below threshold)
        if (_hasSpoken) {
          // If they have spoken previously, start the countdown to stop
          if (_silenceTimer == null || !_silenceTimer!.isActive) {
            _silenceTimer = Timer(const Duration(milliseconds: _silenceDurationMs), () {
              print("[TranslationNotifier] Post-speech silence detected, translating...");
              toggleRecording(isAutoStop: true);
            });
          }
        }
      }
    });

    // We removed the strictly automatic 2-second initial limit. 
    // Now it will wait infinitely for speech to start.
  }

  void _stopSilenceDetection() {
    _amplitudeSub?.cancel();
    _silenceTimer?.cancel();
    _amplitudeSub = null;
    _silenceTimer = null;
  }

  Future<void> _startTranslation(String audioPath, String? sourceLang, String targetLang) async {
    state = state.copyWith(outputText: "", inputText: "");
    final stream = _gemmaService.translateAudioStream(audioPath, sourceLang: sourceLang, targetLang: targetLang);
    
    String accumulated = "";
    await for (final chunk in stream) {
      if (chunk.startsWith("Error:") || chunk.startsWith("Inference Error:")) {
        state = state.copyWith(error: chunk);
      } else {
        accumulated += chunk;
        print("[Gemma Raw Chunk]: $chunk");
        _parseAccumulated(accumulated);
      }
    }
    print("[Gemma Final Response]: $accumulated");

    // Once translation finishes, commit the active text to history
    if (state.inputText.isNotEmpty || state.outputText.isNotEmpty) {
      final newHistoryInput = state.historyInputText.isEmpty 
          ? state.inputText 
          : "${state.historyInputText}\n\n${state.inputText}";
      final newHistoryOutput = state.historyOutputText.isEmpty 
          ? state.outputText 
          : "${state.historyOutputText}\n\n${state.outputText}";

      state = state.copyWith(
        historyInputText: newHistoryInput.trim(),
        historyOutputText: newHistoryOutput.trim(),
        inputText: "",
        outputText: "",
      );
    }

    if (state.isLiveMode && !state.isInitializing) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (state.isLiveMode && !state.isRecording) {
          toggleRecording();
        }
      });
    }
  }

  void _parseAccumulated(String text) {
    String original = "";
    String translated = "";

    // Using case-insensitive regex for tags, allowing for optional colons and spaces
    final originalMatch = RegExp(r"\[ORIGINAL\]\s*:?\s*([\s\S]*?)(?=\[TRANSLATED\]|$)", caseSensitive: false).firstMatch(text);
    final translatedMatch = RegExp(r"\[TRANSLATED\]\s*:?\s*([\s\S]*)", caseSensitive: false).firstMatch(text);

    if (originalMatch != null) {
      original = originalMatch.group(1) ?? "";
    }
    if (translatedMatch != null) {
      translated = translatedMatch.group(1) ?? "";
    }

    // Fallback if tags are missing entirely
    if (originalMatch == null && translatedMatch == null) {
      // Strip any full tags that might be misformatted
      translated = text.replaceAll(RegExp(r'\[?(ORIGINAL|TRANSLATED)\]?\s*:?\s*', caseSensitive: false), '');
    }

    // Clean up any partial tags that are actively streaming at the end of the text like "[ORIG" or "[TRANS"
    final partialTagRegex = RegExp(r'\[[a-zA-Z]*$', caseSensitive: false);
    
    state = state.copyWith(
      inputText: original.replaceAll(partialTagRegex, '').trim(), 
      outputText: translated.replaceAll(partialTagRegex, '').trim()
    );
  }

  String _getLangCode(String lang) {
    switch (lang) {
      case "Japanese": return "ja-JP";
      case "Chinese": return "zh-CN";
      case "Korean": return "ko-KR";
      case "Spanish": return "es-ES";
      case "Finnish": return "fi-FI";
      case "Swedish": return "sv-SE";
      default: return "en-US";
    }
  }

  Future<void> speakOriginal() async {
    final text = (state.historyInputText.isEmpty ? state.inputText : "${state.historyInputText}\n\n${state.inputText}").trim();
    if (text.isNotEmpty) {
      await _audioService.speak(text, _getLangCode(state.sourceLanguage));
    }
  }

  Future<void> speakTranslated() async {
    final text = (state.historyOutputText.isEmpty ? state.outputText : "${state.historyOutputText}\n\n${state.outputText}").trim();
    if (text.isNotEmpty) {
      await _audioService.speak(text, _getLangCode(state.targetLanguage));
    }
  }

  void clearText() {
    state = state.copyWith(
      inputText: "",
      outputText: "",
      historyInputText: "",
      historyOutputText: "",
    );
  }

  void clear() {
    state = TranslationState(sourceLanguage: state.sourceLanguage, targetLanguage: state.targetLanguage);
  }

  Future<void> pickModelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        print("[TranslationNotifier] Manually picked model: $path");
        state = state.copyWith(isInitializing: true, error: null);
        final status = await _gemmaService.initModel(specificPath: path);
        print("[TranslationNotifier] Manual init status: $status");
        if (status == "INITIALIZED") {
          state = state.copyWith(isInitializing: false, isInitialized: true);
        } else {
          state = state.copyWith(isInitializing: false, error: status);
        }
      }
    } catch (e) {
      state = state.copyWith(error: "Error picking file: $e");
    }
  }

  Future<void> playLastRecording() async {
    if (state.lastAudioPath != null) {
      await _audioService.playRecording(state.lastAudioPath!);
    }
  }
}

final translationProvider = NotifierProvider<TranslationNotifier, TranslationState>(
  TranslationNotifier.new,
);
