import os
import re

files = [
    'lib/features/chat/presentation/pages/global_chat_page.dart',
    'lib/features/chat/presentation/pages/direct_message_page.dart'
]

menu_replacement = '''class _HoverableActionMenu extends StatelessWidget {
  const _HoverableActionMenu();

  @override
  Widget build(BuildContext context) {
    final hoverContext = _HoverableActionMenuContext.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedOpacity(
      opacity: hoverContext.isHovering ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 150),
      child: PopupMenuButton<String>(
        icon: Container(
          // No background circle, just the icon with a subtle shadow for visibility
          padding: const EdgeInsets.all(2),
          child: Icon(
            Icons.keyboard_arrow_down, 
            size: 24, 
            color: isDark ? Colors.white70 : Colors.black54,
            shadows: [
              Shadow(color: isDark ? Colors.black87 : Colors.white70, blurRadius: 4, offset: const Offset(0, 1)),
            ]
          ),
        ),
        splashRadius: 16,
        padding: EdgeInsets.zero,
        offset: const Offset(0, 30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 1),
        ),
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        itemBuilder: (menuCtx) => [
          // 1. Reaction Box
          PopupMenuItem<String>(
            value: 'reactions',
            enabled: false,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildReactionButton(
                  emoji: '👍',
                  tooltip: 'Thumbs up',
                  onTap: () {
                     Navigator.of(menuCtx).pop();
                     hoverContext.onAddReaction(context, '👍', hoverContext.messageId);
                  }
                ),
                _buildReactionButton(
                  emoji: '❤️',
                  tooltip: 'Love',
                  onTap: () {
                     Navigator.of(menuCtx).pop();
                     hoverContext.onAddReaction(context, '❤️', hoverContext.messageId);
                  }
                ),
                _buildReactionButton(
                  emoji: '😂',
                  tooltip: 'Laugh',
                  onTap: () {
                     Navigator.of(menuCtx).pop();
                     hoverContext.onAddReaction(context, '😂', hoverContext.messageId);
                  }
                ),
                _buildReactionButton(
                  emoji: '😮',
                  tooltip: 'Wow',
                  onTap: () {
                     Navigator.of(menuCtx).pop();
                     hoverContext.onAddReaction(context, '😮', hoverContext.messageId);
                  }
                ),
                _buildReactionButton(
                  emoji: '😢',
                  tooltip: 'Sad',
                  onTap: () {
                     Navigator.of(menuCtx).pop();
                     hoverContext.onAddReaction(context, '😢', hoverContext.messageId);
                  }
                ),
                _buildReactionButton(
                  emoji: '🙏',
                  tooltip: 'Pray',
                  onTap: () {
                     Navigator.of(menuCtx).pop();
                     hoverContext.onAddReaction(context, '🙏', hoverContext.messageId);
                  }
                ),
                _buildMoreReactionsButton(
                  tooltip: 'More',
                  onTap: () {
                     Navigator.of(menuCtx).pop();
                     hoverContext.onShowMoreReactions(context, hoverContext.messageId);
                  }
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'reply',
            onTap: hoverContext.onReply,
            child: Row(
              children: [
                Icon(Icons.reply, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                const SizedBox(width: 12),
                Text('Reply', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'copy',
            onTap: () async {
               try {
                 await Clipboard.setData(ClipboardData(text: hoverContext.messageContent));
                 if (menuCtx.mounted) {
                   ScaffoldMessenger.of(menuCtx).showSnackBar(
                     const SnackBar(
                       content: Text('Copied to clipboard'),
                       duration: Duration(seconds: 2),
                     ),
                   );
                 }
               } catch (e) {}
            },
            child: Row(
              children: [
                Icon(Icons.copy, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                const SizedBox(width: 12),
                Text('Copy', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
              ],
            ),
          ),
          if (hoverContext.isMe)
            PopupMenuItem<String>(
              value: 'delete',
              onTap: hoverContext.onDelete,
              child: const Row(
                children: [
                  Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReactionButton({
    required String emoji,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(emoji, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }

  Widget _buildMoreReactionsButton({
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(Icons.add_reaction_outlined, size: 16, color: Colors.grey[500]),
        ),
      ),
    );
  }
}'''

for file in files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()

    start_idx = content.find('class _HoverableActionMenu extends StatelessWidget {')
    if start_idx == -1:
        continue
        
    next_class_idx = content.find('\nclass ', start_idx + 10)
    end_idx = next_class_idx if next_class_idx != -1 else len(content)
    
    new_content = content[:start_idx] + menu_replacement + '\n' + content[end_idx:]
    
    with open(file, 'w', encoding='utf-8') as f:
        f.write(new_content)

print('Updated menu icon in all files')
