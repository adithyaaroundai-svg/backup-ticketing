import re
import os

files = [
    'lib/features/chat/presentation/pages/global_chat_page.dart',
    'lib/features/chat/presentation/pages/all_aroundtally_chat_page.dart',
    'lib/features/chat/presentation/pages/custom_channel_chat_page.dart',
    'lib/features/chat/presentation/pages/direct_message_page.dart',
    'lib/features/chat/presentation/widgets/sales_team_chat_view.dart'
]

for file in files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()

    # direct_message_page case
    content = re.sub(
        r'Positioned\(\s*top:\s*-12,\s*right:\s*isMe\s*\?\s*null\s*:\s*0,\s*left:\s*isMe\s*\?\s*0\s*:\s*null,\s*child:\s*const\s*_HoverableActionMenu\(\),\s*\)',
        'Positioned(top: -36, right: isMe ? 0 : null, left: isMe ? null : 0, child: const _HoverableActionMenu())',
        content
    )

    # other pages case
    content = re.sub(
        r'Positioned\(\s*top:\s*-12,\s*right:\s*0,\s*child:\s*_HoverableActionMenu\(\)\)',
        'Positioned(top: -36, right: isMe ? 0 : null, left: isMe ? null : 0, child: const _HoverableActionMenu())',
        content
    )

    # other pages case (const missing or present variation)
    content = re.sub(
        r'Positioned\(\s*top:\s*-12,\s*right:\s*0,\s*child:\s*const\s*_HoverableActionMenu\(\)\)',
        'Positioned(top: -36, right: isMe ? 0 : null, left: isMe ? null : 0, child: const _HoverableActionMenu())',
        content
    )
    
    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)

print('Updated all chat pages!')
