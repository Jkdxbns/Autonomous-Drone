/// Date and time formatting utilities
class DateTimeFormatters {
  DateTimeFormatters._();

  /// Format date/time for chat messages (relative time)
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
      return formatShortDate(dateTime);
    }
  }

  /// Format date as MM/DD/YYYY
  static String formatShortDate(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }

  /// Format date and time as MM/DD/YYYY HH:MM
  static String formatDateTime(DateTime dateTime) {
    return '${formatShortDate(dateTime)} ${formatTime(dateTime)}';
  }

  /// Format time as HH:MM
  static String formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Format duration in HH:MM:SS format
  static String formatDurationHMS(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format duration in milliseconds to seconds with 1 decimal
  static String formatDurationSeconds(int milliseconds) {
    final seconds = milliseconds / 1000;
    return '${seconds.toStringAsFixed(1)}s';
  }

  /// Format duration as readable string (e.g., "2 hours 30 minutes")
  static String formatDurationReadable(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final parts = <String>[];
    if (hours > 0) parts.add('$hours hour${hours != 1 ? 's' : ''}');
    if (minutes > 0) parts.add('$minutes minute${minutes != 1 ? 's' : ''}');
    if (seconds > 0 && hours == 0) {
      parts.add('$seconds second${seconds != 1 ? 's' : ''}');
    }

    return parts.isEmpty ? '0 seconds' : parts.join(' ');
  }
}
