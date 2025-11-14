import 'package:flutter/material.dart';
import '../../../models/chat_message.dart';
import '../chat_bubble.dart';
import '../../../config/ui_config.dart';

/// Chat message list widget
class ChatMessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final int? streamingMessageIndex;
  final ValueNotifier<String>? streamingContentNotifier;

  const ChatMessageList({
    super.key,
    required this.messages,
    required this.scrollController,
    this.streamingMessageIndex,
    this.streamingContentNotifier,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              UIConfig.iconEmptyChat,
              size: UIConfig.iconSizeLarge,
              color: UIConfig.colorGrey400,
            ),
            SizedBox(height: UIConfig.spacingLarge),
            Text(
              UIConfig.textStartConversation,
              style: UIConfig.textStyleSubtitle.copyWith(
                color: UIConfig.colorGrey600,
              ),
            ),
            SizedBox(height: UIConfig.spacingSmall),
            Text(
              UIConfig.textTypeOrRecord,
              style: UIConfig.textStyleBody.copyWith(
                color: UIConfig.colorGrey500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      primary: false,
      padding: EdgeInsets.symmetric(
        vertical: UIConfig.spacingLarge,
        horizontal: UIConfig.spacingSmall,
      ),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isStreaming = index == streamingMessageIndex;

        return ChatBubble(
          key: ValueKey(message.id ?? 'temp_$index'),
          message: message,
          isStreaming: isStreaming,
          streamingContent: isStreaming ? streamingContentNotifier : null,
        );
      },
    );
  }
}
