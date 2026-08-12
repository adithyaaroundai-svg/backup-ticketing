import os

filepath = 'lib/features/dashboard/presentation/pages/revenue_page.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix const issues
old_1 = '''            Row(
              children: const [
                Icon(LucideIcons.filter, color: AppColors.primary),
                SizedBox(width: 12),
                Text(
                  'Filters',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.slate900,
                  ),
                ),
              ],
            ),'''
new_1 = '''            Row(
              children: [
                const Icon(LucideIcons.filter, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  'Filters',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.slate900,
                  ),
                ),
              ],
            ),'''
content = content.replace(old_1, new_1)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Removed const!")
