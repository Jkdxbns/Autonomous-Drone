import 'package:flutter/material.dart';
import '../../models/conversation.dart';
import '../../services/database/database_helper.dart';
import '../helpers/ui_helpers.dart';
import '../helpers/formatters.dart';
import '../../config/ui_config.dart';

class ChatHistoryScreen extends StatefulWidget {
  final Function(int conversationId) onChatSelected;
  final VoidCallback? onConversationsChanged;

  const ChatHistoryScreen({
    super.key,
    required this.onChatSelected,
    this.onConversationsChanged,
  });

  @override
  State<ChatHistoryScreen> createState() => ChatHistoryScreenState();
}

class ChatHistoryScreenState extends State<ChatHistoryScreen> {
  List<Conversation> _conversations = [];
  bool _isLoading = false;

  bool get hasConversations => _conversations.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
    });

    // Load from database
    final conversations = await DatabaseHelper.instance.getAllConversations();

    setState(() {
      _conversations = conversations;
      _isLoading = false;
    });
    
    widget.onConversationsChanged?.call();
  }

  void addConversation(String title) {
    // Conversation is already in database, just reload
    _loadConversations();
  }

  void updateConversationTitle(int conversationId, String newTitle) async {
    final conversation = _conversations.firstWhere((c) => c.id == conversationId);
    final updated = conversation.copyWith(
      title: newTitle,
      lastModified: DateTime.now(),
    );
    
    await DatabaseHelper.instance.updateConversation(updated);
    
    setState(() {
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1) {
        _conversations[index] = updated;
      }
    });
  }

  Future<void> _deleteConversation(Conversation conversation) async {
    final confirmed = await UiHelpers.showConfirmDialog(
      context: context,
      title: 'Delete Chat?',
      message: 'Are you sure you want to delete "${conversation.title}"? This cannot be undone.',
      confirmText: 'DELETE',
      confirmColor: UIConfig.colorError,
    );

    if (confirmed == true) {
      // Delete from database
      await DatabaseHelper.instance.deleteConversation(conversation.id!);
      
      setState(() {
        _conversations.removeWhere((c) => c.id == conversation.id);
      });

      widget.onConversationsChanged?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted')),
        );
      }
    }
  }

  Future<void> _renameConversation(Conversation conversation) async {
    final newTitle = await UiHelpers.showRenameDialog(
      context: context,
      currentTitle: conversation.title,
    );

    if (newTitle != null && newTitle.isNotEmpty) {
      updateConversationTitle(conversation.id!, newTitle);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat renamed')),
        );
      }
    }
  }

  Future<void> _clearAllChats() async {
    final confirmed = await UiHelpers.showConfirmDialog(
      context: context,
      title: 'Clear All Chats?',
      message: 'This will permanently delete all conversations and messages. This action cannot be undone.',
      confirmText: 'DELETE ALL',
      confirmColor: UIConfig.colorError,
    );

    if (confirmed != true) return;

    // Delete all from database
    await DatabaseHelper.instance.deleteAllConversations();
    
    setState(() {
      _conversations.clear();
    });
    
    widget.onConversationsChanged?.call();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All chats cleared')),
      );
    }
  }
  
  void clearAllChats() {
    _clearAllChats();
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody();
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(UIConfig.iconEmptyChat, size: UIConfig.iconSizeLarge, color: UIConfig.colorGrey400),
            SizedBox(height: UIConfig.spacingLarge),
            Text(
              'No chat history',
              style: UIConfig.textStyleSubtitle.copyWith(color: UIConfig.colorGrey600),
            ),
            SizedBox(height: UIConfig.spacingSmall),
            Text(
              'Start a new conversation from the home tab',
              style: UIConfig.textStyleBody.copyWith(color: UIConfig.colorGrey500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: Scrollbar(
        thumbVisibility: UIConfig.scrollbarThumbVisibility,
        thickness: UIConfig.scrollbarThickness,
        radius: Radius.circular(UIConfig.scrollbarRadius),
        child: ListView.builder(
          primary: false,
          padding: UIConfig.paddingVerticalSmall,
          itemCount: _conversations.length,
          itemBuilder: (context, index) {
            final conversation = _conversations[index];

            return Card(
              margin: EdgeInsets.symmetric(horizontal: UIConfig.spacingLarge, vertical: UIConfig.cardMarginSmall),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    UIConfig.iconChat,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(
                  conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: UIConfig.fontWeightMedium),
                ),
                subtitle: Text(
                  Formatters.formatMessageTime(conversation.lastModified),
                  style: UIConfig.textStyleCaption,
                ),
                trailing: PopupMenuButton(
                  icon: Icon(UIConfig.iconMore),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(UIConfig.iconEdit, color: UIConfig.colorInfo, size: UIConfig.iconSizeSmall),
                          SizedBox(width: UIConfig.spacingMedium),
                          const Text('Rename'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(UIConfig.iconDelete, color: UIConfig.colorError, size: UIConfig.iconSizeSmall),
                          SizedBox(width: UIConfig.spacingMedium),
                          Text('Delete', style: TextStyle(color: UIConfig.colorError)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'rename') {
                      _renameConversation(conversation);
                    } else if (value == 'delete') {
                      _deleteConversation(conversation);
                    }
                  },
                ),
                onTap: () {
                  widget.onChatSelected(conversation.id!);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
