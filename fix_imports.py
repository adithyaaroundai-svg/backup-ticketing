import os

files = [
    'lib/features/dashboard/presentation/pages/admin_dashboard_page.dart',
    'lib/features/dashboard/presentation/pages/agent_dashboard_page.dart',
    'lib/features/dashboard/presentation/pages/moderator_dashboard_page.dart',
    'lib/features/dashboard/presentation/pages/support_dashboard_page.dart'
]

import_stmt = "import 'package:supabase_flutter/supabase_flutter.dart';\n"

for f in files:
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    
    if import_stmt not in content:
        content = import_stmt + content
        with open(f, 'w', encoding='utf-8') as file:
            file.write(content)
        print(f'Added import to {f}')
    else:
        print(f'Import already exists in {f}')
