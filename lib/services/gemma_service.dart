import 'dart:async';
import 'dart:io';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class GemmaService {
  bool _isInitialized = false;
  InferenceModel? _model;
  String? _currentModelPath;

  Future<String> initModel({
    String? specificPath,
    bool supportAudio = false,
  }) async {
    try {
      if (!_isInitialized) {
        await FlutterGemma.initialize();
        _isInitialized = true;
      }

      String? targetPath = specificPath ?? await _findAnyModel();
      print("[GemmaService] Using model path: $targetPath");

      if (targetPath == null) {
        return "INIT_FAILED: No .litertlm model file found.";
      }

      if (_model == null || _currentModelPath != targetPath) {
        print("[GemmaService] Installing model...");
        await FlutterGemma.installModel(
          modelType: ModelType.gemmaIt,
          fileType: ModelFileType.litertlm,
        ).fromFile(targetPath).install();

        print(
          "[GemmaService] Activating model (supportAudio: $supportAudio)...",
        );
        _model = await FlutterGemma.getActiveModel(
          preferredBackend: PreferredBackend.gpu,
          maxTokens: 4096,
          supportAudio: supportAudio,
        );
        _currentModelPath = targetPath;
      }

      return "INITIALIZED";
    } catch (e) {
      return "INIT_FAILED: $e";
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;

    // For Android 11+, we ideally want MANAGE_EXTERNAL_STORAGE for side-loading
    if (await Permission.manageExternalStorage.isGranted) return true;

    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    // Fallback to basic storage permission if manage is denied
    return await Permission.storage.request().isGranted;
  }

  Future<String?> _findAnyModel() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        print(
          "[GemmaService] Storage permission denied. Cannot auto-discover models.",
        );
      }
    }

    final Set<String> searchDirs = {};

    // 1. Android standard directories
    if (defaultTargetPlatform == TargetPlatform.android) {
      searchDirs.addAll([
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents',
      ]);
    }

    // 2. Desktop standard directories (macOS/Linux)
    if (!kIsWeb && (Platform.isMacOS || Platform.isLinux)) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        searchDirs.add('$home/Downloads');
        searchDirs.add('$home/Documents');
      }
    }

    // 3. Fallback to path_provider locations
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      searchDirs.add(docsDir.path);
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) searchDirs.add(downloadsDir.path);
    } catch (_) {}

    print("[GemmaService] Scanning for .litertlm in: $searchDirs");

    for (final dirPath in searchDirs) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        try {
          final files = dir.listSync();
          for (final file in files) {
            if (file is File && file.path.toLowerCase().endsWith('.litertlm')) {
              print("[GemmaService] Found model: ${file.path}");
              return file.path;
            }
          }
        } catch (_) {}
      }
    }
    return null;
  }

  /// Translates audio to target language
  Stream<String> translateAudioStream(
    String audioFilePath, {
    String? sourceLang,
    String? targetLang,
  }) async* {
    if (_model == null) {
      final status = await initModel();
      if (status.startsWith("INIT_FAILED")) {
        yield "Error: $status";
        return;
      }
    }

    final audioFile = File(audioFilePath);
    if (!await audioFile.exists()) {
      yield "Error: Audio file not found.";
      return;
    }

    try {
      final pSource = sourceLang ?? "any";
      final pTarget = targetLang ?? "English";

      final String systemPrompt;
      if (pSource == "any") {
        systemPrompt =
            "You are a professional real-time speech translator.\n"
            "Source Language: Any (auto-detect)\n"
            "Target Language: $pTarget\n\n"
            "Task Instructions:\n"
            "1. Transcribe the audio exactly in the language it is spoken. Output this transcription under the [ORIGINAL] tag.\n"
            "2. Translate that transcription strictly into $pTarget. Output this translation under the [TRANSLATED] tag.\n\n"
            "Strict Constraints:\n"
            "- Under [TRANSLATED], you MUST translate only into $pTarget. Do NOT output the original language.\n"
            "- Under [ORIGINAL], output the transcription in the original language. Do NOT output the translation.\n"
            "- If the audio is purely silent, contains only unintelligible noise/static, or has no speech, output EXACTLY: [SILENCE]\n"
            "- Do NOT add any conversational text, pleasantries, explanations, or system tags.\n\n"
            "Output Format:\n"
            "[TRANSLATED]: {translation in $pTarget}\n"
            "[ORIGINAL]: {transcription in original language}";
      } else {
        systemPrompt =
            "You are a professional real-time speech translator.\n"
            "Source Language: $pSource\n"
            "Target Language: $pTarget\n\n"
            "Task Instructions:\n"
            "1. Transcribe the audio exactly in $pSource. Output this transcription under the [ORIGINAL] tag.\n"
            "2. Translate that transcription strictly into $pTarget. Output this translation under the [TRANSLATED] tag.\n\n"
            "Strict Constraints:\n"
            "- You MUST translate strictly from $pSource to $pTarget. Do NOT translate from any other language.\n"
            "- If the speech in the audio is NOT in the $pSource language, or is silent/noise/static, output EXACTLY: [SILENCE]\n"
            "- Under [TRANSLATED], you MUST translate only into $pTarget. Do NOT output $pSource.\n"
            "- Under [ORIGINAL], output the transcription in $pSource. Do NOT output the translation.\n"
            "- Do NOT add any conversational text, pleasantries, explanations, or system tags.\n\n"
            "Output Format:\n"
            "[TRANSLATED]: {translation in $pTarget}\n"
            "[ORIGINAL]: {transcription in $pSource}";
      }

      // The official example initializes the conversation with systemInstruction
      final session = await _model!.createSession(
        systemInstruction: systemPrompt,
      );

      print("[GemmaService] Reading audio file: $audioFilePath");
      final audioBytes = await audioFile.readAsBytes();
      print("[GemmaService] Audio bytes size: ${audioBytes.length}");
      print("[GemmaService] System Prompt: $systemPrompt");

      // Add audio with empty text, so text is not appended incorrectly
      await session.addQueryChunk(
        Message.withAudio(audioBytes: audioBytes, text: "", isUser: true),
      );

      print("[GemmaService] Starting inference...");
      await for (final chunk in session.getResponseAsync()) {
        yield chunk;
      }
      await session.close();
    } catch (e) {
      yield "Inference Error: $e";
    }
  }

  Future<void> dispose() async {
    _model = null;
    _currentModelPath = null;
  }
}
