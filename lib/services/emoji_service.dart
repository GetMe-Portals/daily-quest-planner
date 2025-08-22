import 'dart:convert';
import 'package:flutter/services.dart';

/// Service class for handling emoji mappings and retrieval
class EmojiService {
  static const String _configPath = 'assets/config/emoji_mappings.json';
  static Map<String, dynamic>? _emojiMappings;
  static String _defaultEmoji = '📝';

  /// Initialize the emoji service by loading the JSON configuration
  static Future<void> initialize() async {
    try {
      final String jsonString = await rootBundle.loadString(_configPath);
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      _emojiMappings = jsonData['categories'] as Map<String, dynamic>;
      _defaultEmoji = jsonData['default_emoji'] as String? ?? '📝';
    } catch (e) {
      // Fallback to default emoji if JSON loading fails
      _emojiMappings = {};
      _defaultEmoji = '📝';
    }
  }

  /// Get emoji for a given task name
  /// 
  /// [name] - The task name to find emoji for
  /// Returns the appropriate emoji string
  static String getEmojiForName(String name) {
    if (name.trim().isEmpty) {
      return _defaultEmoji;
    }

    if (_emojiMappings == null) {
      return _defaultEmoji;
    }

    final String lowerName = name.toLowerCase();
    final List<String> words = lowerName.split(' ');

    // First pass: Check for exact matches
    for (final category in _emojiMappings!.entries) {
      final Map<String, dynamic> categoryData = category.value as Map<String, dynamic>;
      final List<dynamic> keywords = categoryData['keywords'] as List<dynamic>;
      
      for (final keyword in keywords) {
        final String keywordStr = keyword as String;
        if (lowerName == keywordStr) {
          return categoryData['emoji'] as String;
        }
      }
    }

    // Second pass: Check for word boundary matches (complete words only)
    for (final category in _emojiMappings!.entries) {
      final Map<String, dynamic> categoryData = category.value as Map<String, dynamic>;
      final List<dynamic> keywords = categoryData['keywords'] as List<dynamic>;
      
      for (final keyword in keywords) {
        final String keywordStr = keyword as String;
        // Check if any word in the task name exactly matches the keyword
        if (words.contains(keywordStr)) {
          return categoryData['emoji'] as String;
        }
      }
    }

    // Third pass: Fall back to substring matching for backward compatibility
    for (final category in _emojiMappings!.entries) {
      final Map<String, dynamic> categoryData = category.value as Map<String, dynamic>;
      final List<dynamic> keywords = categoryData['keywords'] as List<dynamic>;
      
      for (final keyword in keywords) {
        final String keywordStr = keyword as String;
        if (lowerName.contains(keywordStr)) {
          return categoryData['emoji'] as String;
        }
      }
    }

    return _defaultEmoji;
  }

  /// Get all available keywords
  /// 
  /// Returns a list of all keywords from the configuration
  static List<String> getAllKeywords() {
    if (_emojiMappings == null) {
      return [];
    }

    final List<String> keywords = [];
    for (final category in _emojiMappings!.entries) {
      final Map<String, dynamic> categoryData = category.value as Map<String, dynamic>;
      final List<dynamic> categoryKeywords = categoryData['keywords'] as List<dynamic>;
      keywords.addAll(categoryKeywords.map((keyword) => keyword as String));
    }
    return keywords;
  }

  /// Get emoji for a specific category
  /// 
  /// [categoryName] - The name of the category
  /// Returns the emoji for the category or default emoji if not found
  static String getEmojiForCategory(String categoryName) {
    if (_emojiMappings == null || !_emojiMappings!.containsKey(categoryName)) {
      return _defaultEmoji;
    }

    final Map<String, dynamic> categoryData = _emojiMappings![categoryName] as Map<String, dynamic>;
    return categoryData['emoji'] as String;
  }

  /// Get all available categories
  /// 
  /// Returns a list of all category names
  static List<String> getAllCategories() {
    if (_emojiMappings == null) {
      return [];
    }
    return _emojiMappings!.keys.toList();
  }

  /// Check if the service is initialized
  /// 
  /// Returns true if the emoji mappings are loaded
  static bool get isInitialized => _emojiMappings != null;

  /// Get emoji suggestions for a given text input
  /// 
  /// [inputText] - The text to find suggestions for
  /// Returns a list of relevant emoji strings
  static List<String> getEmojiSuggestions(String inputText) {
    if (inputText.trim().isEmpty || _emojiMappings == null) {
      return [];
    }

    final String lowerText = inputText.toLowerCase();
    final List<String> words = lowerText.split(' ');
    final List<String> suggestions = [];

    // Iterate through all categories to find matching keywords
    for (final category in _emojiMappings!.entries) {
      final Map<String, dynamic> categoryData = category.value as Map<String, dynamic>;
      final List<dynamic> keywords = categoryData['keywords'] as List<dynamic>;
      final String emoji = categoryData['emoji'] as String;
      
      bool shouldAdd = false;
      
      // Check for exact matches first
      for (final keyword in keywords) {
        final String keywordStr = keyword as String;
        if (lowerText == keywordStr) {
          shouldAdd = true;
          break;
        }
      }
      
      // Check for word boundary matches
      if (!shouldAdd) {
        for (final keyword in keywords) {
          final String keywordStr = keyword as String;
          if (words.contains(keywordStr)) {
            shouldAdd = true;
            break;
          }
        }
      }
      
      // Check for substring matches
      if (!shouldAdd) {
        for (final keyword in keywords) {
          final String keywordStr = keyword as String;
          if (lowerText.contains(keywordStr)) {
            shouldAdd = true;
            break;
          }
        }
      }
      
      if (shouldAdd && !suggestions.contains(emoji)) {
        suggestions.add(emoji);
      }
    }

    // Return top 4 most relevant suggestions
    return suggestions.take(4).toList();
  }
} 