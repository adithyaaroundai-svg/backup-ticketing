import os

files = [
    'lib/features/chat/presentation/widgets/sales_team_chat_view.dart',
    'lib/features/chat/presentation/pages/custom_channel_chat_page.dart',
    'lib/features/chat/presentation/pages/all_aroundtally_chat_page.dart',
]

for f in files:
    if not os.path.exists(f): continue
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    
    # We replace `itemBuilder: (context) => [` with `itemBuilder: (menuContext) => [`
    # This prevents the inner context from shadowing the outer context, allowing `if (context.mounted)` to check the outer context!
    content = content.replace('itemBuilder: (context) => [', 'itemBuilder: (menuContext) => [')
    
    with open(f, 'w', encoding='utf-8') as file:
        file.write(content)
    print(f"Fixed {f}")
