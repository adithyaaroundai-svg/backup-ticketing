import os
import re

files = [
    'lib/features/chat/presentation/pages/global_chat_page.dart',
]

new_menu = """
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 16, color: AppColors.slate500),
              padding: EdgeInsets.zero,
              tooltip: 'More options',
              onSelected: (val) async {
                if (val == 'copy') {
                  Clipboard.setData(ClipboardData(text: '')); // We need access to the message content here, but we don't have it in _HoverableActionMenu!
                  // Wait, how do we copy if we don't have the message content here?
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.copy, size: 18, color: AppColors.slate600),
                      SizedBox(width: 8),
                      Text('Copy'),
                    ],
                  ),
                ),
              ],
            ),
"""

# Wait, this won't work easily if I don't have the message content.
# I need to modify `_HoverableActionMenuContext` to include `final String messageContent;`
