import re

files = [
    'lib/features/chat/presentation/pages/global_chat_page.dart',
    'lib/features/chat/presentation/pages/all_aroundtally_chat_page.dart',
    'lib/features/chat/presentation/pages/custom_channel_chat_page.dart',
    'lib/features/chat/presentation/pages/direct_message_page.dart',
    'lib/features/chat/presentation/widgets/sales_team_chat_view.dart'
]

replacement = 'Positioned(top: -36, right: isMe ? 0 : null, left: isMe ? null : 0, child: Container(padding: const EdgeInsets.only(bottom: 24), color: Colors.transparent, child: const _HoverableActionMenu()))'

for file in files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()

    # The exact string I injected earlier
    target = 'Positioned(top: -36, right: isMe ? 0 : null, left: isMe ? null : 0, child: const _HoverableActionMenu())'
    
    if target in content:
        content = content.replace(target, replacement)
        with open(file, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f'Updated {file}')
    else:
        print(f'Target not found in {file}')

print('Done')
