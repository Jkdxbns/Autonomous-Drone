/// Formatting utilities for dates, times, file sizes, etc.
class Formatters {
  /// Format time duration in seconds
  static String formatDuration(int milliseconds) {
    final seconds = milliseconds / 1000;
    return '${seconds.toStringAsFixed(1)}s';
  }

  /// Format file size in MB
  static String formatFileSize(int bytes) {
    final mb = bytes / (1024 * 1024);
    if (mb < 1) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// Format date/time for chat messages
  static String formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }

  /// Truncate text to max length
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Generate title from first user message
  static String generateChatTitle(String firstMessage) {
    final cleaned = firstMessage.trim();
    if (cleaned.length <= 30) return cleaned;
    return '${cleaned.substring(0, 30)}...';
  }
}
