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
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'copy',
                          onTap: () async {
                            try {
                              await Clipboard.setData(ClipboardData(text: message.content));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                              }
                            } catch (e) {
                              debugPrint('Error copying: $e');
                            }
                          },
                          child: const Row(
                            children: [
                              Icon(Icons.copy, size: 18, color: AppColors.slate600),
                              SizedBox(width: 8),
                              Text('Copy'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'paste',
                          onTap: () async {
                             try {
                               final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                               if (context.mounted) {
                                 if (clipboardData != null && clipboardData.text != null && clipboardData.text!.isNotEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Clipboard: ${clipboardData.text}')));
                                 } else {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing to paste')));
                                 }
                               }
                             } catch (e) {
                               debugPrint('Error pasting: $e');
                             }
                          },
                          child: const Row(
                            children: [
                              Icon(Icons.paste, size: 18, color: AppColors.slate600),
                              SizedBox(width: 8),
                              Text('Paste'),
                            ],
                          ),
                        ),
                        if (isMe)
                          PopupMenuItem(
                            value: 'delete',
                            onTap: () {
                              Future.delayed(const Duration(milliseconds: 100), () {
                                if (context.mounted) {
                                  _delete(context);
                                }
                              });
                            },
                            child: const Row(
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
    
    # Add flutter/services.dart import
    if "import 'package:flutter/services.dart';" not in content:
        content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';")
        
    # Replace Text(message.content with SelectableText(message.content
    content = re.sub(r'\bText\s*\(\s*message\.content', r'SelectableText(message.content', content)
    
    # Replace the delete button
    pattern = r'// Delete \(own messages only\)\s*\n\s*if\s*\(isMe\)\s*_ActionBtn\(icon:\s*Icons\.delete_outline.*?_delete\(context\)\),'
    content = re.sub(pattern, new_menu, content, flags=re.DOTALL)
    
    with open(f, 'w', encoding='utf-8') as file:
        file.write(content)
    print(f"Fixed {f}")
