import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ScrollingTextWindow extends StatefulWidget {
  final String text;
  final String title;
  final Color baseColor;

  const ScrollingTextWindow({
    super.key,
    required this.text,
    required this.title,
    required this.baseColor,
  });

  @override
  State<ScrollingTextWindow> createState() => _ScrollingTextWindowState();
}

class _ScrollingTextWindowState extends State<ScrollingTextWindow> {
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void didUpdateWidget(covariant ScrollingTextWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.baseColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: widget.baseColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title.toUpperCase(),
            style: GoogleFonts.outfit(
              color: widget.baseColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Text(
                widget.text.isEmpty ? "Waiting for audio..." : widget.text,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
