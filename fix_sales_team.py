import os
import re

files = [
    'lib/features/chat/presentation/widgets/sales_team_chat_view.dart',
    'lib/features/chat/presentation/pages/custom_channel_chat_page.dart',
    'lib/features/chat/presentation/pages/all_aroundtally_chat_page.dart',
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
                          _delete(context);
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
                        if (isMe)
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
    
    # We want to remove the _ActionBtn for delete completely, and replace with new_menu.
    # In these files, it's:
    # // Delete (own messages only)
    # if (isMe)
    #   _ActionBtn(icon: Icons.delete_outline, tooltip: 'Delete', color: Colors.red, onTap: () => _delete(context)),
    
    # Let's search for this exact block.
    # We will use re.sub to replace the block.
    
    # The previous script might have added PopupMenuButton right after it. Let's match from `// Delete (own messages only)` up to the last `]` before `)` that closes the Row.
    
    # Actually, it's much safer to split by `// Delete (own messages only)`
    parts = content.split('// Delete (own messages only)')
    if len(parts) > 1:
        new_content = parts[0]
        for part in parts[1:]:
            # Find the closing `],\n                ),` or similar.
            # We know the action bar ends with `],\n                ),`
            match = re.search(r'\n\s*\]\s*,\s*\n\s*\)\s*,', part)
            if match:
                # Insert our new menu and then the closing tokens
                new_content += new_menu + match.group(0) + part[match.end():]
            else:
                # Maybe it's `],\n              ),`
                match2 = re.search(r'\n\s*\]\s*,\s*\n\s*\)', part)
                if match2:
                    new_content += new_menu + match2.group(0) + part[match2.end():]
                else:
                    new_content += '// Delete (own messages only)' + part
        content = new_content
        
        with open(f, 'w', encoding='utf-8') as file:
            file.write(content)
        print(f"Modified {f}")
