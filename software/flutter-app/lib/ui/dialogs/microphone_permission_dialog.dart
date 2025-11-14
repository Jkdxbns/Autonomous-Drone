import 'package:flutter/material.dart';

/// Professional permission request dialog for microphone access
class MicrophonePermissionDialog extends StatelessWidget {
  final VoidCallback onAllow;
  final VoidCallback onDeny;

  const MicrophonePermissionDialog({
    super.key,
    required this.onAllow,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      icon: Icon(
        Icons.mic,
        size: 48,
        color: theme.colorScheme.primary,
      ),
      title: const Text(
        'Microphone Permission Required',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This app needs access to your microphone to:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(Icons.record_voice_over, 'Record voice messages'),
          const SizedBox(height: 8),
          _buildFeatureItem(Icons.transcribe, 'Transcribe speech to text'),
          const SizedBox(height: 8),
          _buildFeatureItem(Icons.chat_bubble, 'Interact with AI assistant'),
          const SizedBox(height: 16),
          const Text(
            'Your audio is processed securely and is not stored without your consent.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onDeny,
          child: Text(
            'Not Now',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
        ElevatedButton.icon(
          onPressed: onAllow,
          icon: const Icon(Icons.check),
          label: const Text('Allow'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}

/// Show microphone permission dialog
Future<bool> showMicrophonePermissionDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => MicrophonePermissionDialog(
      onAllow: () => Navigator.of(context).pop(true),
      onDeny: () => Navigator.of(context).pop(false),
    ),
  );
  
  return result ?? false;
}
