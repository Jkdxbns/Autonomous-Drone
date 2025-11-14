import 'package:flutter/material.dart';
import '../../../config/ui_config.dart';

enum ProcessingState {
  idle,
  recording,
  uploading,
  transcribing,
  processing,
  speaking,
}

/// Recording/Send button that changes based on state
class RecordingButton extends StatelessWidget {
  final ProcessingState processingState;
  final bool isRecording;
  final bool isTtsSpeaking;
  final VoidCallback? onMicPressed;
  final VoidCallback? onMicReleased;
  final VoidCallback? onStop;

  const RecordingButton({
    super.key,
    required this.processingState,
    required this.isRecording,
    required this.isTtsSpeaking,
    this.onMicPressed,
    this.onMicReleased,
    this.onStop,
  });

  IconData _getButtonIcon() {
    switch (processingState) {
      case ProcessingState.idle:
        return Icons.mic;
      case ProcessingState.recording:
        return Icons.fiber_manual_record;
      case ProcessingState.uploading:
        return Icons.cloud_upload;
      case ProcessingState.transcribing:
        return Icons.hourglass_bottom;
      case ProcessingState.processing:
        return Icons.auto_awesome;
      case ProcessingState.speaking:
        return Icons.volume_up;
    }
  }

  Color _getButtonColor() {
    switch (processingState) {
      case ProcessingState.idle:
        return UIConfig.colorInfo;
      case ProcessingState.recording:
        return UIConfig.colorWarning;
      case ProcessingState.uploading:
        return Colors.orange;
      case ProcessingState.transcribing:
        return Colors.purple;
      case ProcessingState.processing:
        return UIConfig.colorSuccess;
      case ProcessingState.speaking:
        return Colors.blueAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canStop = processingState == ProcessingState.processing ||
        processingState == ProcessingState.speaking ||
        processingState == ProcessingState.transcribing ||
        processingState == ProcessingState.uploading ||
        isTtsSpeaking;

    return GestureDetector(
      onTapDown: canStop ? null : (_) => onMicPressed?.call(),
      onTapUp: canStop ? null : (_) => onMicReleased?.call(),
      onTapCancel: canStop ? null : () => onMicReleased?.call(),
      onTap: canStop ? onStop : null,
      child: Container(
        width: UIConfig.iconSizeLarge,
        height: UIConfig.iconSizeLarge,
        decoration: BoxDecoration(
          color: canStop ? Colors.red : _getButtonColor(),
          shape: BoxShape.circle,
          boxShadow: isRecording || canStop
              ? [
                  BoxShadow(
                    color: (canStop ? Colors.red : _getButtonColor())
                        .withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Icon(
          canStop ? Icons.stop : _getButtonIcon(),
          color: UIConfig.colorWhite,
          size: UIConfig.iconSizeMedium,
        ),
      ),
    );
  }
}
