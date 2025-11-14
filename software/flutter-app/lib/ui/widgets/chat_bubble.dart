import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../config/ui_config.dart';

/// Chat bubble widget (ChatGPT style) - Pure UI, no logic
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isStreaming;
  final ValueNotifier<String>? streamingContent;

  const ChatBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.streamingContent,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: UIConfig.spacingSmall, horizontal: UIConfig.spacingLarge),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            // Avatar on left for assistant
            if (!isUser) ...[
              _buildAvatar(isDarkMode, isUser: false),
              SizedBox(width: UIConfig.spacingMedium),
            ],
            // Message content
            Expanded(
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Role label
                  Text(
                    isUser ? 'You' : 'Assistant',
                    style: TextStyle(
                      fontSize: UIConfig.fontSizeSmall,
                      fontWeight: UIConfig.fontWeightBold,
                      color: isDarkMode ? UIConfig.colorGrey300 : UIConfig.colorGrey700,
                    ),
                  ),
                  SizedBox(height: UIConfig.spacingSmall),
                  // Message text
                  Container(
                    padding: UIConfig.paddingAllMedium,
                    decoration: BoxDecoration(
                      color: isUser 
                          ? (isDarkMode ? UIConfig.colorUserBubbleDark : UIConfig.colorUserBubble)
                          : (isDarkMode ? UIConfig.colorAiBubbleDark : UIConfig.colorAiBubble),
                      borderRadius: UIConfig.radiusMedium,
                      border: Border.all(
                        color: isUser 
                            ? (isDarkMode ? UIConfig.colorDarkPrimary : UIConfig.colorUserBubbleBorder)
                            : (isDarkMode ? UIConfig.colorDarkSurface : UIConfig.colorGrey300),
                        width: UIConfig.borderWidthThin,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Use ValueListenableBuilder for streaming content
                        if (isStreaming && streamingContent != null)
                          ValueListenableBuilder<String>(
                            valueListenable: streamingContent!,
                            builder: (context, content, _) {
                              return Text(
                                content.isEmpty ? message.content : content,
                                style: TextStyle(
                                  fontSize: UIConfig.fontSizeSmall,
                                  height: 1.4,
                                  color: isDarkMode ? UIConfig.colorGrey100 : UIConfig.colorAiText,
                                ),
                              );
                            },
                          )
                        else
                          Text(
                            message.content,
                            style: TextStyle(
                              fontSize: UIConfig.fontSizeSmall,
                              height: 1.4,
                              color: isDarkMode ? UIConfig.colorGrey100 : UIConfig.colorAiText,
                            ),
                          ),
                        // Show streaming indicator for AI messages
                        if (isStreaming && !isUser) ...[
                          SizedBox(height: UIConfig.spacingSmall),
                          SizedBox(
                            width: UIConfig.spacingMedium,
                            height: UIConfig.spacingMedium,
                            child: CircularProgressIndicator(
                              strokeWidth: UIConfig.borderWidthMedium,
                              color: isDarkMode ? UIConfig.colorGrey300 : UIConfig.colorGrey600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Model info (for AI messages)
                  if (!isUser && (message.sttModel != null || message.lmModel != null)) ...[
                    SizedBox(height: UIConfig.spacingSmall),
                    Text(
                      [
                        if (message.sttModel != null) 'STT: ${message.sttModel}',
                        if (message.lmModel != null) 'LM: ${message.lmModel}',
                      ].join(' | '),
                      style: UIConfig.textStyleTimestamp.copyWith(
                        color: isDarkMode ? UIConfig.colorGrey400 : UIConfig.colorGrey600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Avatar on right for user
            if (isUser) ...[
              SizedBox(width: UIConfig.spacingMedium),
              _buildAvatar(isDarkMode, isUser: true),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildAvatar(bool isDarkMode, {required bool isUser}) {
    return CircleAvatar(
      radius: UIConfig.spacingLarge,
      backgroundColor: isDarkMode ? UIConfig.colorDarkPrimary : (isUser ? UIConfig.colorInfo : UIConfig.colorGrey300),
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy,
        size: UIConfig.iconSizeSmall,
        color: (isDarkMode || isUser) ? UIConfig.colorWhite : UIConfig.colorAiText,
      ),
    );
  }
}
