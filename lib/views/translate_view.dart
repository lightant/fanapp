import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/translation_provider.dart';
import '../widgets/scrolling_text_window.dart';

class TranslateView extends ConsumerWidget {
  const TranslateView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translationProvider);
    final notifier = ref.read(translationProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E), // Deep dark background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Gemma 4 Live Translate", style: GoogleFonts.outfit(color: Colors.white, fontSize: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () => notifier.toggleLiveMode(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: state.isLiveMode ? Colors.redAccent.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                  foregroundColor: state.isLiveMode ? Colors.redAccent : Colors.cyanAccent,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  side: BorderSide(
                    color: state.isLiveMode ? Colors.redAccent : Colors.cyanAccent.withOpacity(0.5),
                  ),
                ),
                icon: Icon(
                  state.isLiveMode ? Icons.stop_circle_outlined : Icons.wifi_tethering,
                  size: 16,
                ),
                label: Text(
                  "LIVE",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                    color: state.isLiveMode ? Colors.redAccent : Colors.cyanAccent,
                  ),
                ),
              ),
            ),
          ),
          if (state.isRecording)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  "LISTENING...",
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ),
          if (state.isInitializing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.orangeAccent),
            tooltip: "Clear Text",
            onPressed: () => notifier.clearText(),
          ),
          if (state.lastAudioPath != null)
            IconButton(
              icon: const Icon(Icons.play_circle_outline, color: Colors.greenAccent),
              tooltip: "Play Last Recording",
              onPressed: () => notifier.playLastRecording(),
            ),
          IconButton(
            icon: const Icon(Icons.file_open, color: Colors.cyanAccent),
            tooltip: "Side-load Model",
            onPressed: () => notifier.pickModelFile(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status and Error Display
            if (state.isInitializing)
              const LinearProgressIndicator(color: Colors.cyanAccent),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  state.error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            
            // Top Window: Original Text
            Expanded(
              child: Stack(
                children: [
                  ScrollingTextWindow(
                    text: state.historyInputText.isEmpty 
                          ? state.inputText 
                          : (state.inputText.isEmpty ? state.historyInputText : "${state.historyInputText}\n\n${state.inputText}").trim(),
                    title: "Original",
                    baseColor: Colors.blueAccent,
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.volume_up, color: Colors.cyanAccent),
                      onPressed: () => notifier.speakOriginal(),
                    ),
                  ),
                ],
              ),
            ),
            
            // Middle Control Bar
            _buildControlBar(context, state, notifier),
            
            // Bottom Window: Translated Text
            Expanded(
              child: Stack(
                children: [
                  ScrollingTextWindow(
                    text: state.historyOutputText.isEmpty 
                          ? state.outputText 
                          : (state.outputText.isEmpty ? state.historyOutputText : "${state.historyOutputText}\n\n${state.outputText}").trim(),
                    title: "Translation",
                    baseColor: Colors.greenAccent,
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.volume_up, color: Colors.blueAccent),
                      onPressed: () => notifier.speakTranslated(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar(BuildContext context, TranslationState state, TranslationNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Source Language (Selectable)
          _buildLanguageButton(
            context,
            state.sourceLanguage,
            () => _showLanguagePicker(context, notifier, true),
            Icons.translate,
          ),
          
          // Center: Start / Stop
          GestureDetector(
            onTap: () => notifier.toggleRecording(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: state.isRecording 
                    ? [Colors.red, Colors.redAccent] 
                    : [Colors.cyanAccent, Colors.blueAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (state.isRecording ? Colors.red : Colors.cyanAccent).withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                state.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          
          // Right: Target Language (Selectable)
          _buildLanguageButton(
            context,
            state.targetLanguage,
            () => _showLanguagePicker(context, notifier, false),
            Icons.language,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageButton(BuildContext context, String label, VoidCallback? onTap, IconData icon) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, TranslationNotifier notifier, bool isSource) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final languages = ["Auto", "Swedish", "Chinese", "Spanish", "Japanese", "Korean", "Finnish", "English"];
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isSource ? "Source Language" : "Target Language",
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: languages.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(languages[index], style: const TextStyle(color: Colors.white)),
                      onTap: () {
                        if (isSource) {
                          notifier.setSourceLanguage(languages[index]);
                        } else {
                          notifier.setTargetLanguage(languages[index]);
                        }
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
