import os
import re

files = [
    'lib/features/chat/presentation/pages/global_chat_page.dart',
    'lib/features/chat/presentation/pages/direct_message_page.dart',
    'lib/features/chat/presentation/pages/custom_channel_chat_page.dart',
    'lib/features/chat/presentation/pages/all_aroundtally_chat_page.dart',
    'lib/features/chat/presentation/widgets/sales_team_chat_view.dart',
    'lib/features/chat/presentation/pages/starred_messages_page.dart'
]

new_menu = """
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 16, color: AppColors.slate500),
                      padding: EdgeInsets.zero,
                      tooltip: 'More options',
                      onSelected: (val) async {
                        if (val == 'copy') {
                          Clipboard.setData(ClipboardData(text: message.content));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                        } else if (val == 'delete') {
                          widget.onDelete(); // For global chat and direct message etc
                        } else if (val == 'paste') {
                           final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                           if (clipboardData != null && clipboardData.text != null && clipboardData.text!.isNotEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Clipboard: ${clipboardData.text}')));
                           } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing to paste')));
                           }
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
                        const PopupMenuItem(
                          value: 'paste',
                          child: Row(
                            children: [
                              Icon(Icons.paste, size: 18, color: AppColors.slate600),
                              SizedBox(width: 8),
                              Text('Paste'),
                            ],
                          ),
                        ),
                        if (widget.isMe)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                      ],
                    ),
"""

for f in files:
    if not os.path.exists(f): continue
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    
    # In some files, delete is called via `onDelete()`, in others it's `_delete(context)`
    # We will adjust `new_menu` accordingly for each file.
    
    is_widget_onDelete = 'widget.onDelete' in content and 'widget.isMe' in content
    
    # We want to replace the `_ActionBtn(icon: Icons.delete_outline` block
    # Let's search for `// Delete (own messages only)` or `_ActionBtn(icon: Icons.delete_outline`
    
    # The previous `fix_action_bar.py` might have succeeded on custom_channel, all_aroundtally, and sales_team
    # Let's clean up any existing PopupMenuButton first.
    
    # Wait, the best way is to use regex to find the delete button and replace it.
    # In files where it wasn't modified, the delete button is:
    # if (isMe) (or if (widget.isMe))
    #   _ActionBtn(icon: Icons.delete_outline... )
    
    # In global_chat_page, it looks like:
    #                     if (widget.isMe)
    #                       _ActionBtn(
    #                         icon: Icons.delete_outline,
    #                         tooltip: 'Delete',
    #                         color: Colors.red,
    #                         onTap: widget.onDelete,
    #                       ),
    
    pattern = r'(\s*//\s*Delete.*?only\))?\s*if\s*\((widget\.)?isMe\)\s*_ActionBtn\([^)]+onTap:[^)]+\),'
    
    # Let's find this pattern and replace it.
    
    def replacer(match):
        is_widget = bool(match.group(2))
        m = new_menu
        if not is_widget:
            m = m.replace('widget.onDelete()', '_delete(context)')
            m = m.replace('widget.isMe', 'isMe')
            m = m.replace('widget.message', 'message')
            
        return m
    
    content = re.sub(pattern, replacer, content, flags=re.DOTALL)
    
    with open(f, 'w', encoding='utf-8') as file:
        file.write(content)
    print(f"Modified {f}")
