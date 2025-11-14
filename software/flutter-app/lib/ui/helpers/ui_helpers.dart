import 'package:flutter/material.dart';
import '../../config/ui_config.dart';

/// UI helper functions for dialogs, popups, and alerts
class UiHelpers {
  /// Show error dialog
  static void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show confirmation dialog
  static Future<bool?> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'OK',
    String cancelText = 'CANCEL',
    Color? confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: confirmColor != null
                ? TextButton.styleFrom(foregroundColor: confirmColor)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// Show centered floating popup (non-blocking, auto-dismisses)
  static void showCenteredPopup({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String message,
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 120,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: UIConfig.spacingLarge * 1.25, vertical: UIConfig.spacingMedium),
              margin: EdgeInsets.symmetric(horizontal: UIConfig.spacingLarge * 3.75),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: UIConfig.radiusMedium,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: iconColor, size: UIConfig.iconSizeSmall * 1.1),
                  SizedBox(width: UIConfig.spacingMedium),
                  Flexible(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: UIConfig.colorWhite,
                        fontSize: UIConfig.fontSizeMedium,
                        fontWeight: UIConfig.fontWeightMedium,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(duration, () {
      overlayEntry.remove();
    });
  }

  /// Show input dialog for renaming
  static Future<String?> showRenameDialog({
    required BuildContext context,
    required String currentTitle,
  }) {
    final controller = TextEditingController(text: currentTitle);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Chat Title',
            border: OutlineInputBorder(),
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                Navigator.of(context).pop(newTitle);
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }
}
