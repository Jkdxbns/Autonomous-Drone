import 'package:flutter/material.dart';
import '../../../config/ui_config.dart';

/// Message input field with send button
class MessageInputField extends StatelessWidget {
  final TextEditingController controller;
  final bool hasText;
  final VoidCallback onSend;
  final Widget trailingWidget;

  const MessageInputField({
    super.key,
    required this.controller,
    required this.hasText,
    required this.onSend,
    required this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: UIConfig.spacingMedium,
        vertical: UIConfig.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context)
                .colorScheme
                .outline
                .withValues(alpha: UIConfig.opacityBorder),
            width: UIConfig.borderWidthThin,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 5,
              minLines: 1,
              decoration: InputDecoration(
                hintText: UIConfig.textTypeMessage,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(UIConfig.borderRadiusLarge * 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: UIConfig.spacingLarge,
                  vertical: UIConfig.spacingMedium,
                ),
              ),
            ),
          ),
          const SizedBox(width: UIConfig.spacingSmall),
          hasText
              ? IconButton(
                  onPressed: onSend,
                  icon: Icon(UIConfig.iconSend),
                  color: UIConfig.colorWhite,
                  style: IconButton.styleFrom(
                    backgroundColor: UIConfig.colorInfo,
                    shape: const CircleBorder(),
                    padding: UIConfig.paddingAllMedium,
                  ),
                )
              : trailingWidget,
        ],
      ),
    );
  }
}
