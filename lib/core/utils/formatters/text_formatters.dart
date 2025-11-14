import '../../constants/app_constants.dart';

/// Text formatting utilities
class TextFormatters {
  TextFormatters._();

  /// Truncate text to max length with ellipsis
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Generate chat title from first message
  static String generateChatTitle(String firstMessage) {
    final cleaned = firstMessage.trim();
    if (cleaned.length <= AppConstants.chatTitleMaxLength) {
      return cleaned;
    }
    return truncate(cleaned, AppConstants.chatTitleMaxLength);
  }

  /// Get preview text for display
  static String getPreviewText(String text) {
    return truncate(text, AppConstants.previewTextMaxLength);
  }

  /// Capitalize first letter of each word
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Remove extra whitespace
  static String normalizeWhitespace(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
