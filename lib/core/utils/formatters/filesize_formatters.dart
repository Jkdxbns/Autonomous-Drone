/// File size formatting utilities
class FileSizeFormatters {
  FileSizeFormatters._();

  /// Format file size in bytes to human-readable format
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      final mb = bytes / (1024 * 1024);
      return '${mb.toStringAsFixed(1)} MB';
    } else {
      final gb = bytes / (1024 * 1024 * 1024);
      return '${gb.toStringAsFixed(2)} GB';
    }
  }

  /// Format file size specifically in MB (for model sizes)
  static String formatFileSizeMB(int bytes) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// Format file size specifically in KB (for small files)
  static String formatFileSizeKB(int bytes) {
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(1)} KB';
  }

  /// Parse file size from MB to bytes
  static int parseMBToBytes(double mb) {
    return (mb * 1024 * 1024).round();
  }

  /// Get file size category (small, medium, large)
  static String getFileSizeCategory(int bytes) {
    if (bytes < 1024 * 1024) return 'Small'; // < 1 MB
    if (bytes < 10 * 1024 * 1024) return 'Medium'; // < 10 MB
    if (bytes < 100 * 1024 * 1024) return 'Large'; // < 100 MB
    return 'Very Large'; // >= 100 MB
  }
}
