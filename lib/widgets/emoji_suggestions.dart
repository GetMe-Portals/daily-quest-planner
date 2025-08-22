import 'package:flutter/material.dart';
import 'dart:async';
import '../services/emoji_service.dart';
import '../theme/app_theme.dart';

class EmojiSuggestions extends StatefulWidget {
  final String text;
  final Function(String) onEmojiSelected;
  final ThemeProvider themeProvider;
  final bool isFocused;

  const EmojiSuggestions({
    Key? key,
    required this.text,
    required this.onEmojiSelected,
    required this.themeProvider,
    required this.isFocused,
  }) : super(key: key);

  @override
  State<EmojiSuggestions> createState() => _EmojiSuggestionsState();
}

class _EmojiSuggestionsState extends State<EmojiSuggestions> {
  Timer? _hideTimer;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _updateVisibility();
  }

  @override
  void didUpdateWidget(EmojiSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.isFocused != widget.isFocused) {
      _updateVisibility();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _updateVisibility() {
    final shouldShow = widget.text.trim().isNotEmpty && 
                      widget.isFocused && 
                      _getEmojiSuggestions(widget.text).isNotEmpty;

    if (shouldShow && !_isVisible) {
      setState(() {
        _isVisible = true;
      });
      _startHideTimer();
    } else if (!shouldShow && _isVisible) {
      setState(() {
        _isVisible = false;
      });
      _cancelHideTimer();
    }
  }

  void _startHideTimer() {
    _cancelHideTimer();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _isVisible = false;
        });
      }
    });
  }

  void _cancelHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _onEmojiSelected(String emoji) {
    widget.onEmojiSelected(emoji);
    _cancelHideTimer(); // Cancel timer when user interacts
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    final suggestions = _getEmojiSuggestions(widget.text);
    
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedOpacity(
      opacity: _isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        height: 50,
        margin: const EdgeInsets.only(top: 8),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final emoji = suggestions[index];
            return Container(
              margin: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _onEmojiSelected(emoji),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.themeProvider.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.themeProvider.dividerColor,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<String> _getEmojiSuggestions(String inputText) {
    return EmojiService.getEmojiSuggestions(inputText);
  }
} 