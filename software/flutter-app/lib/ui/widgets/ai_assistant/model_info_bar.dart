import 'package:flutter/material.dart';
import '../../../config/ui_config.dart';

/// Displays the current STT and LM model information
class ModelInfoBar extends StatelessWidget {
  final String sttModel;
  final String lmModel;

  const ModelInfoBar({
    super.key,
    required this.sttModel,
    required this.lmModel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: UIConfig.spacingMedium,
        vertical: UIConfig.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: UIConfig.borderWidthThin,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.mic,
            size: 16,
            color: Color(0xFF64B5F6),
          ),
          const SizedBox(width: 4),
          const Text(
            'STT: ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFFB0BEC5),
            ),
          ),
          Text(
            sttModel,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64B5F6),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 24),
          const Icon(
            Icons.psychology,
            size: 16,
            color: Color(0xFF81C784),
          ),
          const SizedBox(width: 4),
          const Text(
            'LM: ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFFB0BEC5),
            ),
          ),
          Text(
            lmModel,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF81C784),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
