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

                  ],"""

for f in files:
    if not os.path.exists(f): continue
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    
    parts = content.split('// Delete (own messages only)')
    if len(parts) > 1:
        new_content = parts[0]
        for part in parts[1:]:
            match2 = re.search(r'\n\s*\]\s*,\s*\n\s*\)', part)
            if match2:
                # new_menu already includes `],`
                # So we replace up to match2.start() and then append the closing `)`
                new_content += new_menu + '\n                )' + part[match2.end():]
            else:
                new_content += '// Delete (own messages only)' + part
        content = new_content
        
        with open(f, 'w', encoding='utf-8') as file:
            file.write(content)
        print(f"Modified {f}")
