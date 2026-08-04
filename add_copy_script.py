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

popup_code = """
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 16, color: AppColors.slate500),
                      padding: EdgeInsets.zero,
                      tooltip: 'More options',
                      onSelected: (val) {
                        if (val == 'copy') {
                          Clipboard.setData(ClipboardData(text: message.content));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'copy',
                          child: Row(
                            children: [
                              Icon(Icons.copy, size: 18),
                              SizedBox(width: 8),
                              Text('Copy Text'),
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
    
    # 1. Ensure import 'package:flutter/services.dart';
    if "import 'package:flutter/services.dart';" not in content:
        content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';")
        
    # 2. Replace Text(message.content with SelectableText(message.content
    content = re.sub(r'\bText\s*\(\s*message\.content', r'SelectableText(message.content', content)
    content = re.sub(r'\bText\s*\(\s*msg\.content', r'SelectableText(msg.content', content)
    
    # 3. Add PopupMenuButton to Hover action bar
    parts = content.split('// Hover action bar')
    if len(parts) > 1:
        new_content = parts[0]
        for part in parts[1:]:
            # Find the closing sequence: `],\n                ),` or similar that follows the buttons
            # We know it ends with a Row closing.
            # Let's find `_delete(context)),` or `widget.onReply),`
            match = re.search(r'(_ActionBtn\([^)]+\)[;,]?)(\s*\]\s*,?\s*\n\s*\))', part, re.DOTALL)
            if match:
                part = part[:match.start(2)] + "\n" + popup_code + match.group(2) + part[match.end():]
            new_content += '// Hover action bar' + part
        content = new_content
    
    with open(f, 'w', encoding='utf-8') as file:
        file.write(content)
    print(f"Modified {f}")
